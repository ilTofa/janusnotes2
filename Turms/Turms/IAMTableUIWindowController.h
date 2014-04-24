//
//  IAMTableUIWindowController.h
// Turms
//
//  Created by Giacomo Tufano on 22/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "IAMBooksWindowController.h"

@interface IAMTableUIWindowController : NSWindowController

@property (weak, atomic) NSManagedObjectContext *sharedManagedObjectContext;
@property (assign) IBOutlet NSArrayController *arrayController;
@property (assign) IBOutlet NSTableView *theTable;

@property (strong) IBOutlet IAMBooksWindowController *theBookController;

- (IBAction)showUIWindow:(id)sender;
@property (weak) IBOutlet NSMenuItem *notesWindowMenuItem;

@property (strong, nonatomic) NSMutableArray *noteWindowControllers;
@property IBOutlet NSNumber *noteEditorIsShown;

@property NSNumber *booksListIsShown;

- (IBAction)addNote:(id)sender;
- (IBAction)editNote:(id)sender;
- (IBAction)searched:(id)sender;
- (IBAction)deleteNote:(id)sender;
- (IBAction)actionPreferences:(id)sender;
- (IBAction)showBooksAction:(id)sender;

// Called directly from main menu
- (IBAction)backupNotesArchive:(id)sender;
- (IBAction)restoreNotesArchive:(id)sender;

// called from openFile in apdelegate
- (void)openNoteAtURI:(NSURL *)uri;

// Eventually called from main menu
- (IBAction)exportHTML:(id)sender;
- (IBAction)exportMarkdownForPelican:(id)sender;

@end
