//
//  IAMAppDelegate.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

#import "CoreDataController.h"
#import "PiwikTracker.h"

#define kGotLocation @"gotLocation"

@interface IAMAppDelegate : UIResponder <UIApplicationDelegate, CLLocationManagerDelegate>

@property (strong, nonatomic) UIWindow *window;

// helpers for corelocation.
@property (nonatomic, assign) BOOL isLocationDenied;
@property (nonatomic, assign) int nLocationUseDenies;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic) NSString *locationString;

@property (nonatomic, strong) PiwikTracker *tracker;

// CoreData helper
@property (nonatomic, strong, readonly) CoreDataController *coreDataController;

@end
