//
//  IAMFilesystemSyncController.m
//  Janus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMFilesystemSyncController.h"

#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "Note.h"
#import "Attachment.h"

#define kNotesExtension @"txt"
#define kAttachmentDirectory @"Attachments"

#pragma mark - filename helpers

NSString * convertToValidDropboxFilenames(NSString * originalString) {
    NSMutableString * temp = [originalString mutableCopy];
    
    [temp replaceOccurrencesOfString:@"%" withString:@"%25" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"/" withString:@"%2f" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"\\" withString:@"%5c" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"<" withString:@"%3c" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@">" withString:@"%3e" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@":" withString:@"%3a" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"\"" withString:@"%22" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"|" withString:@"%7c" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"?" withString:@"%3f" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"*" withString:@"%2a" options:0 range:NSMakeRange(0, [temp length])];
    return temp;
}

NSString * convertFromValidDropboxFilenames(NSString * originalString) {
    NSMutableString * temp = [originalString mutableCopy];
    
    [temp replaceOccurrencesOfString:@"%2f" withString:@"/" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%5c" withString:@"\\" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3c" withString:@"<" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3e" withString:@">" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3a" withString:@":" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%22" withString:@"\"" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%7c" withString:@"|" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%3f" withString:@"?" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%2a" withString:@"*" options:0 range:NSMakeRange(0, [temp length])];
    [temp replaceOccurrencesOfString:@"%25" withString:@"%" options:0 range:NSMakeRange(0, [temp length])];
    return temp;
}

@interface IAMFilesystemSyncController() {
    dispatch_queue_t _syncQueue;
    NSLock *_deletedLock, *_mutatedLock;
}

@property (weak) CoreDataController *coreDataController;

@property (atomic) NSMutableSet *deletedNotesWhileNotReady;
@property NSMutableSet *mutatedNotesWhileNotReady;

@property NSData *secureBookmarkToData;
@property NSURL *syncDirectory;

@end

@implementation IAMFilesystemSyncController

+ (IAMFilesystemSyncController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static IAMFilesystemSyncController *_sharedObject = nil;
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
        self.coreDataController = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController;
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
        // Init security bookmark
        NSError *error;
        self.secureBookmarkToData = [[NSUserDefaults standardUserDefaults] dataForKey:@"syncDirectory"];
        if(!self.secureBookmarkToData) {
            NSURL *cacheDirectory = [[NSFileManager defaultManager] URLForDirectory:NSDocumentDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
            self.syncDirectory = [cacheDirectory URLByAppendingPathComponent:@"Janus-Notes" isDirectory:YES];
            [[NSFileManager defaultManager] createDirectoryAtURL:self.syncDirectory withIntermediateDirectories:YES attributes:nil error:&error];
        } else {
            self.syncDirectory = [NSURL URLByResolvingBookmarkData:self.secureBookmarkToData options:NSURLBookmarkResolutionWithSecurityScope  relativeToURL:nil bookmarkDataIsStale:YES error:&error];
            [self.syncDirectory startAccessingSecurityScopedResource];
            [self firstAccessToData];
        }
        // Listen to the mainThreadMOC, so to sync changes
        NSAssert(self.coreDataController.mainThreadContext, @"The Managed Object Context for CoreDataController is still invalid");
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeSyncChanges:) name:NSManagedObjectContextDidSaveNotification object:self.coreDataController.mainThreadContext];
    }
    return self;
}

- (BOOL)modifySyncDirectory:(NSURL *)newSyncDirectory {
    NSError *error;
    BOOL alreadySyncingToPrivilegedDir = NO;
    // Remove security access if any before
    if(self.secureBookmarkToData)
        alreadySyncingToPrivilegedDir = YES;
    self.secureBookmarkToData = [newSyncDirectory bookmarkDataWithOptions:NSURLBookmarkCreationWithSecurityScope includingResourceValuesForKeys:nil relativeToURL:nil error:&error];
    if(!self.secureBookmarkToData) {
        DLog(@"Error creating secure bookmark!");
        return FALSE;
    }
    [[NSUserDefaults standardUserDefaults] setObject:self.secureBookmarkToData forKey:@"syncDirectory"];
    if(alreadySyncingToPrivilegedDir)
        [self.syncDirectory stopAccessingSecurityScopedResource];
    self.syncDirectory = [NSURL URLByResolvingBookmarkData:self.secureBookmarkToData options:NSURLBookmarkResolutionWithSecurityScope  relativeToURL:nil bookmarkDataIsStale:YES error:&error];
    [self.syncDirectory startAccessingSecurityScopedResource];
    [self firstAccessToData];
    return YES;
}

