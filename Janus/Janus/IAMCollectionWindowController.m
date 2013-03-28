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

@interface IAMCollectionWindowController () <IAMNoteEditorWCDelegate>

@property (strong, nonatomic) NSMutableArray *noteWindowControllers;
@property (weak) IBOutlet NSSearchFieldCell *searchField;

- (IBAction)addNote:(id)sender;
- (IBAction)editNote:(id)sender;
- (IBAction)searched:(id)sender;

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

- (void)windowDidLoad
{
    [super windowDidLoad];
    
    self.sharedManagedObjectContext = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.mainThreadContext;
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = @[dateAddedSortDesc];
    [self.arrayController setSortDescriptors:sortDescriptors];
    DLog(@"Array controller: %@", self.arrayController);
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pscChanged:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pscChanged:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldRefresh:) name:NSManagedObjectContextObjectsDidChangeNotification object:self.sharedManagedObjectContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldMergeChanges:) name:NSManagedObjectContextDidSaveNotification object:self.sharedManagedObjectContext];
    // If db is still to be loaded, register to be notified.
    if(!((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.coreDataIsReady)
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(coreDataIsReady:) name:GTCoreDataReady object:nil];
}

- (void)coreDataIsReady:(NSNotification *)notification {
    DLog(@"called with notification %@", notification);
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pscChanged:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(pscChanged:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldRefresh:) name:NSManagedObjectContextObjectsDidChangeNotification object:self.sharedManagedObjectContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(shouldMergeChanges:) name:NSManagedObjectContextDidSaveNotification object:self.sharedManagedObjectContext];
    [self.arrayController fetch:nil];
}

- (void)pscChanged:(NSNotification *)notification
{
    DLog(@"called for %@", notification.name);
    [self.arrayController fetch:nil];
}

- (void)shouldRefresh:(NSNotification *)notification {
    DLog(@"called for %@", notification.name);
    [self.arrayController fetch:nil];
}

- (void)shouldMergeChanges:(NSNotification *)notification {
    DLog(@"called for %@", notification.name);
    [self.sharedManagedObjectContext mergeChangesFromContextDidSaveNotification:notification];
    [self.arrayController fetch:nil];
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
