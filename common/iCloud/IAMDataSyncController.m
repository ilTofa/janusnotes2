//
//  IAMDataSyncController.m
//  iJanus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMDataSyncController.h"

#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "Note.h"
#import "Attachment.h"

#define kNotesExtension @"txt"

@interface IAMDataSyncController() {
    dispatch_queue_t _syncQueue;
}

@property (weak) CoreDataController *coreDataController;

@end

@implementation IAMDataSyncController

- (id)init
{
    self = [super init];
    if (self) {
        // check if the data controller is ready
        self.coreDataController = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).coreDataController;
        NSAssert(self.coreDataController.psc, @"DataSyncController inited when CoreDataController Persistent Storage is still invalid");
        _syncQueue = dispatch_queue_create("dataSyncControllerQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(_syncQueue, ^{
            _dataSyncThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_dataSyncThreadContext setPersistentStoreCoordinator:self.coreDataController.psc];
        });
        [self dropboxSyncInit];
    }
    return self;
}

+ (IAMDataSyncController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static IAMDataSyncController *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)syncFromDropbox {
    dispatch_async(_syncQueue, ^{
        DLog(@"Syncronization init");
        // Get notes ids
        DBError *error;
        NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        if(!filesAtRoot) {
            NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            return;
        }
        for (DBFileInfo *fileInfo in filesAtRoot) {
            if(fileInfo.isFolder) {
                // Now check if we have the note in CoreData
                NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"Note"];
                [fr setIncludesPendingChanges:NO]; //distinct has to go down to the db, not implemented for in memory filtering
                NSString *queryString = [NSString stringWithFormat:@"uuid is \"%@\")", fileInfo.path.name];
                DLog(@"Looking for dropbox note incore data. Query string is: '%@'", queryString);
                NSPredicate *predicate = [NSPredicate predicateWithFormat:queryString];
                [fr setPredicate:predicate];
                NSArray *notes = [self.dataSyncThreadContext executeFetchRequest:fr error:&error];
                if(!notes || [notes count] == 0) {
                    // No matching notes in coredata, saving a new note
                    [self saveDropboxNoteToCoreData:fileInfo.path];
                } else {
                    // Found a matching note, update if needed
                    [self updateCoreDataNote:[notes objectAtIndex:0] withDropboxDataAt:fileInfo.path];
                }
            } else {
                DLog(@"Spurious file: %@ (%@)", fileInfo.path.name, fileInfo.modifiedTime);
            }
        }
        DLog(@"Syncronization end");
    });
}

- (void)mergeSyncChanges:(NSNotification *)note {
    NSDictionary *info = note.userInfo;
    NSSet *insertedObjects = [info objectForKey:NSInsertedObjectsKey];
    NSSet *deletedObjects = [info objectForKey:NSDeletedObjectsKey];
    NSSet *updatedObjects = [info objectForKey:NSUpdatedObjectsKey];
    for(NSManagedObject *obj in updatedObjects){
        // now process the changes as you need
        DLog(@"Updated a %@: %@", obj.entity.name, obj);
    }
    for(NSManagedObject *obj in deletedObjects){
        // now process the changes as you need
        DLog(@"Deleted a %@: %@", obj.entity.name, obj);
    }
    for(NSManagedObject *obj in insertedObjects){
        // now process the changes as you need
        DLog(@"Inserted a %@: %@", obj.entity.name, obj);
    }
    // merge changes on the private queue and sync back
    dispatch_async(_syncQueue, ^{
        [self.dataSyncThreadContext mergeChangesFromContextDidSaveNotification:note];
        [self syncFromDropbox];
    });
}

#pragma mark - note to/from dropbox

