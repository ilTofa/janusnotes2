//
//  IAMNoteWindowController.h
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Note.h"

@class IAMNoteEditorWC;

@protocol IAMNoteEditorWCDelegate <NSObject>

-(void)IAMNoteEditorWCDidCloseWindow:(IAMNoteEditorWC *)windowController;

@end

@interface IAMNoteEditorWC : NSWindowController

@property Note *editedNote;
@property (assign, nonatomic) id<IAMNoteEditorWCDelegate> delegate;
@property (strong, atomic) IBOutlet NSManagedObjectContext *noteEditorMOC;
@property NSArray *attachmentsArray;
@property NSFont *editorFont;

@end
