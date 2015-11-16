//
//  IAMAppDelegate.m
//  Janus Notes 2
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

#include <sys/sysctl.h>
#import "IAMPrefsWindowController.h"
#import "STKeychain.h"
#import "Note.h"
#import "Attachment.h"
#import "validation.h"

@interface IAMAppDelegate () <SKPaymentTransactionObserver>

@property (strong) IAMPrefsWindowController *prefsController;

- (IBAction)showFAQs:(id)sender;
- (IBAction)showMarkdownHelp:(id)sender;
- (IBAction)sendAComment:(id)sender;

@end

@implementation IAMAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

@synthesize cryptPassword = _cryptPassword;

- (void)applicationWillFinishLaunching:(NSNotification *)notification {
    NSAppleEventManager *appleEventManager = [NSAppleEventManager sharedAppleEventManager];
    [appleEventManager setEventHandler:self andSelector:@selector(handleGetURLEvent:withReplyEvent:) forEventClass:kInternetEventClass andEventID:kAEGetURL];
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DLog(@"Starting application init");
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    if(!fontName) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Lucida Grande" forKey:@"fontName"];
        [[NSUserDefaults standardUserDefaults] setDouble:13.0 forKey:@"fontSize"];
    }
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
        [self.collectionController showWindow:self];
    }
    // Count executions
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:@"count"];
    [[NSUserDefaults standardUserDefaults] setInteger:++count forKey:@"count"];
    // Set itself as store observer
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    // Now set for the iCloud notification
    NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
    [dc addObserver:self selector:@selector(storesWillChange:) name:NSPersistentStoreCoordinatorStoresWillChangeNotification object:self.persistentStoreCoordinator];
    [dc addObserver:self selector:@selector(storesDidChange:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:self.persistentStoreCoordinator];
    [dc addObserver:self selector:@selector(storeHaveNewData:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:self.persistentStoreCoordinator];
    [self deleteCache];
    // Check first note
    [self addReadmeIfNeeded];
    // Check receipt
    [self whatever];
}

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    DLog(@"App called to open %@", filename);
    BOOL retValue = NO;
    if (filename && [filename hasSuffix:@"turmsentry"]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
            [self openFile:filename];
        });
        retValue = YES;
    }
    return retValue;
}

- (void)openFile:(NSString *)filename {
    // Decode URI from path.
    NSURL *objectURI = [[NSPersistentStoreCoordinator elementsDerivedFromExternalRecordURL:[NSURL fileURLWithPath:filename]] objectForKey:NSObjectURIKey];
    if (objectURI) {
        NSManagedObjectID *moid = [[self persistentStoreCoordinator] managedObjectIDForURIRepresentation:objectURI];
        if (moid) {
            NSManagedObject *mo = [[self managedObjectContext] objectWithID:moid];
            if(!self.collectionController) {
                ALog(@"Bad news. Init is *really* slow today, aborting open");
                return;
            }
            NSURL *uri = [[mo objectID] URIRepresentation];
            DLog(@"Send note URL to the main UI for opening: %@", uri);
            [self.collectionController openNoteAtURI:uri];
        } else {
            ALog(@"Error: no NSManagedObjectID for %@", objectURI);
        }
    } else {
        ALog(@"Error: no objectURI for %@", filename);
    }
}

