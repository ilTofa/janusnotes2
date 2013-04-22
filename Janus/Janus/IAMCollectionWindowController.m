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
#import "NSManagedObjectContext+FetchedObjectFromURI.h"
#import "Attachment.h"

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
    // Init sync mamagement
    [IAMFilesystemSyncController sharedInstance];
    [self.arrayController fetch:nil];
}

- (void)mergeSyncChanges:(NSNotification *)note {
    DLog(@"Merging data from sync Engine");
    DLog(@"MAINMERGESYNCDEBUGSECTION - BEGIN");
    NSDictionary *info = note.userInfo;
    NSSet *insertedObjects = [info objectForKey:NSInsertedObjectsKey];
    NSSet *deletedObjects = [info objectForKey:NSDeletedObjectsKey];
    NSSet *updatedObjects = [info objectForKey:NSUpdatedObjectsKey];
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
    DLog(@"MAINMERGESYNCDEBUGSECTION - END");

    [self.sharedManagedObjectContext mergeChangesFromContextDidSaveNotification:note];
    [self.arrayController fetch:nil];
}

#pragma mark - sync management

// Reload management
- (IBAction)refresh:(id)sender {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endSyncNotificationHandler:) name:kIAMDataSyncRefreshTerminated object:nil];
    [[IAMFilesystemSyncController sharedInstance] refreshContentFromRemote];
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
        // Create a local moc, children of the sync moc and delete there.
        DLog(@"User confirmed delete, now really deleting note.");
        NSManagedObjectContext *moc = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSConfinementConcurrencyType];
        [moc setParentContext:[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext];
        NSURL *uri = [[[self.arrayController selectedObjects][0] objectID] URIRepresentation];
        Note *delenda = (Note *)[moc objectWithURI:uri];
        DLog(@"About to delete note: %@", delenda);
        [moc deleteObject:delenda];
        NSError *error;
        if(![moc save:&error])
            ALog(@"Unresolved error %@, %@", error, [error userInfo]);
        // Save on parent context
        [[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext performBlock:^{
            NSError *localError;
            if(![[IAMFilesystemSyncController sharedInstance].dataSyncThreadContext save:&localError])
                ALog(@"Unresolved error saving parent context %@, %@", error, [error userInfo]);
        }];
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
