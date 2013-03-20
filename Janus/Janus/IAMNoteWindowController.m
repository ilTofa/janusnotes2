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
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    DLog(@"This is IAMNoteWindowController's windowDidLoad.");
    if(!self.editedNote) {
        // It seems that we're created without a note, that will mean that we're required to create a new one.
        IAMAppDelegate *appDelegate = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]);
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.managedObjectContext];
        self.editedNote = newNote;
    }
}

- (IBAction)save:(id)sender
{
    DLog(@"This is IAMNoteWindowController's save.");
    // save (if useful) and pop back
    if([self.editedNote.title isEqualToString:@""] || [[self.editedNote.attributedText string] isEqualToString:@""]) {
        DLog(@"Save refused because no text ('%@') or no title ('%@')", self.editedNote.title, [self.editedNote.attributedText string]);
        return;
    }
    self.editedNote.text = self.editedNote.attributedText.string;
    NSError *error;
    if(![((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).managedObjectContext save:&error])
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    // If called via action
    if(sender)
        [self.window performClose:sender];
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
