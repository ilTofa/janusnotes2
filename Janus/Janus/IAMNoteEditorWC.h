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
@property (weak, nonatomic) id<IAMNoteEditorWCDelegate> delegate;

@end
