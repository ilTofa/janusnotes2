//
//  IAMNoteWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteWindowController.h"

#import "IAMAppDelegate.h"

@interface IAMNoteWindowController () <NSWindowDelegate>

@property (weak) IBOutlet NSTextField *title;
@property (weak) IBOutlet NSScrollView *text;

- (IBAction)save:(id)sender;

@end

@implementation IAMNoteWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    DLog(@"This is IAMNoteWindowController's windowDidLoad.");
    // Create a new note
    IAMAppDelegate *appDelegate = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]);
    Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.managedObjectContext];
    self.editedNote = newNote;
}

- (IBAction)save:(id)sender
{
    DLog(@"This is IAMNoteWindowController's save.");
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    // Notify delegate that we're closing ourselves
    DLog(@"Notifying delegate.");
    if(self.delegate)
        [self.delegate IAMNoteWindowControllerDidCloseWindow:self];
}

@end
