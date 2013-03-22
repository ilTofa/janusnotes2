//
//  IAMNoteWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEditorWC.h"

#import "IAMAppDelegate.h"

@interface IAMNoteEditorWC () <NSWindowDelegate>

- (IBAction)save:(id)sender;
- (IBAction)addAttachment:(id)sender;

@end

@implementation IAMNoteEditorWC

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
    // TODO: The NSManagedObjectContext instance should change for a local (to the controller instance) one.
    self.noteEditorMOC = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).managedObjectContext;
    self.attachmentsArray = [self.editedNote.attachment allObjects];
    DLog(@"This is IAMNoteWindowController's windowDidLoad.");
    if(!self.editedNote) {
        // It seems that we're created without a note, that will mean that we're required to create a new one.
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.noteEditorMOC];
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
    self.editedNote.timeStamp = [NSDate date];
    NSError *error;
    if(![self.noteEditorMOC save:&error])
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    // If called via action
    if(sender)
        [self.window performClose:sender];
}

- (IBAction)addAttachment:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = NO;
    openPanel.canChooseFiles = YES;
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL: %@", openPanel.URL);
            CFStringRef fileExtension = (__bridge CFStringRef) [openPanel.URL pathExtension];
            CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, fileExtension, NULL);
            DLog(@"FileUTI is: %@", fileUTI);
            if (UTTypeConformsTo(fileUTI, kUTTypeImage)) NSLog(@"It's an image");
            else if (UTTypeConformsTo(fileUTI, kUTTypeMovie)) NSLog(@"It's a movie");
            else if (UTTypeConformsTo(fileUTI, kUTTypeText)) NSLog(@"It's text");
            else if (UTTypeConformsTo(fileUTI, kUTTypeFileURL)) NSLog(@"It's an URL");
            else NSLog(@"It's an unknown type");
            CFRelease(fileUTI);
        }
    }];
}

#pragma mark - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{
    // Rollback any unsaved change
    if([self.noteEditorMOC hasChanges])
        [self.noteEditorMOC rollback];
    // Notify delegate that we're closing ourselves
    DLog(@"Notifying delegate.");
    if(self.delegate)
        [self.delegate IAMNoteEditorWCDidCloseWindow:self];
}

@end
