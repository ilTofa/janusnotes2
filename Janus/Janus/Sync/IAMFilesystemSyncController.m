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
            BOOL staleData;
            self.syncDirectory = [NSURL URLByResolvingBookmarkData:self.secureBookmarkToData options:NSURLBookmarkResolutionWithSecurityScope  relativeToURL:nil bookmarkDataIsStale:&staleData error:&error];
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
    BOOL staleData;
    self.syncDirectory = [NSURL URLByResolvingBookmarkData:self.secureBookmarkToData options:NSURLBookmarkResolutionWithSecurityScope  relativeToURL:nil bookmarkDataIsStale:&staleData error:&error];
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

// Copy all coredata db to dropbox (this is only if we move to a new directory for syncing)
- (void)copyDataToDropbox {
    dispatch_async(_syncQueue, ^{
        DLog(@"Started copy of coredata db to dropbox (new directory here).");
        // Get notes ids
        NSError *error;
        NSArray *filesAtRoot = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.syncDirectory
                                                             includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(!filesAtRoot) {
            ALog(@"Aborting. Error reading notes: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        NSMutableArray *notesOnFS = [[NSMutableArray alloc] initWithCapacity:5];
        for (NSURL *fileInfo in filesAtRoot) {
            NSNumber *isDirectory;
            NSString *name;
            if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
                ALog(@"error looking for filename: %@", [error localizedDescription]);
                error = nil;
            }
            if (![fileInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
                ALog(@"Error looking for directory type: %@", [error localizedDescription]);
                error = nil;
            }
            if(isDirectory) {
                [notesOnFS addObject:fileInfo];
                DLog(@"Fuond note: %@", fileInfo);
            } else {
                DLog(@"Spurious file at notes root: %@.", name);
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
            for (NSURL *fileinfo in notesOnFS) {
                NSString *name;
                if (![fileinfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
                    ALog(@"error looking for filename: %@", [error localizedDescription]);
                    error = nil;
                }
                if([[[fileinfo path] lastPathComponent] caseInsensitiveCompare:note.uuid] == NSOrderedSame) {
                    found = YES;
                }
            }
            if(!found)
                [self saveNoteToDropbox:note];
        }
        DLog(@"End copy of coredata db to dropbox.");
    });
}

// Save the passed note to dropbox
- (void)saveNoteToDropbox:(Note *)note {
    DLog(@"Copying note %@ (%ld attachments) to dropbox.", note.title, (unsigned long)[note.attachment count]);
    NSError *error;
    // Create folder (named after uuid)
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:note.uuid isDirectory:YES];
    if(![[NSFileManager defaultManager] createDirectoryAtURL:notePath withIntermediateDirectories:YES attributes:nil error:&error]) {
        DLog(@"Creating folder to save note. Error could be 'normal'. Error creating folder at %@: %@.", notePath, [error description]);
    }
    // write note
    NSString *encodedTitle = convertToValidDropboxFilenames(note.title);
    if(![[encodedTitle pathExtension] isEqualToString:kNotesExtension])
        encodedTitle = [encodedTitle stringByAppendingFormat:@".%@", kNotesExtension];
    NSURL *noteTextPath = [notePath URLByAppendingPathComponent:encodedTitle isDirectory:NO];
    if(![note.text writeToURL:noteTextPath atomically:YES encoding:NSUTF8StringEncoding error:&error]) {
        DLog(@"Error writing note text saving to dropbox at %@: %@.", noteTextPath, [error description]);
    }
    // Now write all the attachments
    NSURL *attachmentPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    for (Attachment *attachment in note.attachment) {
        // write attachment
        NSString *encodedAttachmentName = convertToValidDropboxFilenames(attachment.filename);
        NSURL *attachmentDataPath = [attachmentPath URLByAppendingPathComponent:encodedAttachmentName isDirectory:NO];
        if([attachment.data writeToURL:attachmentDataPath atomically:YES]) {
            DLog(@"Error writing attachment data at %@ for note %@: %@", attachmentDataPath, note.title, [error description]);
        }
    }
    // Now ensure that no stale attachments are still in the dropbox
    NSURL *attachmentsPath = [notePath URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
    NSArray *attachmentFiles =  [[NSFileManager defaultManager] contentsOfDirectoryAtURL:attachmentsPath
                                                                   includingPropertiesForKeys:@[NSURLNameKey]
                                                                                      options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
    if(!attachmentFiles || [attachmentFiles count] == 0) {
        // No attachments directory -> No attachments
        DLog(@"note %@ copied to dropbox.", note.title);
        return;
    }

    for (NSURL *fileInfo in attachmentFiles) {
        BOOL found = NO;
        NSString *name;
        if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
            ALog(@"error looking for filename: %@", [error localizedDescription]);
            error = nil;
        }
        for (Attachment *attachments in note.attachment) {
            if([attachments.filename isEqualToString:name]) {
                found = YES;
            }
        }
        if(!found) {
            // Delete attachment file
            [[NSFileManager defaultManager] removeItemAtURL:fileInfo error:&error];
        }
    }
    DLog(@"note %@ copied to dropbox.", note.title);
}

- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename {
    DLog(@"Delete note %@ in dropbox folder after change in filename from %@", uuid, oldFilename);
    NSError *error;
    NSString *encodedFilename = convertToValidDropboxFilenames(oldFilename);
    encodedFilename = [encodedFilename stringByAppendingFormat:@".%@", kNotesExtension];
    NSURL *noteTextPath = [[self.syncDirectory URLByAppendingPathComponent:uuid isDirectory:YES] URLByAppendingPathComponent:encodedFilename isDirectory:NO];
    if(![[NSFileManager defaultManager] removeItemAtURL:noteTextPath error:&error]) {
        ALog(@"*** Error deleting note text after filename change at %@: %@", noteTextPath, [error description]);
    } else {
        DLog(@"Note deleted.");
    }
}

- (void)deleteNoteInDropbox:(Note *)note {
    DLog(@"Delete note in dropbox folder");
    NSError *error;
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:note.uuid isDirectory:YES];
    if(![[NSFileManager defaultManager] removeItemAtURL:notePath error:&error]) {
        ALog(@"*** Error deleting note at %@: %@", notePath, [error description]);
    }
}

- (void)deleteAttachmentInDropbox:(Attachment *)attachment {
    NSError *error;
    NSURL *notePath = [self.syncDirectory URLByAppendingPathComponent:attachment.note.uuid isDirectory:YES];
    NSURL *attachmentPath = [notePath URLByAppendingPathComponent:attachment.filename isDirectory:NO];
    if(![[NSFileManager defaultManager] removeItemAtURL:attachmentPath error:&error]) {
        ALog(@"*** Error deleting attachment at %@: %@",attachmentPath, [error description]);
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
        NSArray *filesAtRoot = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:self.syncDirectory
                                                             includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                                                options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(!filesAtRoot) {
            ALog(@"Aborting. Error reading notes: %@", [error description]);
            [self.dataSyncThreadContext rollback];
            return;
        }
        for (NSURL *fileInfo in filesAtRoot) {
            NSNumber *isDirectory;
            NSString *name;
            if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
                ALog(@"error looking for filename: %@", [error localizedDescription]);
                error = nil;
            }
            if (![fileInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
                ALog(@"Error looking for directory type: %@", [error localizedDescription]);
                error = nil;
            }
            if(isDirectory) {
                if([self saveDropboxNoteToCoreData:fileInfo]) {
                    if (![self.dataSyncThreadContext save:&error]) {
                        ALog(@"Error copying note %@ from dropbox to core data, error: %@", name, [error description]);
                    }
                }
            } else {
                DLog(@"Deleting spurious file at notes root: %@.", name);
                [[NSFileManager defaultManager] removeItemAtURL:fileInfo error:&error];
            }
        }
        DLog(@"Syncronization end");
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncRefreshTerminated object:self]];
        });
    });
}

