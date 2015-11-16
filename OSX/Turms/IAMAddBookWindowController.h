//
//  IAMAddBookWindowController.h
//  Janus Notes 2
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMAddBookWindowController : NSWindowController

@property (weak) IBOutlet NSTextField *bookNameField;

- (IBAction)OKAction:(id)sender;
- (IBAction)cancelAction:(id)sender;

@end