- (void)handleGetURLEvent:(NSAppleEventDescriptor *)event withReplyEvent:(NSAppleEventDescriptor *)replyEvent {
    // Extract the URL from the Apple event and handle it here.
    NSURL* url = [NSURL URLWithString:[[event paramDescriptorForKeyword:keyDirectObject] stringValue]];
    NSString* receivedString = [url resourceSpecifier];
    if (receivedString) {
        DLog(@"Received: '%@'", receivedString);
        // Now get data from URL
        NSArray *components = [receivedString componentsSeparatedByString:@"?"];
        if ([components count] != 3) {
            ALog(@"Parsing go wrong: %@", components);
        } else {
            NSString *URL = [components[0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *title = [components[1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            NSString *text = [components[2] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
            DLog(@"URL: '%@'. Title: '%@'. Text: '%@'.", URL, title, text);
            if(!self.collectionController) {
                DLog(@"Bad news. Init is *really* slow today, saving automagically.");
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
                [self saveAction:self];
            } else {
                [self.collectionController addNoteFromUrlWithTitle:title andURL:URL andText:text];
            }
        }
    } else {
        ALog(@"Invalid embedded URL in: '%@'", url);
    }
}

- (BOOL)applicationShouldHandleReopen:(NSApplication *)theApplication hasVisibleWindows:(BOOL)flag {
    if (!flag) {
        DLog(@"User clicked on dock. Show main window.");
        [self.collectionController showWindow:self];
        return NO;
    }
    return YES;
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

#pragma mark - iAD

- (void)whatever {
    // An array of the product identifiers to query in the receipt
    DLog(@"starting whatever.");
    [self setSkipAds:NO];
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"In-App-Products" withExtension:@"plist"];
    NSArray *identifiers = [NSArray arrayWithContentsOfURL:url];
    // The validation code that enumerates the InApp purchases
    RV_CheckInAppPurchases(identifiers, ^(NSString *identifier, BOOL isPresent, NSDictionary *purchaseInfo) {
        DLog(@"%@ isPresent: %hhd.\n%@", identifier, isPresent, purchaseInfo);
        if (isPresent) {
            DLog(@">>> %@ x %d", identifier, [[purchaseInfo objectForKey:RV_INAPP_ATTRIBUTETYPE_QUANTITY] intValue]);
            [self setSkipAds:YES];
        } else {
            DLog(@">>> %@ missing", identifier);
        }
    });
}

- (void)setSkipAds:(BOOL)skipAds {
    [[NSUserDefaults standardUserDefaults] setBool:skipAds forKey:@"skipAds"];
}

- (BOOL)skipAds {
    return [[NSUserDefaults standardUserDefaults] boolForKey:@"skipAds"];
}

- (BOOL)isTimeToNag {
    // Get first run time.
    NSDate *firstDate = [[NSUserDefaults standardUserDefaults] objectForKey:@"firstDate"];
    if (!firstDate) {
        DLog(@"First time");
        [[NSUserDefaults standardUserDefaults] setObject:[NSDate date] forKey:@"firstDate"];
        return NO;
    }
    NSInteger count = [[NSUserDefaults standardUserDefaults] integerForKey:@"count"];
    DLog(@"Time to nag? %.0f, %ld", [firstDate timeIntervalSinceNow], (long)count);
    // Wait 7 days && 15 app executions
    if ((-[firstDate timeIntervalSinceNow] > 86400 * 7) && count > 15) {
        return YES;
    }
    return NO;
}

- (BOOL)nagUser {
    if ([[NSUserDefaults standardUserDefaults] boolForKey:@"skipAds"]) {
        DLog(@"no Ads, no nag");
        return NO;
    }
    if (![self isTimeToNag]) {
        DLog(@"Still early");
        return NO;
    }
    int nagDivisor;
    if ([NSWindow instancesRespondToSelector:@selector(addTitlebarAccessoryViewController:)]) {
        // Nag only 25%...
        nagDivisor = 4;
    } else {
        // nag 50% of the time (no visual indicator)
        nagDivisor = 2;
    }
    if (arc4random() % nagDivisor != 0) {
        return NO;
    }
    NSString *question = NSLocalizedString(@"Thank you!", @"");
    NSString *info = @"If you're happy with the app and you're using it regularly, show your appreciation by building the Full Version.\nThis will stop the app from nagging you from time to time and will give the developer reasons to continue development of the app.";
    NSString *buyButton = @"Buy Now";
    NSString *cancelButton = @"Later";
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setMessageText:question];
    [alert setInformativeText:info];
    [alert addButtonWithTitle:cancelButton];
    [alert addButtonWithTitle:buyButton];
    NSInteger answer = [alert runModal];
    DLog(@"%ld", (long)answer);
    if (answer == NSAlertSecondButtonReturn) {
        [self preferencesAction:self];
        return YES;
    }
    return NO;
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    for (SKPaymentTransaction *transaction in transactions)
    {
        switch (transaction.transactionState)
        {
            case SKPaymentTransactionStatePurchased: {
                DLog(@"SKPaymentTransactionStatePurchased");
                self.skipAds = YES;
                self.processingPurchase = NO;
                [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kSkipAdProcessingChanged object:self]];
                [queue finishTransaction:transaction];
                NSString *question = NSLocalizedString(@"Thank you!", @"");
                NSString *info = NSLocalizedString(@"Restart the app to get rid of the window tag.", @"");
                NSString *cancelButton = NSLocalizedString(@"OK", @"");
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setMessageText:question];
                [alert setInformativeText:info];
                [alert addButtonWithTitle:cancelButton];
                [alert runModal];
            }
                break;
            case SKPaymentTransactionStateFailed: {
                DLog(@"SKPaymentTransactionStateFailed: %@", transaction.error);
                NSAlert *alert = [NSAlert alertWithError:transaction.error];
                [alert runModal];
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
    DLog(@"Error restoring purchase: %@.", [error localizedDescription]);
    NSAlert *alert = [NSAlert alertWithError:error];
    [alert runModal];
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

#pragma mark - Core Data

- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"it.iltofa.Turms"];
}

// Creates if necessary and returns the managed object model for the application.
- (NSManagedObjectModel *)managedObjectModel
{
    if (_managedObjectModel) {
        return _managedObjectModel;
    }
	
    NSURL *modelURL = [[NSBundle mainBundle] URLForResource:@"IAmMine" withExtension:@"momd"];
    _managedObjectModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
    return _managedObjectModel;
}

// Returns the persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. (The directory for the store is created, if necessary.)
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator) {
        return _persistentStoreCoordinator;
    }
    
    NSManagedObjectModel *mom = [self managedObjectModel];
    if (!mom) {
        NSLog(@"%@:%@ No model to generate a store from", [self class], NSStringFromSelector(_cmd));
        return nil;
    }
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *applicationFilesDirectory = [self applicationFilesDirectory];
    NSError *error = nil;
    
    NSDictionary *properties = [applicationFilesDirectory resourceValuesForKeys:@[NSURLIsDirectoryKey] error:&error];
    
    if (!properties) {
        BOOL ok = NO;
        if ([error code] == NSFileReadNoSuchFileError) {
            ok = [fileManager createDirectoryAtPath:[applicationFilesDirectory path] withIntermediateDirectories:YES attributes:nil error:&error];
        }
        if (!ok) {
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    } else {
        if (![properties[NSURLIsDirectoryKey] boolValue]) {
            // Customize and localize this error.
            NSString *failureDescription = [NSString stringWithFormat:@"Expected a folder to store application data, found a file (%@).", [applicationFilesDirectory path]];
            
            NSMutableDictionary *dict = [NSMutableDictionary dictionary];
            [dict setValue:failureDescription forKey:NSLocalizedDescriptionKey];
            error = [NSError errorWithDomain:@"it.iltofa.Turms" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"store.sqlite"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    NSDictionary *options = @{NSPersistentStoreUbiquitousContentNameKey: @"Turms",
                              NSMigratePersistentStoresAutomaticallyOption: @YES,
                              NSInferMappingModelAutomaticallyOption: @YES};
//    if ([NSPersistentStoreCoordinator removeUbiquitousContentAndPersistentStoreAtURL:url options:options error:&error]) {
    if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:url options:options error:&error]) {
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _persistentStoreCoordinator = coordinator;
    
    return _persistentStoreCoordinator;
}

// Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.)
- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext) {
        return _managedObjectContext;
    }
    
    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (!coordinator) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        [dict setValue:@"Failed to initialize the store" forKey:NSLocalizedDescriptionKey];
        [dict setValue:@"There was an error building up the data file." forKey:NSLocalizedFailureReasonErrorKey];
        NSError *error = [NSError errorWithDomain:@"it.iltofa.turms" code:9999 userInfo:dict];
        [[NSApplication sharedApplication] presentError:error];
        return nil;
    }
    _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    
    return _managedObjectContext;
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
    //reset user interface
}

- (void)storesDidChange:(NSNotification *)n {
    DLog(@"NSPersistentStoreCoordinatorStoresDidChangeNotification: %@", n);
    [[NSNotificationCenter defaultCenter] postNotificationName:kCoreDataStoreExternallyChanged object:self.persistentStoreCoordinator userInfo:@{@"reason": NSPersistentStoreCoordinatorStoresDidChangeNotification}];
}

- (void)storeHaveNewData:(NSNotification *)n {
    DLog(@"NSPersistentStoreDidImportUbiquitousContentChangesNotification: %@", n);
    [self.managedObjectContext performBlock:^{
        [self.managedObjectContext mergeChangesFromContextDidSaveNotification:n];
        [[NSNotificationCenter defaultCenter] postNotificationName:kCoreDataStoreExternallyChanged object:self.persistentStoreCoordinator userInfo:@{@"reason": NSPersistentStoreDidImportUbiquitousContentChangesNotification}];
    }];
}

#pragma mark - Encryption password

#define DEFAULT_PASSWORD @"This password should be changed!"

- (NSString *)cryptPassword {
    if (!_cryptPassword) {
        NSError *error;
        _cryptPassword = [STKeychain getPasswordForUsername:@"crypt" andServiceName:@"it.iltofa.Turms" error:&error];
        if (!_cryptPassword) {
            _cryptPassword = DEFAULT_PASSWORD;
            if (error) {
                ALog(@"Error loading password, loading default password. Error: %@", [error description]);
                NSAlert *alert = [NSAlert alertWithError:error];
                [alert runModal];
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
        NSAlert *alert = [NSAlert alertWithError:error];
        [alert runModal];
    } else {
        _cryptPassword = [[NSString alloc] initWithString:aPassword];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
        [fetchRequest setEntity:entity];
        NSArray *fetchResults = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!fetchResults) {
            ALog(@"Error loading notes from db. Please restore from a backup. Error: %@", [error description]);
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
            return;
        }
        DLog(@"Re-encrypting %lu notes.", (unsigned long)[fetchResults count]);
        for (Note *note in fetchResults) {
            [note reencryptIfNeededFromOldCryptKey:oldPassword];
        }
        if (![self.managedObjectContext save:&error]) {
            ALog(@"Error saving notes after re-encryption. Please restore from a backup. Error: %@", [error description]);
            NSAlert *alert = [NSAlert alertWithError:error];
            [alert runModal];
        }
    }
}

#pragma mark -

// Performs the save action for the application, which is to send the save: message to the application's managed object context. Any encountered errors are presented to the user.
- (IBAction)saveAction:(id)sender
{
    NSError *error = nil;
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing before saving", [self class], NSStringFromSelector(_cmd));
    }
    
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
}

// TODO: delete two methods below

- (IBAction)preferencesAction:(id)sender {
    if(!self.prefsController) {
        self.prefsController = [[IAMPrefsWindowController alloc] initWithWindowNibName:@"IAMPrefsWindowController"];
    }
    [self.prefsController showWindow:self];
}

- (IBAction)notesWindowAction:(id)sender {
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
    }
    [self.collectionController showUIWindow:self];
}

- (IBAction)getIOSApp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id879143273"]];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
    }
    
    if ([self.collectionController countOfOpenedNotes] > 0) {
        NSString *question = NSLocalizedString(@"Do you want to save opened notes?", @"Quit with editors open");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made to opened notes since the last successful save", @"Quit with editors open question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSString *saveAllButton = NSLocalizedString(@"Save All", @"Save all button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:saveAllButton];
        [alert addButtonWithTitle:cancelButton];
        [alert addButtonWithTitle:quitButton];
        
        NSInteger answer = [alert runModal];
        
        switch (answer) {
            case NSAlertFirstButtonReturn:
                [self.collectionController saveAllOpenNotes];
                break;
            case NSAlertSecondButtonReturn:
                return NSTerminateCancel;
            default:
                break;
        }
    }
    
    if (![[self managedObjectContext] commitEditing]) {
        NSLog(@"%@:%@ unable to commit editing to terminate", [self class], NSStringFromSelector(_cmd));
        return NSTerminateCancel;
    }
    
    if (![[self managedObjectContext] hasChanges]) {
        return NSTerminateNow;
    }
    
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {

        // Customize this code block to include application-specific recovery steps.              
        BOOL result = [sender presentError:error];
        if (result) {
            return NSTerminateCancel;
        }

        NSString *question = NSLocalizedString(@"Could not save changes while quitting. Quit anyway?", @"Quit without saves error question message");
        NSString *info = NSLocalizedString(@"Quitting now will lose any changes you have made since the last successful save", @"Quit without saves error question info");
        NSString *quitButton = NSLocalizedString(@"Quit anyway", @"Quit anyway button title");
        NSString *cancelButton = NSLocalizedString(@"Cancel", @"Cancel button title");
        NSAlert *alert = [[NSAlert alloc] init];
        [alert setMessageText:question];
        [alert setInformativeText:info];
        [alert addButtonWithTitle:quitButton];
        [alert addButtonWithTitle:cancelButton];

        NSInteger answer = [alert runModal];
        
        if (answer == NSAlertAlternateReturn) {
            return NSTerminateCancel;
        }
    }
    return NSTerminateNow;
}

