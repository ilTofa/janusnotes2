//
//  IAMCollectionWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 20/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMCollectionWindowController.h"

#import "IAMNoteEditorWC.h"
#import "IAMAppDelegate.h"
#import "CoreDataController.h"
#import "IAMFileSystemSyncController.h"

@interface IAMCollectionWindowController () <IAMNoteEditorWCDelegate>

@property (strong, nonatomic) NSMutableArray *noteWindowControllers;
@property (weak) IBOutlet NSSearchFieldCell *searchField;

@property NSTimer *syncStatusTimer;

- (IBAction)addNote:(id)sender;
- (IBAction)editNote:(id)sender;
- (IBAction)searched:(id)sender;
- (IBAction)deleteNote:(id)sender;

@end

@implementation IAMCollectionWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        _noteWindowControllers = [[NSMutableArray alloc] initWithCapacity:1];
    }
    
    return self;
}

// Startup sequence
// when coredata is loaded exec coredataisready
// register for sync data (mergeSyncChanges:) from datasync thread

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.sharedManagedObjectContext = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.mainThreadContext;
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = @[dateAddedSortDesc];
    [self.arrayController setSortDescriptors:sortDescriptors];
    DLog(@"Array controller: %@", self.arrayController);
    // If db is still to be loaded, register to be notified else go directly
    if(!((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.coreDataIsReady)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coreDataIsReady:) name:GTCoreDataReady object:nil];
    else
        [self coreDataIsReady:nil];
}

- (void)coreDataIsReady:(NSNotification *)notification {
    if(notification)
        DLog(@"called with notification %@", notification);
    else
        DLog(@"called directly from init");
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    NSManagedObjectContext *syncMOC = [IAMFilesystemSyncController sharedInstance].dataSyncThreadContext;
    NSAssert(syncMOC, @"The Managed Object Context for the Sync Engine is still not set while setting main view.");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeSyncChanges:) name:NSManagedObjectContextDidSaveNotification object:syncMOC];
    if([IAMFilesystemSyncController sharedInstance].syncControllerReady)
        [self refreshControlSetup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreNotificationHandler:) name:kIAMDataSyncControllerReady object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreNotificationHandler:) name:kIAMDataSyncControllerStopped object:nil];
    [self.arrayController fetch:nil];
}

- (void)shouldRefresh:(NSNotification *)notification {
    DLog(@"called for %@", notification.name);
    [self.arrayController fetch:nil];
}

- (void)mergeSyncChanges:(NSNotification *)note {
    DLog(@"Merging data from sync Engine");
    [self.sharedManagedObjectContext mergeChangesFromContextDidSaveNotification:note];
    // Reset the moc, so we don't get changes back to the background moc.
    [self.sharedManagedObjectContext reset];
    [self.arrayController fetch:nil];
}

- (void)shouldMergeChanges:(NSNotification *)notification {
    DLog(@"called for %@", notification.name);
    [self.sharedManagedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    [self.arrayController fetch:nil];
}

#pragma mark - sync management

- (void)refreshControlSetup {
    // Here we are sure there is an active dropbox link
    self.syncStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(syncStatus:) userInfo:nil repeats:YES];
}

-(void)syncStatus:(NSTimer *)timer {
    
    DBSyncStatus status = [[DBFilesystem sharedFilesystem] status];
    NSMutableString *title = [[NSMutableString alloc] initWithString:@"Sync "];
    if(!status) {
        // If all is quiet and dropbox says it's fully synced (and it was not before), then reload (only if last reload were more than 45 seconds ago).
        title = [NSLocalizedString(@"Notes ", nil) mutableCopy];
        [title appendString:@"✔"];
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:NO];
        if(self.dropboxSyncronizedSomething && [self.lastDropboxSync timeIntervalSinceNow] < -45.0) {
            DLog(@"Dropbox synced everything, time to reload! Last reload %.0f seconds ago", -[self.lastDropboxSync timeIntervalSinceNow]);
            self.dropboxSyncronizedSomething = NO;
            self.lastDropboxSync = [NSDate date];
            [[IAMDataSyncController sharedInstance] refreshContentFromRemote];
        }
    } else {
        [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
    }
    if(status & DBSyncStatusSyncing)
        [title appendString:@"␖"];
    if(status & DBSyncStatusDownloading) {
        [title appendString:@"↓"];
        self.dropboxSyncronizedSomething = YES;
    }
    if(status & DBSyncStatusUploading)
        [title appendString:@"↑"];
    self.title = title;
}