- (void)firstAccessToData {
    [self copyAllFromDropbox];
    DLog(@"IAMDataSyncController is ready.");
    self.syncControllerReady = YES;
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
}

#pragma mark - RefreshContent from dropbox

- (void)refreshContentFromRemote {
    [self copyAllFromDropbox];
}

#pragma mark - handler propagating new (and updated) notes from coredata to dropbox
/*
- (void)mergeSyncChanges:(NSNotification *)note {
    if(self.syncControllerReady) {
        DLog(@"Propagating moc changes to dropbox");
        NSDictionary *info = note.userInfo;
        NSSet *insertedObjects = [info objectForKey:NSInsertedObjectsKey];
        NSSet *deletedObjects = [info objectForKey:NSDeletedObjectsKey];
        NSSet *updatedObjects = [info objectForKey:NSUpdatedObjectsKey];
        
        DLog(@"MERGESYNCDEBUGSECTION - BEGIN");
        DLog(@"Deleted objects");
        for(NSManagedObject *obj in deletedObjects){
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"D - An attachment %@ from note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
            } else {
                DLog(@"D - A note %@", ((Note *)obj).title);
            }
        }
        DLog(@"Inserted objects");
        for(NSManagedObject *obj in insertedObjects){
            // If attachment get the corresponding note to insert
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"I - An attachment %@ for note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
            } else {
                DLog(@"I - A note %@", ((Note *)obj).title);
            }
        }
        DLog(@"Updated objects");
        for(NSManagedObject *obj in updatedObjects){
            // If attachment get the corresponding note to update
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"U - An attachment %@ for note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
            } else {
                DLog(@"U - A note %@", ((Note *)obj).title);
            }
        }
        DLog(@"MERGESYNCDEBUGSECTION - END");

        
        for(NSManagedObject *obj in deletedObjects){
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"Deleting the attachment %@ from note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
                dispatch_async(_syncQueue, ^{ [self deleteAttachmentInDropbox:(Attachment *)obj]; });
            } else {
                DLog(@"Deleting note %@", ((Note *)obj).title);
                dispatch_async(_syncQueue, ^{ [self deleteNoteInDropbox:(Note *)obj]; });
            }
        }
        for(NSManagedObject *obj in insertedObjects){
            // If attachment get the corresponding note to insert
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"Inserting the attachment %@ for note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:((Attachment *)obj).note]; });
            } else {
                DLog(@"Inserting note %@", ((Note *)obj).title);
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:(Note *)obj]; });
            }
        }
        for(NSManagedObject *obj in updatedObjects){
            // If attachment get the corresponding note to update
            if([obj.entity.name isEqualToString:@"Attachment"]) {
                DLog(@"Updating the attachment %@ for note %@", ((Attachment *)obj).filename, ((Attachment *)obj).note.title);
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:((Attachment *)obj).note]; });
            } else {
                DLog(@"Updating note %@", ((Note *)obj).title);
                dispatch_async(_syncQueue, ^{ [self saveNoteToDropbox:(Note *)obj]; });
            }
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
    NSString *encodedTitle = convertToValidDropboxFilenames(note.title);
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
        NSString *encodedAttachmentName = convertToValidDropboxFilenames(attachment.filename);
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
        DLog(@"note %@ copied to dropbox.", note.title);
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

- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename {
    DLog(@"Delete note %@ in dropbox folder after change in filename from %@", uuid, oldFilename);
    DBError *error;
    NSString *encodedFilename = convertToValidDropboxFilenames(oldFilename);
    encodedFilename = [encodedFilename stringByAppendingFormat:@".%@", kNotesExtension];
    DBPath *noteTextPath = [[[DBPath root] childPath:uuid] childPath:encodedFilename];
    if(![[DBFilesystem sharedFilesystem] deletePath:noteTextPath error:&error]) {
        ALog(@"*** Error %d deleting note text after filename change at %@.", [error code], [noteTextPath stringValue]);
    } else {
        DLog(@"Note deleted.");
    }
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
*/
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
        NSArray *filesAtRoot = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.syncDirectory
                                                             includingPropertiesForKeys:@[NSURLIsDirectoryKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(!filesAtRoot) {
            ALog(@"Aborting. Error reading notes: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        for (DBFileInfo *fileInfo in filesAtRoot) {
            if(fileInfo.isFolder) {
                if([self saveDropboxNoteToCoreData:fileInfo.path]) {
                    if (![self.dataSyncThreadContext save:&error]) {
                        ALog(@"Error copying note %@ from dropbox to core data, error: %@", fileInfo.path.stringValue, [error description]);
                    }
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
- (BOOL)saveDropboxNoteToCoreData:(DBPath *)pathToNoteDir {
    // BEWARE that this code needs to be called in the _syncqueue dispatch_queue beacuse it's using dataSyncThreadContext
    Note *newNote = nil;
    DBError *error;
    NSMutableArray *filesInNoteDir = [[[DBFilesystem sharedFilesystem] listFolder:pathToNoteDir error:&error] mutableCopy];
    if(!filesInNoteDir) {
        ALog(@"Aborting. Error reading notes: %d (%@)", [error code], [error description]);
        return NO;
    }
    for (DBFileInfo *fileInfo in filesInNoteDir) {
        if(!fileInfo.isFolder) {
            // This is the note
            DLog(@"Copying note at path %@ to CoreData", fileInfo.path.name);
            newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
            newNote.uuid = pathToNoteDir.name;
            NSString *titolo = convertFromValidDropboxFilenames(fileInfo.path.name);
            if([titolo hasSuffix:kNotesExtension]) {
                titolo = [titolo substringToIndex:([titolo length] - 4)];
            }
            newNote.title = titolo;
            newNote.creationDate = newNote.timeStamp = fileInfo.modifiedTime;
            DBFile *noteOnDropbox = [[DBFilesystem sharedFilesystem] openFile:fileInfo.path error:&error];
            if(!noteOnDropbox) {
                ALog(@"Aborting note copy to coredata. Error opening note: %d (%@)", [error code], [error description]);
                [self.dataSyncThreadContext rollback];
                return NO;
            }
            if(!noteOnDropbox.status.state == DBFileStateIdle || !noteOnDropbox.status.cached) {
                // If the file is not stable, abort copy
                // TODO: make a queue for later loading
                DLog(@"File for note %@ is still not ready to copy. State: %d. Cached: %d", fileInfo.path.stringValue, noteOnDropbox.status.state, noteOnDropbox.status.cached);
                [self.dataSyncThreadContext rollback];
                return NO;
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
            return YES;
        }
        for (DBFileInfo *attachmentInfo in filesInAttachmentDir) {
            DLog(@"Copying attachment: %@ to CoreData note %@", attachmentInfo.path.name, newNote.title);
            DBFile *attachmentOnDropbox = [[DBFilesystem sharedFilesystem] openFile:attachmentInfo.path error:&error];
            if(!attachmentOnDropbox) {
                ALog(@"Aborting attachment copy to coredata. Error %d opening attachment %@", [error code], attachmentInfo.path.stringValue);
                continue;
            }
            if(!attachmentOnDropbox.status.state == DBFileStateIdle || !attachmentOnDropbox.status.cached) {
                // If the file is not stable, abort copy
                // TODO: make a queue for later loading
                DLog(@"Attachment file %@ is still not ready to copy. State: %d. Cached: %d", attachmentInfo.path.stringValue, attachmentOnDropbox.status.state, attachmentOnDropbox.status.cached);
                [self.dataSyncThreadContext rollback];
                return NO;
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
    return YES;
}

@end