#pragma mark - cache management

- (void)deleteCache {
    // Async load, please (so don't use defaultManager, not thread safe)
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

#pragma mark - Help menu

- (IBAction)showFAQs:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/faq.html"]];
}

- (IBAction)showMarkdownHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet"]];
}

- (NSString *)getModel {
    NSString *model;
    size_t length = 0;
    sysctlbyname("hw.model", NULL, &length, NULL, 0);
    if (length) {
        char *m = malloc(length * sizeof(char));
        sysctlbyname("hw.model", m, &length, NULL, 0);
        model = [NSString stringWithUTF8String:m];
        free(m);
    } else {
        model = @"Unknown";
    }
    return model;
}

- (IBAction)rateTheApp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"macappstore://userpub.itunes.apple.com/WebObjects/MZUserPublishing.woa/wa/addUserReview?id=879393686&type=Purple+Software"]];
}

- (IBAction)sendFeedback:(id)sender {
    NSString *subject = [NSString stringWithFormat:@"Feedback on Janus Notes 2 version %@ (%@) on a %@/%@", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"], [self getModel], [[NSProcessInfo processInfo] operatingSystemVersionString]];
    NSString *urlString = [[NSString stringWithFormat:@"mailto:gt+janus2support@iltofa.com?subject=%@", subject] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

- (IBAction)sendAComment:(id)sender {
    NSString *subject = [NSString stringWithFormat:@"Comment on Janus Notes 2 version %@ (%@) on a %@/%@", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"], [self getModel], [[NSProcessInfo processInfo] operatingSystemVersionString]];
    NSString *urlString = [[NSString stringWithFormat:@"mailto:gt+janus2support@iltofa.com?subject=%@", subject] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}

@end
