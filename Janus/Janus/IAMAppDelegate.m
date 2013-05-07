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

#import "PTTimerDispatchStrategy.h"

#define PIWIK_URL @"http://piwik.iltofa.com/"
#define SITE_ID_TEST @"5"

@interface IAMAppDelegate ()

@property (strong) IAMPrefsWindowController *prefsController;

@property (nonatomic, strong) PTTimerDispatchStrategy *timerStrategy;

@end

@implementation IAMAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectContext = _managedObjectContext;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    // Init core data (and iCloud)
    _coreDataController = [[CoreDataController alloc] init];
    // [_coreDataController nukeAndPave];
    [_coreDataController loadPersistentStores];
    // Get the shared tracker and init it.
    self.tracker = [PiwikTracker sharedTracker];
    [self startTracker:self];
    // Set base font if not set
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    if(!fontName) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Lucida Grande" forKey:@"fontName"];
        [[NSUserDefaults standardUserDefaults] setDouble:13.0 forKey:@"fontSize"];
    }
    self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
    [self.collectionController showWindow:self];
    [self deleteCache];
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

#pragma mark - piwik tracker

- (IBAction)startTracker:(id)sender {
    DLog(@"Start the Tracker");
    // Start the tracker. This also creates a new session.
    NSError *error = nil;
    [self.tracker startTrackerWithPiwikURL:PIWIK_URL
                                    siteID:SITE_ID_TEST
                       authenticationToken:nil
                                 withError:&error];
    self.tracker.dryRun = NO;
    // Start the timer dispatch strategy
    self.timerStrategy = [PTTimerDispatchStrategy strategyWithErrorBlock:^(NSError *error) {
        NSLog(@"The timer strategy failed to initated dispatch of analytic events");
    }];
    self.timerStrategy.timeInteraval = 20; // Set the time interval to 20s, default value is 3 minutes
    [self.timerStrategy startDispatchTimer];
}


- (IBAction)stopTracker:(id)sender {
    DLog(@"Stop the Tracker");
    // Stop the Tracker from accepting new events
    [self.tracker stopTracker];
    // Stop the time strategy
    [self.timerStrategy stopDispatchTimer];
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
    [self.tracker stopTracker];
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
