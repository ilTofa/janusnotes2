//
//  IAMAppDelegate.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

@interface IAMAppDelegate()
// Colors for the app
@property NSInteger colorMix;

@end

@implementation IAMAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{

    // Core Location init: get number of times user denied location use in app lifetime...
	self.nLocationUseDenies = [[NSUserDefaults standardUserDefaults] integerForKey:@"userDeny"];
	self.isLocationDenied = NO;
    self.locationString = NSLocalizedString(@"Location unknown", @"");
    // Init core data (and iCloud)
    _coreDataController = [[CoreDataController alloc] init];
    // [_coreDataController nukeAndPave];
    [_coreDataController loadPersistentStores];
    return YES;
}
							
- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

#pragma mark - colors

-(NSInteger)getStandardColorsID
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"standardColors"];
}

-(void)applyStandardColors:(NSInteger)colorMix
{
    [[NSUserDefaults standardUserDefaults] setInteger:colorMix forKey:@"standardColors"];
    // Get colors
    switch (colorMix) {
        case 0:
            self.textColor = [UIColor blackColor];
            self.backgroundColor = [UIColor colorWithWhite:0.950 alpha:1.000];
            self.tintColor = [UIColor colorWithWhite:0.667 alpha:1.000];
            break;
        case 1:
            self.textColor = [UIColor whiteColor];
            self.backgroundColor = [UIColor blackColor];
            self.tintColor = [UIColor blackColor];
        case 2:
            self.textColor = [UIColor blackColor];
            self.backgroundColor = [UIColor whiteColor];
            self.tintColor = [UIColor colorWithWhite:0.667 alpha:1.000];
        case 3:
            self.textColor = [UIColor colorWithRed:0.216 green:0.212 blue:0.192 alpha:1.000];
            self.backgroundColor = [UIColor colorWithRed:1.000 green:0.988 blue:0.922 alpha:1.000];
            self.tintColor = [UIColor colorWithRed:1.000 green:0.988 blue:0.922 alpha:1.000];
        default:
            break;
    }
}

#pragma mark - CLLocationManagerDelegate and its delegate

- (void)startLocation
{
    // if no location services, give up
    if(![CLLocationManager locationServicesEnabled])
        return;
	// If user already denied once this session, bail out
	if(self.isLocationDenied)
		return;
	// if user denied thrice, bail out...
	if(self.nLocationUseDenies >= 3)
		return;
    // Create the location manager (if needed)
    if(self.locationManager == nil)
    {
        self.locationManager = [[CLLocationManager alloc] init];
        self.locationManager.delegate = self;
        self.locationManager.desiredAccuracy = kCLLocationAccuracyKilometer;
    }
    
    // Set a movement threshold for new events
    self.locationManager.distanceFilter = 500;
    
    [self.locationManager startUpdatingLocation];
}

// Delegate method from the CLLocationManagerDelegate protocol.
- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
		   fromLocation:(CLLocation *)oldLocation
{
    // Got a location, good.
    DLog(@"Got a location, good. lat %+.4f, lon %+.4f \u00B1%.0fm\n", newLocation.coordinate.latitude, newLocation.coordinate.longitude, newLocation.horizontalAccuracy);
    self.locationString = [NSString stringWithFormat:@"lat %+.4f, lon %+.4f \u00B1%.0fm\n", newLocation.coordinate.latitude, newLocation.coordinate.longitude, newLocation.horizontalAccuracy];
    // Notify the world that we have found ourselves
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kGotLocation object:self]];
    // Now look for reverse geolocation
    CLGeocoder *theNewReverseGeocoder = [[CLGeocoder alloc] init];
    [theNewReverseGeocoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        if(placemarks != nil)
        {
            CLPlacemark * placemark = [placemarks objectAtIndex:0];
            self.locationString = [NSString stringWithFormat:@"%@, %@, %@", placemark.locality, placemark.administrativeArea, placemark.country];
            // Notify the world that we have found ourselves
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kGotLocation object:self]];
        }
        else
        {
            NSLog(@"Reverse geolocation failed with error: '%@'", [error localizedDescription]);
        }
    }];
    // If it's a relatively recent event and accuracy is satisfactory, turn off updates to save power (only if we're using standard location)
    NSDate* eventDate = newLocation.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (abs(howRecent) < 5.0 && newLocation.horizontalAccuracy < 501)
    {
        DLog(@"It's a relatively recent event and accuracy is satisfactory, turning off GPS");
        [manager stopUpdatingLocation];
        manager = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"Location Manager error: %@", [error localizedDescription]);
	// if the user don't want to give us the rights, give up.
	if(error.code == kCLErrorDenied)
	{
		[manager stopUpdatingLocation];
		// mark that user already denied us for this session
		self.isLocationDenied = YES;
		// add one to Get how many times user refused and save to default
		self.nLocationUseDenies = self.nLocationUseDenies + 1;
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		[defaults setInteger:self.nLocationUseDenies forKey:@"userDeny"];
	}
}

@end
