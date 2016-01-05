//
//  IAMNoteWindowController.h
// Turms
//
//  Created by Giacomo Tufano on 18/03/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Cocoa/Cocoa.h>

#import "Note.h"

@class IAMNoteEditorWC;

@protocol IAMNoteEditorWCDelegate <NSObject>

-(void)IAMNoteEditorWCDidCloseWindow:(IAMNoteEditorWC *)windowController;

@end

@interface IAMNoteEditorWC : NSWindowController

@property (getter = isCalledFromURL) BOOL calledFromUrl;
@property (copy) NSString *calledTitle;
@property (copy) NSString *calledURL;
@property (copy) NSString *calledText;

@property NSManagedObjectID *idForTheNoteToBeEdited;
@property (assign, nonatomic) id<IAMNoteEditorWCDelegate> delegate;
@property (strong, atomic) IBOutlet NSManagedObjectContext *noteEditorMOC;
@property NSArray *attachmentsArray;
@property NSArray *booksArray;
@property NSFont *editorFont;

- (IBAction)saveAndContinue:(id)sender;
- (IBAction)saveAndClose:(id)sender;
- (IBAction)closeWithoutSave:(id)sender;
- (IBAction)addAttachment:(id)sender;
- (IBAction)deleteAttachment:(id)sender;
- (IBAction)previewMarkdown:(id)sender;

- (IBAction)exportText:(id)sender;
- (IBAction)exportHTML:(id)sender;
- (IBAction)exportMarkdownForPelican:(id)sender;

- (IBAction)showAttachmentInFinder:(id)sender;

@end
