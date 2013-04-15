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

+ (IAMDataSyncController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static IAMDataSyncController *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

#pragma mark - Dropbox init

// Init is called on first usage. Calls gotNewDropboxUser just in case, and register for account changes to call gotNewDropboxUser
- (id)init
{
    self = [super init];
    if (self) {
        // check if the data controller is ready
        self.coreDataController = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).coreDataController;
        NSAssert(self.coreDataController.psc, @"DataSyncController inited when CoreDataController Persistent Storage is still invalid");
        _syncQueue = dispatch_queue_create("dataSyncControllerQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(_syncQueue, ^{
            _dataSyncThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
            [_dataSyncThreadContext setPersistentStoreCoordinator:self.coreDataController.psc];
        });
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
    return self;
}

// This is called at startup and everytime a new account is linked (or unlinked). The real engine readiness is in checkFirstSync.
- (void)gotNewDropboxUser:(DBAccount *)account {
    DBAccount *currentAccount = [DBAccountManager sharedManager].linkedAccount;
    if(currentAccount) {
        DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:currentAccount];
        [DBFilesystem setSharedFilesystem:filesystem];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
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

// This check if first sync is completed every second. When ready:
// If this is a new account copy coredata db to dropbox,
// in any case, copy all data from dropbox to CoreData db.
- (void)checkFirstSync:(NSTimer*)theTimer {
    if([DBFilesystem sharedFilesystem].completedFirstSync) {
        // Copy current notes (if new account) to dropbox and notify
        if(![[[NSUserDefaults standardUserDefaults] stringForKey:@"currentDropboxAccount"] isEqualToString:[DBAccountManager sharedManager].linkedAccount.info.email])
            [self copyDataToDropbox];
        // Notify interested parties that the sync engine is ready to be used (and set the flag)
        dispatch_async(dispatch_get_main_queue(), ^{
            [self copyAllFromDropbox];
            DLog(@"IAMDataSyncController is ready.");
            self.syncControllerReady = YES;
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
        });
        // Listen to incoming changes from dropbox remotes
//        [[DBFilesystem sharedFilesystem] addObserver:self forPathAndDescendants:[DBPath root] block:^{
//            DLog(@"Got a change in dropbox filesystem");
//            [self copyAllFromDropbox];
//        }];
    } else {
        DLog(@"Still waiting for first sync completion");
        dispatch_async(dispatch_get_main_queue(), ^{
            [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkFirstSync:) userInfo:nil repeats:NO];
        });
    }
}

#pragma mark - RefreshContent from dropbox

