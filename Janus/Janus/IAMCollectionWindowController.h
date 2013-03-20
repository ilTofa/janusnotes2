//
//  IAMCollectionWindowController.h
//  Janus
//
//  Created by Giacomo Tufano on 20/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMCollectionWindowController : NSWindowController

@property (weak, atomic) IBOutlet NSManagedObjectContext *sharedManagedObjectContext;
@property (strong) IBOutlet NSArrayController *arrayController;

@end
