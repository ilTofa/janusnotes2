//
//  IAMOpenWithWC.m
// Turms
//
//  Created by Giacomo Tufano on 10/05/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import "IAMOpenWithWC.h"

@interface IAMOpenWithWC ()

@property IBOutlet NSArrayController *arrayController;

@end

@implementation IAMOpenWithWC

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
    [self.arrayController setSelectionIndex:0];
}

- (IBAction)closeSheet:(id)sender {
    self.selectedAppId = NSNotFound;
    [[NSApplication sharedApplication] endSheet:self.window];
}

- (IBAction)selected:(id)sender {
    self.selectedAppId = self.arrayController.selectionIndex;
    [[NSApplication sharedApplication] endSheet:self.window];
}

@end