// Save the note from dropbox folder to CoreData
- (BOOL)saveDropboxNoteToCoreData:(NSURL *)pathToNoteDir {
    // BEWARE that this code needs to be called in the _syncqueue dispatch_queue beacuse it's using dataSyncThreadContext
    Note *newNote = nil;
    NSError *error;
    NSMutableArray *filesInNoteDir = [[[NSFileManager defaultManager] contentsOfDirectoryAtURL:pathToNoteDir
                                                                    includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey, NSURLContentModificationDateKey]
                                                                                       options:NSDirectoryEnumerationSkipsHiddenFiles error:&error] mutableCopy];
    if(!filesInNoteDir) {
        ALog(@"Aborting. Error reading notes: %@", [error description]);
        return NO;
    }
    for (NSURL *fileInfo in filesInNoteDir) {
        NSNumber *isDirectory;
        NSString *name;
        NSDate *modificationDate;
        if (![fileInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
            ALog(@"error looking for filename: %@", [error localizedDescription]);
            error = nil;
        }
        if (![fileInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
            ALog(@"Error looking for directory type: %@", [error localizedDescription]);
            error = nil;
        }
        if (![fileInfo getResourceValue:&modificationDate forKey:NSURLContentModificationDateKey error:&error]) {
            ALog(@"Error looking for modificationDate: %@", [error localizedDescription]);
            error = nil;
        }
        if(!isDirectory) {
            // This is the note
            DLog(@"Copying note at path %@ to CoreData", name);
            newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.dataSyncThreadContext];
            newNote.uuid = [[pathToNoteDir path] lastPathComponent];
            NSString *titolo = convertFromValidDropboxFilenames([[fileInfo path] lastPathComponent]);
            if([titolo hasSuffix:kNotesExtension]) {
                titolo = [titolo substringToIndex:([titolo length] - 4)];
            }
            newNote.title = titolo;
            newNote.creationDate = newNote.timeStamp = modificationDate;
            newNote.text = [[NSString alloc] initWithContentsOfURL:fileInfo encoding:NSUTF8StringEncoding error:&error];
            if(!newNote.text) {
                ALog(@"Serious error reading note %@: %@", fileInfo, [error description]);
            }
            break;
        }
    }
    // Now copy attachment(s) (if note exists)
    if(newNote) {
        NSURL *attachmentsPath = [pathToNoteDir URLByAppendingPathComponent:kAttachmentDirectory isDirectory:YES];
        NSArray *filesInAttachmentDir =  [[NSFileManager defaultManager] contentsOfDirectoryAtURL:attachmentsPath
                                                                       includingPropertiesForKeys:@[NSURLIsDirectoryKey, NSURLNameKey]
                                                                                          options:NSDirectoryEnumerationSkipsHiddenFiles error:&error];
        if(!filesInAttachmentDir || [filesInAttachmentDir count] == 0) {
            // No attachments directory -> No attachments
            DLog(@"Cannot list attachment directory for note %@, no attachments then.", newNote.title);
            return YES;
        }
        for (NSURL *attachmentInfo in filesInAttachmentDir) {
            NSNumber *isDirectory;
            NSString *name;
            if (![attachmentInfo getResourceValue:&name forKey:NSURLNameKey error:&error]) {
                ALog(@"error looking for filename: %@", [error localizedDescription]);
                error = nil;
            }
            if (![attachmentInfo getResourceValue:&isDirectory forKey:NSURLIsDirectoryKey error:&error]) {
                ALog(@"Error looking for directory type: %@", [error localizedDescription]);
                error = nil;
            }
            DLog(@"Copying attachment: %@ to CoreData note %@", name, newNote.title);
            Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.dataSyncThreadContext];
            newAttachment.filename = [[attachmentInfo path] lastPathComponent];
            newAttachment.extension = attachmentInfo.path.pathExtension;
            newAttachment.data = [NSData dataWithContentsOfURL:attachmentInfo options:NSDataReadingMappedIfSafe error:&error];
            if(!newAttachment.data) {
                ALog(@"Serious error (data loss?) reading attachment %@: %@", attachmentInfo, [error description]);
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
