//
//  IAMNoteWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteWindowController.h"

@interface IAMNoteWindowController ()

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
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (IBAction)save:(id)sender {
}
@end
