//
//  IAMCryptPasswordWC.m
//  Janus
//
//  Created by Giacomo Tufano on 15/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMCryptPasswordWC.h"

@interface IAMCryptPasswordWC ()

- (IBAction)cancelAction:(id)sender;
- (IBAction)cryptAction:(id)sender;

@end

@implementation IAMCryptPasswordWC

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

- (IBAction)cancelAction:(id)sender {
    self.validPassword = nil;
    [[NSApplication sharedApplication] endSheet:self.window];
}

- (IBAction)cryptAction:(id)sender {
    if (!self.validPassword || [self.validPassword isEqualToString:@""]) {
        return;
    }
    if(!self.passwordToBeCheckedAgaintFilesystem) {
        [[NSApplication sharedApplication] endSheet:self.window];
    }
}

@end
