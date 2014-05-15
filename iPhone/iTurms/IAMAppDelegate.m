//
//  IAMAppDelegate.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

#import <MobileCoreServices/MobileCoreServices.h>
#import "GTThemer.h"
#import "iRate.h"
#import "GTTransientMessage.h"
#import "Note.h"
#import "Attachment.h"
#import "IAMViewController.h"
#import "STKeychain.h"
#import "THPinViewController.h"

@interface IAMAppDelegate() <THPinViewControllerDelegate>

@property (atomic) BOOL userInitedShutdown;

@end

@implementation IAMAppDelegate

@synthesize managedObjectContext = _managedObjectContext;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;

@synthesize cryptPassword = _cryptPassword;

+ (void)initialize {
//    [iRate sharedInstance].daysUntilPrompt = 5;
//    [iRate sharedInstance].usesUntilPrompt = 5;
//    [iRate sharedInstance].appStoreID = 651150600;
//    [iRate sharedInstance].appStoreGenreID = 0;
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    // Starting, so we want PIN request (if any) later
    self.userInitedShutdown = YES;
   // Core Location init: get number of times user denied location use in app lifetime...
	self.nLocationUseDenies = [[NSUserDefaults standardUserDefaults] integerForKey:@"userDeny"];
	self.isLocationDenied = NO;
    self.locationString = NSLocalizedString(@"Location unknown", @"");
    // Set itself as store observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    // Now set for the iCloud notification
    NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
    [dc addObserver:self selector:@selector(storesWillChange:) name:NSPersistentStoreCoordinatorStoresWillChangeNotification object:self.persistentStoreCoordinator];
    [dc addObserver:self selector:@selector(storesDidChange:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:self.persistentStoreCoordinator];
    [dc addObserver:self selector:@selector(storeHaveNewData:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:self.persistentStoreCoordinator];
    // Purge cache directory
    [self deleteCache];
    // Check first note
    [self addReadmeIfNeeded];
    return YES;
}

- (void)applicationDidEnterBackground:(UIApplication *)application {
    DLog(@"Marking user inited app shutdown.");
    self.userInitedShutdown = YES;
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    DLog(@"Here we are.");
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationWillResignActive:(UIApplication *)application {
    DLog(@"Resigning active.");
}

- (void)applicationDidBecomeActive:(UIApplication *)application {
    if (!self.userInitedShutdown) {
        DLog(@"Active from external reason (no user inited), skipping PIN check");
        return;
    }
    self.userInitedShutdown = NO;
    NSError *error;
    NSString *pin = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error];
    if(pin) {
        DLog(@"PIN (%@) is required!", pin);
        self.pinRequestNeeded = YES;
        [[NSNotificationCenter defaultCenter] postNotificationName:kViewControllerShouldShowPINRequest object:self userInfo:nil];
    } else {
        DLog(@"PIN (%@) not required!", pin);
        self.pinRequestNeeded = NO;
    }
}

- (void)saveContext
{
    NSError *error = nil;
    NSManagedObjectContext *managedObjectContext = self.managedObjectContext;
    if (managedObjectContext != nil) {
        if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
            // Replace this implementation with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

#pragma mark - PIN Request

- (NSUInteger)pinLengthForPinViewController:(THPinViewController *)pinViewController {
    return 4;
}

- (BOOL)pinViewController:(THPinViewController *)pinViewController isPinValid:(NSString *)pin {
    DLog(@"PIN is: %@", pin);
    NSError *error;
    NSString *savedPIN = [STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error];
    if(!savedPIN || ![pin isEqualToString:savedPIN]) {
        return NO;
    } else {
        self.pinRequestNeeded = NO;
        return YES;
    }
}

- (BOOL)userCanRetryInPinViewController:(THPinViewController *)pinViewController{
    return YES;
}

- (BOOL)shouldPinViewControllerlDismissedAfterPinEntryWasCancelled:(THPinViewController *)pinViewController {
    return NO;
}

- (void)getPinOnWindow:(UIViewController<THPinViewControllerDelegate> *)parentViewController {
    if (!self.pinRequestNeeded) {
        DLog(@"Call was not valid.");
        return;
    }
    THPinViewController *pinViewController = [[THPinViewController alloc] initWithDelegate:self];
    pinViewController.backgroundColor = [UIColor whiteColor];
    pinViewController.promptTitle = @"Enter PIN";
    pinViewController.promptColor = [UIColor colorWithRed:0.000 green:0.455 blue:0.780 alpha:1.000];
    pinViewController.view.tintColor = [UIColor colorWithRed:0.000 green:0.455 blue:0.780 alpha:1.000];
    pinViewController.hideLetters = YES;
    [parentViewController presentViewController:pinViewController animated:YES completion:nil];
}

#pragma mark - Readme file

-(void)addReadmeIfNeeded {
    if(![[NSUserDefaults standardUserDefaults] boolForKey:@"readmeAdded"]) {
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"readmeAdded"];
        DLog(@"Adding readme note.");
        NSError *error;
        NSString *filePath = [[NSBundle mainBundle] pathForResource:@"readme" ofType:@"txt"];
        NSString *readmeText = [NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:&error];
        if (readmeText) {
            Note *readmeNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
            readmeNote.title = @"Read me!";
            readmeNote.text = readmeText;
            if(![self.managedObjectContext save:&error]) {
                ALog(@"Error saving readme note: %@,", [error description]);
            }
        } else {
            ALog(@"Error reading readme text from bundle: %@", [error description]);
        }
    }
}

#pragma mark - URL support

- (BOOL)application:(UIApplication *)application openURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication annotation:(id)annotation {
    // Extract the URL from the Apple event and handle it here.
    DLog(@"Received %@ from %@.", url, sourceApplication);
    NSString* receivedString = [url resourceSpecifier];
    if (receivedString) {
        DLog(@"Received: '%@'", receivedString);
        // Now get data from URL
        NSArray *components = [receivedString componentsSeparatedByString:@"?"];
        if ([components count] != 3) {
            ALog(@"Parsing go wrong: %@", components);
            return NO;
        } else {
            NSString *URL = [components[0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *title = [components[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *text = [components[2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            DLog(@"URL: '%@'. Title: '%@'. Text: '%@'.", URL, title, text);
            // Creating new note
            Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
            newNote.title = title;
            newNote.text = text;
            // and attachment for the URL
            Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.managedObjectContext];
            newAttachment.uti = (__bridge NSString *)(kUTTypeURL);
            newAttachment.extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(kUTTypeURL, kUTTagClassFilenameExtension);
            if(!newAttachment.extension)
                newAttachment.extension = @"url";
            newAttachment.filename = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], newAttachment.extension];
            newAttachment.type = @"Link";
            NSString *attachmentContent = [NSString stringWithFormat:@"[InternetShortcut]\nURL=%@\n", URL];
            newAttachment.data = [attachmentContent dataUsingEncoding:NSUTF8StringEncoding];
            // Now link attachment to the note
            newAttachment.note = newNote;
            [newNote addAttachmentObject:newAttachment];
            [self saveContext];
        }
    } else {
        ALog(@"Invalid embedded URL in: '%@'", url);
        return NO;
    }
    return YES;
}

#pragma mark - Core Data stack

// Returns the managed object context for the application.
// If the context doesn't already exist, it is created and bound to the persistent store coordinator for the application.
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext != nil) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    }
    return _managedObjectContext;
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created from the application's model.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel != nil) {
        return _managedObjectModel;
    }
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"IAmMine" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator != nil) {
        return _persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSURL *storeURL = [[self applicationDocumentsDirectory] URLByAppendingPathComponent:@"store.sqlite"];
    NSError *error = nil;
    _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSDictionary *options = @{NSPersistentStoreUbiquitousContainerIdentifierKey: @"6483W56522.it.iltofa.Turms",
                              NSPersistentStoreUbiquitousContentNameKey: @"Turms",
                              NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES};
//    if (![NSPersistentStoreCoordinator removeUbiquitousContentAndPersistentStoreAtURL:storeURL options:options error:&error]) {
    if (![_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error]) {
        /*
         Replace this implementation with code to handle the error appropriately.
         
         abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
         
         Typical reasons for an error here include:
         * The persistent store is not accessible;
         * The schema for the persistent store is incompatible with current managed object model.
         Check the error message to determine what the actual problem was.
         
         
         If the persistent store is not accessible, there is typically something wrong with the file path. Often, a file URL is pointing into the application's resources directory instead of a writeable directory.
         
         If you encounter schema incompatibility errors during development, you can reduce their frequency by:
         * Simply deleting the existing store:
         [[NSFileManager defaultManager] removeItemAtURL:storeURL error:nil]
         
         * Performing automatic lightweight migration by passing the following dictionary as the options parameter:
         @{NSMigratePersistentStoresAutomaticallyOption:@YES, NSInferMappingModelAutomaticallyOption:@YES}
         
         Lightweight migration will only work for a limited set of schema changes; consult "Core Data Model Versioning and Data Migration Programming Guide" for details.
         
         */
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
        abort();
    }
    return _persistentStoreCoordinator;
}

#pragma mark - Application's Documents directory

// Returns the URL to the application's Documents directory.
- (NSURL *)applicationDocumentsDirectory
{
    return [[[NSFileManager defaultManager] URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask] lastObject];
}

- (void)applicationWillTerminate:(UIApplication *)application {
    DLog(@"Here we are");
}

#pragma mark - Encryption password

#define DEFAULT_PASSWORD @"This password should be changed!"

- (NSString *)cryptPassword {
    if (!_cryptPassword) {
        NSError *error;
//        [STKeychain deleteItemForUsername:@"crypt" andServiceName:@"it.iltofa.Turms" error:&error];
        _cryptPassword = [STKeychain getPasswordForUsername:@"crypt" andServiceName:@"it.iltofa.Turms" error:&error];
        if (!_cryptPassword) {
            _cryptPassword = DEFAULT_PASSWORD;
            if (error) {
                ALog(@"Error loading password, loading default password. Error: %@", [error description]);
            }
        }
    }
    return _cryptPassword;
}

- (void)setCryptPassword:(NSString *)aPassword {
    NSError *error;
    NSString *oldPassword = _cryptPassword;
    if(![STKeychain storeUsername:@"crypt" andPassword:aPassword forServiceName:@"it.iltofa.Turms" updateExisting:YES error:&error]) {
        ALog(@"Error saving password, password not changed. Error: %@", [error description]);
    } else {
        _cryptPassword = [[NSString alloc] initWithString:aPassword];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
        [fetchRequest setEntity:entity];
        NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!fetchResults) {
            NSString *errorMessage = [NSString stringWithFormat:@"Error loading notes from db. Please restore from a backup on a Macintosh. Error: %@", [error description]];
            ALog(@"%@", errorMessage);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMessage delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
            [alert show];
            return;
        }
        DLog(@"Re-encrypting %lu notes.", (unsigned long)[fetchResults count]);
        for (Note *note in fetchResults) {
            [note reencryptIfNeededFromOldCryptKey:oldPassword];
        }
        if (![self.managedObjectContext save:&error]) {
            NSString *errorMessage = [NSString stringWithFormat:@"Error saving notes after re-encryption. Please restore from a backup on a Mac. Error: %@", [error description]];
            ALog(@"%@", errorMessage);
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:errorMessage delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
            [alert show];
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kCoreDataStoreExternallyChanged object:self.persistentStoreCoordinator userInfo:@{@"reason": NSPersistentStoreCoordinatorStoresWillChangeNotification}];
    }
}

#pragma mark - iCloud

- (void)storesWillChange:(NSNotification *)n {
    DLog(@"NSPersistentStoreCoordinatorStoresWillChangeNotification: %@", n);
    NSError *error;
    if ([self.managedObjectContext hasChanges]) {
        [self.managedObjectContext save:&error];
    }
    [self.managedObjectContext reset];
    [[NSNotificationCenter defaultCenter] postNotificationName:kCoreDataStoreExternallyChanged object:self.persistentStoreCoordinator userInfo:@{@"reason": NSPersistentStoreCoordinatorStoresWillChangeNotification}];
}

- (void)storesDidChange:(NSNotification *)n {
    DLog(@"NSPersistentStoreCoordinatorStoresDidChangeNotification: %@", n);
    [[NSNotificationCenter defaultCenter] postNotificationName:kCoreDataStoreExternallyChanged object:self.persistentStoreCoordinator userInfo:@{@"reason": NSPersistentStoreCoordinatorStoresDidChangeNotification}];
}

- (void)storeHaveNewData:(NSNotification *)n {
    DLog(@"NSPersistentStoreDidImportUbiquitousContentChangesNotification: %@", n);
    [self.managedObjectContext performBlock:^{
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:n];
    }];
}

