//
//  IAMAppDelegate.h
//  Turms
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

#import "IAMTableUIWindowController.h"

@interface IAMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;

@property (strong, nonatomic) IAMTableUIWindowController *collectionController;

- (IBAction)saveAction:(id)sender;
- (IBAction)preferencesAction:(id)sender;
- (IBAction)notesWindowAction:(id)sender;
- (IBAction)newNoteAction:(id)sender;
- (IBAction)editNoteAction:(id)sender;
- (IBAction)closeNoteAction:(id)sender;
- (IBAction)deleteNoteAction:(id)sender;
- (IBAction)showInFinderAction:(id)sender;

- (IBAction)saveNoteAndContinueAction:(id)sender;
- (IBAction)saveNoteAndCloseAction:(id)sender;
- (IBAction)closeNote:(id)sender;
- (IBAction)addAttachmentToNoteAction:(id)sender;
- (IBAction)removeAttachmentFromNoteAction:(id)sender;

- (IBAction)getIOSApp:(id)sender;

@end