// Reload management
- (IBAction)refresh:(id)sender {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endSyncNotificationHandler:) name:kIAMDataSyncRefreshTerminated object:nil];
    [[IAMDataSyncController sharedInstance] refreshContentFromRemote];
}

- (void)syncStoreNotificationHandler:(NSNotification *)note {
    IAMDataSyncController *controller = note.object;
    if(controller.syncControllerReady) {
        [self refreshControlSetup];
        self.lastDropboxSync = [NSDate date];
    }
    else {
        self.refreshControl = nil;
        if(self.syncStatusTimer) {
            [self.syncStatusTimer invalidate];
            self.syncStatusTimer = nil;
        }
    }
    if(self.hud) {
        [self.hud hide:YES];
        self.hud = nil;
    }
}

- (void)endSyncNotificationHandler:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kIAMDataSyncRefreshTerminated object:nil];
}

#pragma mark - Notes Editing management

// This event comes from the collection item view subclass
- (IBAction)collectionItemViewDoubleClick:(id)sender {
    if([[self.arrayController selectedObjects] count] != 0) {
        DLog(@"Double click detected in collection view, sending event to editNote:");
        [self editNote:sender];
    } else {
        DLog(@"Double click detected in collection view, but no collection is selected. This should not happen");
    }
}

- (IBAction)addNote:(id)sender {
    DLog(@"This is addNote handler in MainWindowController");
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    [noteEditor showWindow:self];
}

- (IBAction)editNote:(id)sender {
    DLog(@"Selected note for editing is: %@", [self.arrayController selectedObjects][0]);
    IAMNoteEditorWC *noteEditor = [[IAMNoteEditorWC alloc] initWithWindowNibName:@"IAMNoteEditorWC"];
    [noteEditor setDelegate:self];
    [noteEditor setEditedNote:[self.arrayController selectedObjects][0]];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    [noteEditor showWindow:self];
}

- (IBAction)deleteNote:(id)sender {
    DLog(@"Selected note for deleting is: %@", [self.arrayController selectedObjects][0]);
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the note?", nil)];
    [alert setMessageText:NSLocalizedString(@"Warning", @"")];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertSecondButtonReturn)
    {
        DLog(@"User confirmed delete, now really deleting note.");
        [self.arrayController removeObject:[self.arrayController selectedObjects][0]];
        NSError *error;
        if(![self.sharedManagedObjectContext save:&error])
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
}

- (IBAction)searched:(id)sender {
    DLog(@"Search string is %@", [self.searchField stringValue]);
    NSString *queryString = nil;
    if(![[self.searchField stringValue] isEqualToString:@""])
    {
        // Complex NSPredicate needed to match any word in the search string
        DLog(@"Fetching again. Query string is: '%@'", [self.searchField stringValue]);
        NSArray *terms = [[self.searchField stringValue] componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        for(NSString *term in terms)
        {
            if([term length] == 0)
                continue;
            if(queryString == nil)
                queryString = [NSString stringWithFormat:@"(text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
            else
                queryString = [queryString stringByAppendingFormat:@" AND (text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
        }
    }
    else
        queryString = @"text  like[c] \"*\"";
    DLog(@"Fetching again. Query string is: '%@'", queryString);
    [self.arrayController setFilterPredicate:[NSPredicate predicateWithFormat:queryString]];
    [self.arrayController fetch:nil];
}

-(void)IAMNoteEditorWCDidCloseWindow:(IAMNoteEditorWC *)windowController
{
    // Note editor closed, now find and delete it from our controller array (so to allow ARC dealloc it)
    for (IAMNoteEditorWC *storedController in self.noteWindowControllers) {
        if(storedController == windowController) {
            [self.noteWindowControllers removeObject:storedController];
        }
    }
}


@end
