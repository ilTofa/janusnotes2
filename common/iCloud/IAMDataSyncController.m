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
#define kAttachmentDirectory @"Attachments"

@interface IAMDataSyncController() {
    dispatch_queue_t _syncQueue;
    NSLock *_deletedLock, *_mutatedLock;
}

@property (weak) CoreDataController *coreDataController;

@property (atomic) NSMutableSet *deletedNotesWhileNotReady;
@property NSMutableSet *mutatedNotesWhileNotReady;

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
        self.deletedNotesWhileNotReady = [[NSMutableSet alloc] initWithCapacity:10];
        self.mutatedNotesWhileNotReady = [[NSMutableSet alloc] initWithCapacity:10];
        _deletedLock = [[NSLock alloc] init];
        _mutatedLock = [[NSLock alloc] init];
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
        self.syncControllerInited = YES;
        DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:currentAccount];
        [DBFilesystem setSharedFilesystem:filesystem];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
        [self checkFirstSync:nil];
    } else {
        // Stop the sync engine
        dispatch_async(dispatch_get_main_queue(), ^{
            self.syncControllerInited = NO;
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
//        // Listen to incoming changes from dropbox remotes
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
    if(self.syncControllerReady) {
        // Propagate changes to dropbox (if we have a dropbox store attached).
        NSDictionary *info = note.userInfo;
        NSSet *insertedObjects = [info objectForKey:NSInsertedObjectsKey];
        NSSet *deletedObjects = [info objectForKey:NSDeletedObjectsKey];
        NSSet *updatedObjects = [info objectForKey:NSUpdatedObjectsKey];
        for(NSManagedObject *obj in deletedObjects){
            DLog(@"Deleted a %@: %@", obj.entity.name, [obj valueForKey:@"uuid"]);
            if([obj.entity.name isEqualToString:@"Attachment"])
                dispatch_async(_syncQueue, ^{ [self deleteAttachmentInDropbox:(Attachment *)obj]; });
            else
                dispatch_async(_syncQueue, ^{ [self deleteNoteInDropbox:(Note *)obj]; });
        }
        for(NSManagedObject *obj in insertedObjects){
            DLog(@"Inserted a %@: %@", obj.entity.name, [obj valueForKey:@"uuid"]);
            // If attachment get the corresponding note to insert
            if([obj.entity.name isEqualToString:@"Attachment"])
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:((Attachment *)obj).note]; });
            else
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:(Note *)obj]; });
        }
        for(NSManagedObject *obj in updatedObjects){
            DLog(@"Updated a %@: %@", obj.entity.name, [obj valueForKey:@"uuid"]);
            // If attachment get the corresponding note to update
            if([obj.entity.name isEqualToString:@"Attachment"])
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:((Attachment *)obj).note]; });
            else
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:(Note *)obj]; });
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
        DLog(@"Started copy of coredata db to dropbox (new user here).");
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
        [fr setIncludesPendingChanges:NO];
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
        DLog(@"End copy of coredata db to dropbox-");
    });
}

// Save the passed note to dropbox
- (void)saveNoteToDropbox:(Note *)note {
    DLog(@"Copying note %@ (%d attachments) to dropbox.", note.title, [note.attachment count]);
    DBError *error;
    // Create folder (named after uuid)
    DBPath *notePath = [[DBPath root] childPath:note.uuid];
    if(![[DBFilesystem sharedFilesystem] createFolder:notePath error:&error]) {
        DLog(@"Creating folder to save note. Error could be 'normal'. Error %d creating folder at %@.", [error code], [notePath stringValue]);
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
            DLog(@"Creating file to save a new note to dropbox. Error %d creating file at %@.", [error code], [noteTextPath stringValue]);
        }
    }
    if(![noteTextFile writeString:note.text error:&error]) {
        DLog(@"Error %d writing note text saving to dropbox at %@.", [error code], [noteTextPath stringValue]);
    }
    // Now write all the attachments
    DBPath *attachmentPath = [notePath childPath:kAttachmentDirectory];
    for (Attachment *attachment in note.attachment) {
        // write attachment
        NSString *encodedAttachmentName = [attachment.filename stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        DBPath *attachmentDataPath = [attachmentPath childPath:encodedAttachmentName];
        DBFile *attachmentDataFile = [[DBFilesystem sharedFilesystem] openFile:attachmentDataPath error:&error];
        if(!attachmentDataFile) {
            [[DBFilesystem sharedFilesystem] createFile:attachmentDataPath error:&error];
            if(!attachmentDataFile) {
                DLog(@"Error %d saving attachment file at %@ for note %@.", [error code], [attachmentDataPath stringValue], note.title);
            }
   
        }
        if(![attachmentDataFile writeData:attachment.data error:&error]) {
            DLog(@"Error %d writing attachment data at %@ for note %@.", [error code], [attachmentDataPath stringValue], note.title);
        }
    }
    // Now ensure that no stale attachments are still in the dropbox
    NSArray *attachmentFiles = [[DBFilesystem sharedFilesystem] listFolder:attachmentPath error:&error];
    if(!attachmentFiles) {
        DLog(@"Error reading attachment files %d for note %@", [error code], note.title);
        return;
    }
    for (DBFileInfo *fileInfo in attachmentFiles) {
        BOOL found = NO;
        for (Attachment *attachments in note.attachment) {
            if([attachments.filename isEqualToString:fileInfo.path.name]) {
                found = YES;
            }
        }
        if(!found) {
            // Delete attachment file
            [[DBFilesystem sharedFilesystem] deletePath:fileInfo.path error:&error];
        }
    }
    DLog(@"note %@ copied to dropbox.", note.title);
}

