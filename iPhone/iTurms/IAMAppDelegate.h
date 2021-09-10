//
//  IAMAppDelegate.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <CoreData/CoreData.h>

#define kGotLocation @"gotLocation"
#define kCoreDataStoreExternallyChanged @"kCoreDataStoreExternallyChanged"
#define kViewControllerShouldShowPINRequest @"kViewControllerShouldShowPINRequest"


@interface IAMAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;

// helpers for corelocation.
@property (nonatomic, assign) BOOL isLocationDenied;
@property (nonatomic, assign) NSInteger nLocationUseDenies;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic) NSString *locationString;

@property (copy, nonatomic) NSString *cryptPassword;

// CoreData helper
@property (readonly, strong, nonatomic) NSManagedObjectContext *managedObjectContext;
@property (readonly, strong, nonatomic) NSManagedObjectModel *managedObjectModel;
@property (readonly, strong, nonatomic) NSPersistentStoreCoordinator *persistentStoreCoordinator;
- (NSURL *)applicationDocumentsDirectory;
- (void)saveContext;

// Error helper
- (void)presentError:(NSString *)errorMessage;

// PIN support
@property BOOL pinRequestNeeded;
- (void)getPinOnWindow:(UIViewController *)parentViewController;
@property (weak) UIViewController *currentController;

@end
