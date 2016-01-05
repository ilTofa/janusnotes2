//
//  IAMBooksWindowController.h
//  Janus Notes 2
//
//  Created by Giacomo Tufano on 28/11/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Cocoa/Cocoa.h>

@interface IAMBooksWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property (assign) IBOutlet NSArrayController *arrayController;
@property (weak) NSManagedObjectContext *managedObjectContext;

- (IBAction)deleteBookAction:(id)sender;
- (IBAction)addBookAction:(id)sender;

@end