- (void)refreshContentFromRemote {
    [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    [self copyAllFromDropbox];
}

#pragma mark - handler propagating new (and updated) notes from coredata to dropbox

- (void)mergeSyncChanges:(NSNotification *)note {
    // Propagate changes to dropbox (if we have a dropbox store attached).
    if(self.syncControllerReady) {
        NSDictionary *info = note.userInfo;
        NSSet *insertedObjects = [info objectForKey:NSInsertedObjectsKey];
        NSSet *deletedObjects = [info objectForKey:NSDeletedObjectsKey];
        NSSet *updatedObjects = [info objectForKey:NSUpdatedObjectsKey];
        for(NSManagedObject *obj in deletedObjects){
            DLog(@"Deleted a %@: %@", obj.entity.name, [obj valueForKey:@"uuid"]);
            if([obj.entity.name isEqualToString:@"Attachment"])
                [self deleteAttachmentInDropbox:(Attachment *)obj];
            else
                [self deleteNoteToDropbox:(Note *)obj];
        }
        for(NSManagedObject *obj in insertedObjects){
            DLog(@"Inserted a %@: %@", obj.entity.name, [obj valueForKey:@"uuid"]);
            // If attachment get the corresponding note to insert
            if([obj.entity.name isEqualToString:@"Attachment"])
                [self saveNoteToDropbox:((Attachment *)obj).note];
            else
                [self saveNoteToDropbox:(Note *)obj];
        }
        for(NSManagedObject *obj in updatedObjects){
            DLog(@"Updated a %@: %@", obj.entity.name, [obj valueForKey:@"uuid"]);
            // If attachment get the corresponding note to update
            if([obj.entity.name isEqualToString:@"Attachment"])
                [self saveNoteToDropbox:((Attachment *)obj).note];
            else
                [self saveNoteToDropbox:(Note *)obj];
        }
    }
    // merge changes on the private queue
    dispatch_async(_syncQueue, ^{
        [self.dataSyncThreadContext mergeChangesFromContextDidSaveNotification:note];
    });
}

#pragma mark - from CoreData to Dropbox (first sync AND user changes to data)

// Copy all coredata db to dropbox (this is only if we have a new account)
- (void)copyDataToDropbox {
    dispatch_async(_syncQueue, ^{
        DLog(@"copy started");
        // Get notes ids
        NSError *error;
        NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        if(!filesAtRoot) {
            DLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
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

// Save the passed note to dropbox
- (void)saveNoteToDropbox:(Note *)note {
    DLog(@"Copying to dropbox note: %@", note);
    DBError *error;
    // Create folder (named after uuid)
    DBPath *notePath = [[DBPath root] childPath:note.uuid];
    if(![[DBFilesystem sharedFilesystem] createFolder:notePath error:&error]) {
        DLog(@"Error %d (%@) creating folder at %@.", [error code], [error description], [notePath stringValue]);
    }
    // write note
    NSString *encodedTitle = [note.title stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    if(![[encodedTitle pathExtension] isEqualToString:kNotesExtension])
        encodedTitle = [encodedTitle stringByAppendingFormat:@".%@", kNotesExtension];
    DBPath *noteTextPath = [notePath childPath:encodedTitle];
    DBFile *noteTextFile = [[DBFilesystem sharedFilesystem] openFile:noteTextPath error:&error];
    if(!noteTextFile) {
        // tring to create it.
        noteTextFile = [[DBFilesystem sharedFilesystem] createFile:noteTextPath error:&error];
        if(!noteTextFile) {
            DLog(@"Error %d (%@) creating file at %@.", [error code], [error description], [noteTextPath stringValue]);
        }
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
        DBFile *attachmentDataFile = [[DBFilesystem sharedFilesystem] openFile:attachmentDataPath error:&error];
        if(!attachmentDataFile) {
            [[DBFilesystem sharedFilesystem] createFile:attachmentDataPath error:&error];
            if(!attachmentDataFile) {
                DLog(@"Error %d (%@) creating file at %@.", [error code], [error description], [attachmentDataPath stringValue]);
            }
   
        }
        if(![attachmentDataFile writeData:attachment.data error:&error]) {
            DLog(@"Error %d (%@) writing attachment data at %@.", [error code], [error description], [attachmentDataPath stringValue]);
        }
    }
}

- (void)deleteNoteToDropbox:(Note *)note {
    DLog(@"Delete note in dropbox folder");
    DBError *error;
    DBPath *notePath = [[DBPath root] childPath:note.uuid];
    if(![[DBFilesystem sharedFilesystem] deletePath:notePath error:&error]) {
        DLog(@"*** Error %d (%@) deleting note at %@.", [error code], [error description], [notePath stringValue]);
    }
}

- (void)deleteAttachmentInDropbox:(Attachment *)attachment {
    DBError *error;
    DBPath *notePath = [[DBPath root] childPath:attachment.note.uuid];
    DBPath *attachmentPath = [notePath childPath:attachment.uuid];
    if(![[DBFilesystem sharedFilesystem] deletePath:attachmentPath error:&error]) {
        DLog(@"*** Error %d (%@) deleting attachment at %@.", [error code], [error description], [attachmentPath stringValue]);
    }
}

#pragma mark - from dropbox to core data

- (void)copyAllFromDropbox {
    dispatch_async(_syncQueue, ^{
        DLog(@"Deleting current coreData db init");
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
        [fetchRequest setEntity:entity];
        NSError *error;
        NSArray *notes = [self.dataSyncThreadContext executeFetchRequest:fetchRequest error:&error];
        for (Note *note in notes) {
            [self.dataSyncThreadContext deleteObject:note];
        }
        // Save deleting
        if (![self.dataSyncThreadContext save:&error]) {
            NSLog(@"Aborting. Error deleting all notes from dropbox to core data, error: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        // Get notes ids
        NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        if(!filesAtRoot) {
            NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            DLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        for (DBFileInfo *fileInfo in filesAtRoot) {
            if(fileInfo.isFolder) {
                [self saveDropboxNoteToCoreData:fileInfo.path];
            } else {
                DLog(@"Spurious file: %@ (%@)", fileInfo.path.name, fileInfo.modifiedTime);
            }
        }
        if (![self.dataSyncThreadContext save:&error]) {
            NSLog(@"Aborting. Error copying all notes from dropbox to core data, error: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        DLog(@"Syncronization end");
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncRefreshTerminated object:self]];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        });
    });
}

- (void)updateCoreDataNote:(Note *)note withDropboxDataAt:(DBPath *)pathToNoteDir {
    dispatch_async(_syncQueue, ^{
        DBError *error;
        NSMutableArray *filesInNoteDir = [[[DBFilesystem sharedFilesystem] listFolder:pathToNoteDir error:&error] mutableCopy];
        if(!filesInNoteDir) {
            NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            DLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            return;
        }
        for (DBFileInfo *fileInfo in filesInNoteDir) {
            if(!fileInfo.isFolder) {
                // This is the note and has been modified later, then copy data
                if([fileInfo.modifiedTime compare:note.timeStamp] == NSOrderedDescending) {
                    DLog(@"Updating note: %@ (%@) to CoreData", fileInfo.path.name, fileInfo.modifiedTime);
                    note.uuid = pathToNoteDir.name;
                    note.title = [fileInfo.path.name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
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

// Save the note at the passed path to CoreData
- (void)saveDropboxNoteToCoreData:(DBPath *)pathToNoteDir {
    // BEWARE that this code needs to be called in the _syncqueue dispatch_queue beacuse it's using dataSyncThreadContext
    Note *newNote = nil;
    DBError *error;
    NSMutableArray *filesInNoteDir = [[[DBFilesystem sharedFilesystem] listFolder:pathToNoteDir error:&error] mutableCopy];
    if(!filesInNoteDir) {
        NSLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
        DLog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
        return;
    }
    for (DBFileInfo *fileInfo in filesInNoteDir) {
        if(!fileInfo.isFolder) {
            // This is the note
            DLog(@"Copying note: %@ (%@) to CoreData", fileInfo.path.name, fileInfo.modifiedTime);
            newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
            newNote.uuid = pathToNoteDir.name;
            newNote.title = [[fileInfo.path.name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding] lastPathComponent];
            newNote.creationDate = newNote.timeStamp = fileInfo.modifiedTime;
            DBFile *noteOnDropbox = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
            if(!noteOnDropbox) {
                NSLog(@"Aborting note copy to coredata. Error opening note: %d (%@)", [error code], [error description]);
                [self.dataSyncThreadContext rollback];
                return;
            }
            newNote.text = [noteOnDropbox readString:&error];
            if(!newNote.text) {
                DLog(@"Serious error reading note %@: %d (%@)", fileInfo.path.stringValue, [error code], [error description]);
            }
            // Remove the file from the index (leaving only attachments in the array) and exit the enumeration
            [filesInNoteDir removeObject:fileInfo];
            break;
        }
    }
    // Now copy attachment(s) (if note exists)
    if(newNote)
        [self attachAttachmentsToCoreDataNote:newNote fromFileInfoArrayInNotesDir:filesInNoteDir];
    filesInNoteDir = nil;
}

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
            if(!newAttachment.data) {
                DLog(@"Serious error reading attachment %@: %d (%@)", fileInfo.path.stringValue, [error code], [error description]);
            }
            // Now link attachment to the note
            newAttachment.note = note;
            [note addAttachmentObject:newAttachment];
        }
    }
}

@end
