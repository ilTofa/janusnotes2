//
//  IAMAppDelegate.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <StoreKit/StoreKit.h>
#import <CoreData/CoreData.h>

#define kGotLocation @"gotLocation"
#define kSkipAdProcessingChanged @"skipAdChanged"
#define kCoreDataStoreExternallyChanged @"kCoreDataStoreExternallyChanged"
#define kViewControllerShouldShowPINRequest @"kViewControllerShouldShowPINRequest"


@interface IAMAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate, SKPaymentTransactionObserver>

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

// PIN support
@property BOOL pinRequestNeeded;
- (void)getPinOnWindow:(UIViewController *)parentViewController;

// Ads
@property (nonatomic) BOOL skipAds;
@property (atomic) BOOL processingPurchase;

@end
