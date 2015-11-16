//
//  IAMAppDelegate.h
//  Janus Notes 2
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreLocation/CoreLocation.h>
#import <StoreKit/StoreKit.h>

#import "IAMTableUIWindowController.h"

#define kCoreDataStoreExternallyChanged @"kCoreDataStoreExternallyChanged"

#define kSkipAdProcessingChanged @"skipAdChanged"
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

// Ads
@property (nonatomic) BOOL skipAds;
@property (atomic) BOOL processingPurchase;
- (BOOL)nagUser;

@end
