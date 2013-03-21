//
//  IAMCollectionWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 20/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMCollectionWindowController.h"

#import "IAMNoteWindowController.h"
#import "IAMAppDelegate.h"

@interface IAMCollectionWindowController () <IAMNoteWindowControllerDelegate>

@property (strong, nonatomic) NSMutableArray *noteWindowControllers;

- (IBAction)addNote:(id)sender;
- (IBAction)editNote:(id)sender;

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
}

- (void)pscChanged:(NSNotification *)notification
{
    DLog(@"called for: %@", notification);
//    self.sharedManagedObjectContext = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).coreDataController.mainThreadContext;
    //    [self.arrayController setAutomaticallyPreparesContent:YES];
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
    IAMNoteWindowController *noteEditor = [[IAMNoteWindowController alloc] initWithWindowNibName:@"IAMNoteWindowController"];
    [noteEditor setDelegate:self];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    [noteEditor showWindow:self];
}

- (IBAction)editNote:(id)sender {
    DLog(@"Selected note for editing is: %@", [self.arrayController selectedObjects][0]);
    IAMNoteWindowController *noteEditor = [[IAMNoteWindowController alloc] initWithWindowNibName:@"IAMNoteWindowController"];
    [noteEditor setDelegate:self];
    [noteEditor setEditedNote:[self.arrayController selectedObjects][0]];
    // Preserve a reference to the controller to keep ARC happy
    [self.noteWindowControllers addObject:noteEditor];
    [noteEditor showWindow:self];
}

-(void)IAMNoteWindowControllerDidCloseWindow:(IAMNoteWindowController *)windowController
{
    // Note editor closed, now find and delete it from our controller array (so to allow ARC dealloc it)
    for (IAMNoteWindowController *storedController in self.noteWindowControllers) {
        if(storedController == windowController) {
            [self.noteWindowControllers removeObject:storedController];
        }
    }
}


@end
