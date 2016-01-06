//
//  IAMPrefsWindowController.h
// Turms
//
//  Created by Giacomo Tufano on 23/04/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Cocoa/Cocoa.h>

@interface IAMPrefsWindowController : NSWindowController

@property NSFont *currentFont;
@property (weak) IBOutlet NSTextField *encryptionKeyField;

- (IBAction)actionChangeFont:(id)sender;
- (IBAction)changeEncryptionKey:(id)sender;

@end
