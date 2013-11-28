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
- (IBAction)showInFinder:(id)sender;
- (IBAction)showBooksAction:(id)sender;

// Note editor actions from main menu
- (IBAction)saveNoteAndContinueAction:(id)sender;
- (IBAction)saveNoteAndCloseAction:(id)sender;
- (IBAction)closeNote:(id)sender;
- (IBAction)addAttachmentToNoteAction:(id)sender;
- (IBAction)removeAttachmentFromNoteAction:(id)sender;

// called from openFile in apdelegate
- (void)openNoteAtURI:(NSURL *)uri;

@end