- (void)attachAttachmentsToCoreDataNote:(Note *)note fromFileInfoArrayInNotesDir:(NSArray *)filesInNoteDir {
    DBError *error;
    for (DBFileInfo *fileInfo in filesInNoteDir) {
        // If a directory is an attachment
        if(fileInfo.isFolder) {
            NSMutableArray *filesInAttachmentDir = [[[DBFilesystem sharedFilesystem] listFolder:fileInfo.path error:&error] mutableCopy];
            if(!filesInAttachmentDir) {
                NSLog(@"Error reading attachment directory: %d (%@)", [error code], [error description]);
                continue;
            }
            if([filesInAttachmentDir count] != 1) {
                NSLog(@"Too many or too few files in attachment directory %@: %d.", fileInfo.path.stringValue, [filesInAttachmentDir count]);
                continue;
            }
            // Create and copy attachment
            DBFileInfo *attachmentInfo = [filesInAttachmentDir objectAtIndex:0];
            DLog(@"Copying attachment: %@ (%@) to CoreData", attachmentInfo.path.name, attachmentInfo.modifiedTime);
            DBFile *attachmentOnDropbox = [[DBFilesystem sharedFilesystem] openFile:attachmentInfo.path error:&error];
            if(!attachmentOnDropbox) {
                NSLog(@"Aborting attachment copy to coredata. Error opening note: %d (%@)", [error code], [error description]);
                continue;
            }
            Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.dataSyncThreadContext];
            newAttachment.filename = attachmentInfo.path.name;
            newAttachment.extension = [attachmentInfo.path.stringValue pathExtension];
            newAttachment.data = [attachmentOnDropbox readData:&error];
            // Now link attachment to the note
            newAttachment.note = note;
            [note addAttachmentObject:newAttachment];
            note.text = [attachmentOnDropbox readString:&error];
        }
    }
}

- (void)updateCoreDataNote:(Note *)note withDropboxDataAt:(DBPath *)pathToNoteDir {
    dispatch_async(_syncQueue, ^{
        DBError *error;
        NSMutableArray *filesInNoteDir = [[[DBFilesystem sharedFilesystem] listFolder:pathToNoteDir error:&error] mutableCopy];
        if(!filesInNoteDir) {
            NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            return;
        }
        for (DBFileInfo *fileInfo in filesInNoteDir) {
            if(!fileInfo.isFolder) {
                // This is the note and has been modified later, then copy data
                if([fileInfo.modifiedTime compare:note.timeStamp] == NSOrderedDescending) {
                    DLog(@"Updating note: %@ (%@) to CoreData", fileInfo.path.name, fileInfo.modifiedTime);
                    note.uuid = pathToNoteDir.name;
                    note.title = fileInfo.path.name;
                    note.creationDate = note.timeStamp = fileInfo.modifiedTime;
                    DBFile *noteOnDropbox = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
                    if(!noteOnDropbox) {
                        NSLog(@"Aborting note copy to coredata. Error opening note: %d (%@)", [error code], [error description]);
                        [self.dataSyncThreadContext rollback];
                        return;
                    }
                    note.text = [noteOnDropbox readString:&error];
                    // Remove the file from the index (leaving only attachments in the array) and exit the enumeration
                    [filesInNoteDir removeObject:fileInfo];
                    break;
                } else {
                    // note on dropbox is earlier or the same date of note on core data, stop updating then
                    DLog(@"Not updating core data note. Modification date for dropbox is %@, for note is %@", fileInfo.modifiedTime, note.timeStamp);
                    return;
                }
            }
        }
        // Now delete and then copy attachment(s) (if any)
        // TODO: refactor with checking modification dates on attachments.
        [note removeAttachment:note.attachment];
        [self attachAttachmentsToCoreDataNote:note fromFileInfoArrayInNotesDir:filesInNoteDir];
        filesInNoteDir = nil;
    });
}

