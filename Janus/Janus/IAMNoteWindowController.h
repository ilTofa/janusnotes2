//
//  IAMNoteWindowController.h
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Note.h"

@class IAMNoteWindowController;

@protocol IAMNoteWindowControllerDelegate <NSObject>

-(void)IAMNoteWindowControllerDidCloseWindow:(IAMNoteWindowController *)windowController;

@end

@interface IAMNoteWindowController : NSWindowController

@property Note *editedNote;
@property (weak, nonatomic) id<IAMNoteWindowControllerDelegate> delegate;

@end
