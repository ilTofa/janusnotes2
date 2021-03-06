//
//  IAMAppDelegate.h
//  Janus Notes 2
//
//  Created by Giacomo Tufano on 18/03/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>

#import "IAMTableUIWindowController.h"

#define kCoreDataStoreExternallyChanged @"kCoreDataStoreExternallyChanged"

#define kViewControllerShouldShowPINRequest @"kViewControllerShouldShowPINRequest"

@interface IAMAppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;

@property (strong, nonatomic) IAMTableUIWindowController *collectionController;

@property (copy, nonatomic) NSString *cryptPassword;

- (IBAction)saveAction:(id)sender;
- (IBAction)preferencesAction:(id)sender;
- (IBAction)notesWindowAction:(id)sender;

- (IBAction)getIOSApp:(id)sender;

@end