- (void)deleteNoteInDropbox:(Note *)note {
    DLog(@"Delete note in dropbox folder");
    DBError *error;
    DBPath *notePath = [[DBPath root] childPath:note.uuid];
    if(![[DBFilesystem sharedFilesystem] deletePath:notePath error:&error]) {
        ALog(@"*** Error %d deleting note at %@.", [error code], [notePath stringValue]);
    }
}

- (void)deleteAttachmentInDropbox:(Attachment *)attachment {
    DBError *error;
    DBPath *notePath = [[DBPath root] childPath:attachment.note.uuid];
    DBPath *attachmentPath = [[notePath childPath:kAttachmentDirectory] childPath:attachment.filename];
    if(![[DBFilesystem sharedFilesystem] deletePath:attachmentPath error:&error]) {
        ALog(@"*** Error %d deleting attachment at %@.", [error code], [attachmentPath stringValue]);
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
            ALog(@"Aborting. Error deleting all notes from dropbox to core data, error: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        // Get notes ids
        NSArray *filesAtRoot = [[DBFilesystem sharedFilesystem] listFolder:[DBPath root] error:&error];
        if(!filesAtRoot) {
            ALog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        for (DBFileInfo *fileInfo in filesAtRoot) {
            if(fileInfo.isFolder) {
                [self saveDropboxNoteToCoreData:fileInfo.path];
                if (![self.dataSyncThreadContext save:&error]) {
                    ALog(@"Error copying note %@ from dropbox to core data, error: %@", fileInfo.path.stringValue, [error description]);
                }
            } else {
                DLog(@"Deleting spurious file at notes dropbox root: %@ (%@)", fileInfo.path.name, fileInfo.modifiedTime);
                [[DBFilesystem sharedFilesystem] deletePath:fileInfo.path error:&error];
            }
        }
        DLog(@"Syncronization end");
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncRefreshTerminated object:self]];
            [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        });
    });
}

// Save the note from dropbox folder to CoreData
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
            DLog(@"Copying note at path %@ to CoreData", fileInfo.path.name);
            newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
            newNote.uuid = pathToNoteDir.name;
            NSString *titolo = [fileInfo.path.name stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            if([titolo hasSuffix:kNotesExtension]) {
                titolo = [titolo substringToIndex:([titolo length] - 4)];
            }
            newNote.title = titolo;
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
            break;
        }
    }
    // Now copy attachment(s) (if note exists)
    if(newNote) {
        DBPath *attachmentsPath = [pathToNoteDir childPath:kAttachmentDirectory];
        NSArray *filesInAttachmentDir = [[DBFilesystem sharedFilesystem] listFolder:attachmentsPath error:&error];
        if(!filesInAttachmentDir) {
            // No attachments directory -> No attachments
            DLog(@"Cannot list attachment directory for note %@, no attachments then.", newNote.title);
            return;
        }
        for (DBFileInfo *attachmentInfo in filesInAttachmentDir) {
            DLog(@"Copying attachment: %@ to CoreData note %@", attachmentInfo.path.name, newNote.title);
            DBFile *attachmentOnDropbox = [[DBFilesystem sharedFilesystem] openFile:attachmentInfo.path error:&error];
            if(!attachmentOnDropbox) {
                ALog(@"Aborting attachment copy to coredata. Error %d opening attachment %@", [error code], attachmentInfo.path.stringValue);
                continue;
            }
            Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.dataSyncThreadContext];
            newAttachment.filename = attachmentInfo.path.name;
            newAttachment.extension = [attachmentInfo.path.stringValue pathExtension];
            newAttachment.data = [attachmentOnDropbox readData:&error];
            if(!newAttachment.data) {
                DLog(@"Serious error (data loss?) reading attachment %@: %d", attachmentInfo.path.stringValue, [error code]);
            }
            // Now link attachment to the note
            newAttachment.note = newNote;
            [newNote addAttachmentObject:newAttachment];
        }        
    }
    filesInNoteDir = nil;
}

@end
