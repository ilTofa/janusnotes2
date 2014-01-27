//
//  IAMPrefsWindowController.h
// Turms
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMPrefsWindowController : NSWindowController

@property NSFont *currentFont;
@property (weak) IBOutlet NSTextField *encryptionKeyField;

- (IBAction)actionChangeFont:(id)sender;
- (IBAction)changeEncryptionKey:(id)sender;

@end