#pragma mark iAD

- (void)setSkipAds:(BOOL)skipAds {
    [[NSUserDefaults standardUserDefaults] setBool:skipAds forKey:@"skipAds"];
}

- (BOOL)skipAds {
    return YES;// [[NSUserDefaults standardUserDefaults] boolForKey:@"skipAds"];
}

#pragma mark SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased:
                DLog(@"SKPaymentTransactionStatePurchased");
                self.skipAds = YES;
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
                [GTTransientMessage showWithTitle:@"Thank you!" andSubTitle:@"No Ad will be shown anymore." forSeconds:1.0];
                break;
            case SKPaymentTransactionStateFailed: {
                DLog(@"SKPaymentTransactionStateFailed");
                NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error purchasing: %@.", nil), [transaction.error localizedDescription]];
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase Error" message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
                [alert show];
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
            }
                break;
            case SKPaymentTransactionStateRestored:
                DLog(@"SKPaymentTransactionStateRestored");
                self.skipAds = YES;
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
            case SKPaymentTransactionStatePurchasing:
                DLog(@"SKPaymentTransactionStatePurchasing");
                self.processingPurchase = YES;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                break;
            default:
                break;
        }
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error {
    NSString *message = [NSString stringWithFormat:NSLocalizedString(@"Error restoring purchase: %@.", nil), [error localizedDescription]];
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
    [alert show];
    self.processingPurchase = NO;
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
}

- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue {
    DLog(@"Restore finished");
    self.processingPurchase = NO;
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedDownloads:(NSArray *)downloads {
    DLog(@"Called with %@", downloads);
}


#pragma mark - cache management

-(void)deleteCache {
    // Async load so don't use defaultManage, not thread safe
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

- (void)startLocation {
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
    if(self.locationManager == nil) {
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
		   fromLocation:(CLLocation *)oldLocation {
    // Got a location, good.
    DLog(@"Got a location, good. lat %+.4f, lon %+.4f \u00B1%.0fm\n", newLocation.coordinate.latitude, newLocation.coordinate.longitude, newLocation.horizontalAccuracy);
    self.locationString = [NSString stringWithFormat:@"lat %+.4f, lon %+.4f \u00B1%.0fm\n", newLocation.coordinate.latitude, newLocation.coordinate.longitude, newLocation.horizontalAccuracy];
    // Notify the world that we have found ourselves
    [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kGotLocation object:self]];
    // Now look for reverse geolocation
    CLGeocoder *theNewReverseGeocoder = [[CLGeocoder alloc] init];
    [theNewReverseGeocoder reverseGeocodeLocation:newLocation completionHandler:^(NSArray *placemarks, NSError *error) {
        if(placemarks != nil) {
            CLPlacemark * placemark = placemarks[0];
            self.locationString = [NSString stringWithFormat:@"%@, %@, %@", placemark.locality, placemark.administrativeArea, placemark.country];
            // Notify the world that we have found ourselves
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kGotLocation object:self]];
        } else {
            NSLog(@"Reverse geolocation failed with error: '%@'", [error localizedDescription]);
        }
    }];
    // If it's a relatively recent event and accuracy is satisfactory, turn off updates to save power (only if we're using standard location)
    NSDate* eventDate = newLocation.timestamp;
    NSTimeInterval howRecent = [eventDate timeIntervalSinceNow];
    if (abs(howRecent) < 5.0 && newLocation.horizontalAccuracy < 501) {
        DLog(@"It's a relatively recent event and accuracy is satisfactory, turning off GPS");
        [manager stopUpdatingLocation];
        manager = nil;
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"Location Manager error: %@", [error localizedDescription]);
	// if the user don't want to give us the rights, give up.
	if(error.code == kCLErrorDenied) {
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
