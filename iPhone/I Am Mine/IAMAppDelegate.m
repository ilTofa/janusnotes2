//
//  IAMAppDelegate.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

#import "GTThemer.h"
#import <Dropbox/Dropbox.h>
#import "IAMDataSyncController.h"
#import "iRate.h"
#import "STKeychain.h"

@interface IAMAppDelegate()

@end

@implementation IAMAppDelegate

+ (void)initialize {
    [iRate sharedInstance].daysUntilPrompt = 5;
    [iRate sharedInstance].usesUntilPrompt = 5;
    [iRate sharedInstance].appStoreID = 651150600;
    [iRate sharedInstance].appStoreGenreID = 0;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // init colorizer...
    if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
        [[GTThemer sharedInstance] saveStandardColors:[[GTThemer sharedInstance] getStandardColorsID]];
    }
    // Core Location init: get number of times user denied location use in app lifetime...
	self.nLocationUseDenies = [[NSUserDefaults standardUserDefaults] integerForKey:@"userDeny"];
	self.isLocationDenied = NO;
    self.locationString = NSLocalizedString(@"Location unknown", @"");
    // Init core data (and iCloud)
    _coreDataController = [[CoreDataController alloc] init];
    // [_coreDataController nukeAndPave];
    [_coreDataController loadPersistentStores];
    // Init datasync engine
    [IAMDataSyncController sharedInstance];
    // Purge cache directory
    [self deleteCache];
    return YES;
}

- (BOOL)application:(UIApplication *)app openURL:(NSURL *)url sourceApplication:(NSString *)source annotation:(id)annotation {
    DBAccount *account = [[DBAccountManager sharedManager] handleOpenURL:url];
    if (account) {
        DLog(@"App linked successfully!");
        return YES;
    }
    return NO;
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

- (void)applicationDidBecomeActive:(UIApplication *)application {
    NSError *error;
    NSString *pin = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error];
    if(pin) {
        DLog(@"PIN (%@) is required!", pin);
        [self getPIN];
    } else {
        DLog(@"PIN is not required");
    }
}

-(void)getPIN {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Enter Lock Code", nil)
                                                        message:NSLocalizedString(@"Enter the lock code to access the application.", nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [[alertView textFieldAtIndex:0] setKeyboardType:UIKeyboardTypeNumberPad];
    [alertView show];    
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    NSLog(@"Button %d clicked, text is: \'%@\'", buttonIndex, [alertView textFieldAtIndex:0].text);
    NSError *error;
    NSString *pin = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.janus" error:&error];
    if(!pin || ![pin isEqualToString:[alertView textFieldAtIndex:0].text]) {
        [self getPIN];
    }
}

- (void)applicationWillTerminate:(UIApplication *)application
{
}

#pragma mark iAD

- (void)setSkipAds:(BOOL)skipAds {
    [[NSUserDefaults standardUserDefaults] setBool:skipAds forKey:@"skipAds"];
}

- (BOOL)skipAds {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"skipAds"];
}

#pragma mark - cache management

-(void)deleteCache {
    // Async load, please (so don't use defaultManage, not thread safe)
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSFileManager *fileMgr = [[NSFileManager alloc] init];
        NSError *error;
        NSString *directory = [[fileMgr URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error] path];
        NSArray *fileArray = [fileMgr contentsOfDirectoryAtPath:directory error:nil];
        for (NSString *filename in fileArray)  {
            [fileMgr removeItemAtPath:[directory stringByAppendingPathComponent:filename] error:NULL];
        }
        fileMgr = nil;
    });
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
            CLPlacemark * placemark = placemarks[0];
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
