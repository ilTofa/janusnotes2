//
//  IAMAppDelegate.h
//  Janus
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

#import "CoreDataController.h"

@interface IAMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;

// CoreData helper
@property (nonatomic, strong, readonly) CoreDataController *coreDataController;

- (IBAction)saveAction:(id)sender;
- (IBAction)preferencesAction:(id)sender;
- (IBAction)notesWindowAction:(id)sender;
- (IBAction)newNoteAction:(id)sender;
- (IBAction)editNoteAction:(id)sender;
- (IBAction)closeNoteAction:(id)sender;
- (IBAction)deleteNoteAction:(id)sender;
- (IBAction)refreshNotesAction:(id)sender;

@end