- (void)saveDropboxNoteToCoreData:(DBPath *)pathToNoteDir {
    dispatch_async(_syncQueue, ^{
        Note *newNote = nil;
        DBError *error;
        NSMutableArray *filesInNoteDir = [[[DBFilesystem sharedFilesystem] listFolder:pathToNoteDir error:&error] mutableCopy];
        if(!filesInNoteDir) {
            NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            return;
        }
        for (DBFileInfo *fileInfo in filesInNoteDir) {
            if(!fileInfo.isFolder) {
                // This is the note
                DLog(@"Copying note: %@ (%@) to CoreData", fileInfo.path.name, fileInfo.modifiedTime);
                newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
                newNote.uuid = pathToNoteDir.name;
                newNote.title = fileInfo.path.name;
                newNote.creationDate = newNote.timeStamp = fileInfo.modifiedTime;
                DBFile *noteOnDropbox = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
                if(!noteOnDropbox) {
                    NSLog(@"Aborting note copy to coredata. Error opening note: %d (%@)", [error code], [error description]);
                    [self.dataSyncThreadContext rollback];
                    return;                    
                }
                newNote.text = [noteOnDropbox readString:&error];
                // Remove the file from the index (leaving only attachments in the array) and exit the enumeration
                [filesInNoteDir removeObject:fileInfo];
                break;
            }
        }
        // Now copy attachment(s) (if note exists)
        if(newNote)
            [self attachAttachmentsToCoreDataNote:newNote fromFileInfoArrayInNotesDir:filesInNoteDir];
        filesInNoteDir = nil;
    });
}

- (void)saveNoteToDropbox:(Note *)note {
    DLog(@"Copying to dropbox note: %@", note);
    DBError *error;
    // Create folder (named after uuid)
    DBPath *notePath = [[DBPath root] childPath:note.uuid];
    if(![[DBFilesystem sharedFilesystem] createFolder:notePath error:&error]) {
        DLog(@"Error %d (%@) creating folder at %@.", [error code], [error description], [notePath stringValue]);
    }
    // write note
    NSString *encodedTitle = [[NSString stringWithFormat:@"%@.%@", note.title, kNotesExtension] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    DBPath *noteTextPath = [notePath childPath:encodedTitle];
    DBFile *noteTextFile = [[DBFilesystem sharedFilesystem] createFile:noteTextPath error:&error];
    if(!noteTextFile) {
        DLog(@"Error %d (%@) creating file at %@.", [error code], [error description], [noteTextPath stringValue]);
    }
    if(![noteTextFile writeString:note.text error:&error]) {
        DLog(@"Error %d (%@) writing note text at %@.", [error code], [error description], [noteTextPath stringValue]);        
    }
    // Now write all the attachments
    for (Attachment *attachment in note.attachment) {
        // Create folder (named after uuid)
        DBPath *attachmentPath = [notePath childPath:attachment.uuid];
        if(![[DBFilesystem sharedFilesystem] createFolder:attachmentPath error:&error]) {
            DLog(@"Error %d (%@) creating folder at %@.", [error code], [error description], [attachmentPath stringValue]);
        }
        // write attachment
        NSString *encodedAttachmentName = [attachment.filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        DBPath *attachmentDataPath = [attachmentPath childPath:encodedAttachmentName];
        DBFile *attachmentDataFile = [[DBFilesystem sharedFilesystem] createFile:attachmentDataPath error:&error];
        if(!attachmentDataFile) {
            DLog(@"Error %d (%@) creating file at %@.", [error code], [error description], [attachmentDataPath stringValue]);
        }
        if(![attachmentDataFile writeData:attachment.data error:&error]) {
            DLog(@"Error %d (%@) writing attachment data at %@.", [error code], [error description], [attachmentDataPath stringValue]);
        }
    }
}

- (void)copyDataToDropbox {
    dispatch_async(_syncQueue, ^{
        DLog(@"copy started");
        // Get notes ids
        NSError *error;
        NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        if(!filesAtRoot) {
            NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            return;
        }
        NSMutableArray *notesOnFS = [[NSMutableArray alloc] initWithCapacity:5];
        for (DBFileInfo *fileInfo in filesAtRoot) {
            if(fileInfo.isFolder) {
                [notesOnFS addObject:fileInfo];
                DLog(@"Note: %@ (%@)", fileInfo.path.name, fileInfo.modifiedTime);
            } else {
                DLog(@"Spurious file: %@ (%@)", fileInfo.path.name, fileInfo.modifiedTime);
            }
        }
        filesAtRoot = nil;
        // Loop on the data set and write anything not already present
        // This will not include new attachments to existing (on dropbox) notes. This is by design.
        NSFetchRequest *fr = [[NSFetchRequest alloc] initWithEntityName:@"Note"];
        [fr setIncludesPendingChanges:NO]; //distinct has to go down to the db, not implemented for in memory filtering
        [fr setFetchBatchSize:1000]; //protect thy memory
        NSSortDescriptor *sortKey = [NSSortDescriptor sortDescriptorWithKey:@"uuid" ascending:YES];
        [fr setSortDescriptors:@[sortKey]];
        NSArray *notes = [self.dataSyncThreadContext executeFetchRequest:fr error:&error];
        for (Note *note in notes) {
            BOOL found = NO;
            for (DBFileInfo *fileinfo in notesOnFS) {
                if([fileinfo.path.name caseInsensitiveCompare:note.uuid] == NSOrderedSame) {
                    found = YES;
                }
            }
            if(!found)
                [self saveNoteToDropbox:note];
        }
        [[NSUserDefaults standardUserDefaults] setValue:[DBAccountManager sharedManager].linkedAccount.info.email forKey:@"currentDropboxAccount"];
        DLog(@"copy end");
    });
}

#pragma mark - Dropbox init

- (void)checkFirstSync:(NSTimer*)theTimer {
    if([DBFilesystem sharedFilesystem].completedFirstSync) {
        // Copy current notes (if new account) to dropbox and notify
        if(![[[NSUserDefaults standardUserDefaults] stringForKey:@"currentDropboxAccount"] isEqualToString:[DBAccountManager sharedManager].linkedAccount.info.email])
            [self copyDataToDropbox];
        [self dataSyncEngineReady];
    } else {
        DLog(@"Still waiting for first sync completion");
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkFirstSync:) userInfo:nil repeats:NO];
        });        
    }
}

