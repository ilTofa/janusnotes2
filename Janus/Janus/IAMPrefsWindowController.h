//
//  IAMPrefsWindowController.h
//  Janus
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMPrefsWindowController : NSWindowController

@property (weak) IBOutlet NSTextField *pathToLabel;
@property NSFont *currentFont;

- (IBAction)changePath:(id)sender;
- (IBAction)actionChangeFont:(id)sender;

@end
