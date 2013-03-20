//
//  IAMMainWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 20/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMMainWindowController.h"

#import "IAMAppDelegate.h"
#import "IAMNoteWindowController.h"

@interface IAMMainWindowController () <IAMNoteWindowControllerDelegate>

@property NSMutableArray *noteWindowControllers;

- (IBAction)addNote:(id)sender;

@end

@implementation IAMMainWindowController

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
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

#pragma mark - Notes Editing management

- (IBAction)addNote:(id)sender {
    DLog(@"This is addNote handler in MainWindowController");
    IAMNoteWindowController *noteEditor = [[IAMNoteWindowController alloc] initWithWindowNibName:@"IAMNoteWindowController"];
    [noteEditor setDelegate:self];
    // Preserve a reference to the controller to keer ARC happy
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