- (void)dataSyncEngineReady {
    // Notify interested parties that the sync engine is ready to be used (and set the flag)
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
        self.syncControllerReady = YES;
        DLog(@"IAMDataSyncController is ready.");
        [self syncFromDropbox];
    });    
}

- (void)gotNewDropboxUser:(DBAccount *)account {
    DBAccount *currentAccount = [DBAccountManager sharedManager].linkedAccount;
    if(currentAccount) {
        DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:currentAccount];
        [DBFilesystem setSharedFilesystem:filesystem];
        [self checkFirstSync:nil];
    } else {
        // Stop the sync engine
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSUserDefaults standardUserDefaults] setValue:nil forKey:@"currentDropboxAccount"];
            // TODO: we should probably kill the private queue and reset our moc
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerStopped object:self]];
            self.syncControllerReady = NO;
            DLog(@"IAMDataSyncController is stopped.");
        });
    }
}

- (void)dropboxSyncInit {
    // Init dropbox sync API
    DBAccountManager* accountMgr = [[DBAccountManager alloc] initWithAppKey:@"8mwm9fif4s1fju2" secret:@"pvafyx258qkx2fm"];
    [DBAccountManager setSharedManager:accountMgr];
    DBAccount *account = accountMgr.linkedAccount;
    [self gotNewDropboxUser:account];
    // Observe account changes and reset the shared filesystem just in case.
    [accountMgr addObserver:self block:^(DBAccount *account) {
        [self gotNewDropboxUser:account];
    }];
    // Listen to the mainThreadMOC, so to sync changes
    NSAssert(self.coreDataController.mainThreadContext, @"The Managed Object Context for CoreDataController is still invalid");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeSyncChanges:) name:NSManagedObjectContextDidSaveNotification object:self.coreDataController.mainThreadContext];
}

@end
