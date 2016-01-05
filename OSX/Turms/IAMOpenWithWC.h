//
//  IAMOpenWithWC.h
// Turms
//
//  Created by Giacomo Tufano on 10/05/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Cocoa/Cocoa.h>

@interface IAMOpenWithWC : NSWindowController

@property IBOutlet NSArray *appArray;
@property NSInteger selectedAppId;

- (IBAction)closeSheet:(id)sender;
- (IBAction)selected:(id)sender;

@end
