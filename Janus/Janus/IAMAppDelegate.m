//
//  IAMAppDelegate.m
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

#import "IAMFilesystemSyncController.h"
#import "IAMPrefsWindowController.h"
#import "Appirater.h"

@interface IAMAppDelegate ()

@property (strong) IAMPrefsWindowController *prefsController;

@end

@implementation IAMAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectContext = _managedObjectContext;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DLog(@"Starting application init");
    // Init appirater
    [Appirater setAppId:@"651141191"];
    [Appirater setDaysUntilPrompt:5];
    [Appirater setUsesUntilPrompt:8];
    [Appirater setSignificantEventsUntilPrompt:-1];
    [Appirater setTimeBeforeReminding:2];
    [Appirater setDebug:NO];
    [Appirater appLaunched:YES];
    // Init core data (and iCloud)
    _coreDataController = [[CoreDataController alloc] init];
    // [_coreDataController nukeAndPave];
    [_coreDataController loadPersistentStores];
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    if(!fontName) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Lucida Grande" forKey:@"fontName"];
        [[NSUserDefaults standardUserDefaults] setDouble:13.0 forKey:@"fontSize"];
    }
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
        [self.collectionController showWindow:self];
    }
    [self deleteCache];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    DLog(@"App called to open %@", filename);
    BOOL retValue = NO;
    if (filename && [filename hasSuffix:@"janus"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
            [self openFile:filename];
        });
    }
    return retValue;
}

- (void)openFile:(NSString *)filename {
    // Decode URI from path.
    NSURL *objectURI = [[NSPersistentStoreCoordinator elementsDerivedFromExternalRecordURL:[NSURL fileURLWithPath:filename]] objectForKey:NSObjectURIKey];
    if (objectURI) {
        NSManagedObjectID *moid = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:objectURI];
        if (moid) {
            NSManagedObject *mo = [[self managedObjectContext] objectWithID:moid];
            if(!self.collectionController) {
                ALog(@"Bad news. Init is *really* slow today, aborting open");
                return;
            }
            NSURL *uri = [[mo objectID] URIRepresentation];
            DLog(@"Send note URL to the main UI for opening: %@", uri);
            [self.collectionController openNoteAtURI:uri];
        } else {
            ALog(@"Error: no NSManagedObjectID for %@", objectURI);
        }
    } else {
        ALog(@"Error: no objectURI for %@", filename);
    }
}

// Returns the directory the application uses to store the Core Data store file. This code uses a directory named "it.iltofa.Janus" in the user's Application Support directory.
- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"it.iltofa.Janus"];
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    return self.coreDataController.psc;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) 
- (NSManagedObjectContext *)managedObjectContext
{
    return self.coreDataController.mainThreadContext;
}

// Returns the NSUndoManager for the application. In this case, the manager returned is that of the managed object context for the application.
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window
{
    return [[self managedObjectContext] undoManager];
}

// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

- (IBAction)preferencesAction:(id)sender {
    if(!self.prefsController) {
        self.prefsController = [[IAMPrefsWindowController alloc] initWithWindowNibName:@"IAMPrefsWindowController"];
    }
    // sender is nil, this is called because we need a password now...
    if(!sender) {
        self.prefsController.aPasswordIsNeededASAP = YES;
    }
    [self.prefsController showWindow:self];
}

- (IBAction)notesWindowAction:(id)sender {
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
    }
    [self.collectionController showUIWindow:self];
}

- (IBAction)newNoteAction:(id)sender {
    [self.collectionController addNote:sender];
}

- (IBAction)editNoteAction:(id)sender {
    [self.collectionController editNote:sender];
}

- (IBAction)closeNoteAction:(id)sender {
    [self.collectionController.window performClose:sender];
}

- (IBAction)deleteNoteAction:(id)sender {
    [self.collectionController deleteNote:sender];
}

- (IBAction)refreshNotesAction:(id)sender {
    [self.collectionController refresh:sender];
}

- (IBAction)showInFinderAction:(id)sender {
    [self.collectionController showInFinder:sender];
}

- (IBAction)saveNoteAndContinueAction:(id)sender {
    [self.collectionController saveNoteAndContinueAction:sender];
}

- (IBAction)saveNoteAndCloseAction:(id)sender {
    [self.collectionController saveNoteAndCloseAction:sender];
}

- (IBAction)closeNote:(id)sender {
    [self.collectionController closeNote:sender];
}

- (IBAction)addAttachmentToNoteAction:(id)sender {
    [self.collectionController addAttachmentToNoteAction:sender];
}

- (IBAction)removeAttachmentFromNoteAction:(id)sender {
    [self.collectionController removeAttachmentFromNoteAction:sender];
}

- (IBAction)getIOSApp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id651150600"]];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
    return NSTerminateNow;
}

#pragma mark - cache management

- (void)deleteCache {
    // Async load, please (so don't use defaultManager, not thread safe)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileMgr = [[NSFileManager alloc] init];
        NSError *error;
        NSString *directory = [[fileMgr URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error] path];
        NSArray *fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
        for (NSString *filename in fileArray)  {
            [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
        }
        fileMgr = nil;
    });
}

//- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)theApplication {
//    return YES;
//}

@end
