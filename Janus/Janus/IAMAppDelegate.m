//
//  IAMAppDelegate.m
//  Turms
//
//  Created by Giacomo Tufano on 18/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAppDelegate.h"

#include <sys/sysctl.h>
#import "IAMFilesystemSyncController.h"
#import "IAMPrefsWindowController.h"
#import "iRate.h"
#import "STKeychain.h"

@interface IAMAppDelegate ()

@property (strong) IAMPrefsWindowController *prefsController;

- (IBAction)showFAQs:(id)sender;
- (IBAction)showMarkdownHelp:(id)sender;
- (IBAction)sendAComment:(id)sender;

@end

@implementation IAMAppDelegate

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

#ifndef DEMO
//+ (void)initialize {
//    // Init iRate
//    [iRate sharedInstance].daysUntilPrompt = 5;
//    [iRate sharedInstance].usesUntilPrompt = 15;
//    [iRate sharedInstance].appStoreID = 651141191;
//    [iRate sharedInstance].appStoreGenreID = 0;
//    [iRate sharedInstance].onlyPromptIfMainWindowIsAvailable = NO;
//}
#endif

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
    DLog(@"Starting application init");
#if DEMO
    [self lifeSaver];
#else
    [self.buyFullVersionMenu setHidden:YES];
#endif
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    if(!fontName) {
        [[NSUserDefaults standardUserDefaults] setObject:@"Lucida Grande" forKey:@"fontName"];
        [[NSUserDefaults standardUserDefaults] setDouble:13.0 forKey:@"fontSize"];
    }
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
        [self.collectionController showWindow:self];
    }
    [self deleteCache];
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

- (NSURL *)applicationFilesDirectory
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *appSupportURL = [[fileManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask] lastObject];
    return [appSupportURL URLByAppendingPathComponent:@"it.iltofa.Buttami"];
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
            error = [NSError errorWithDomain:@"it.iltofa.turms" code:101 userInfo:dict];
            
            [[NSApplication sharedApplication] presentError:error];
            return nil;
        }
    }
    
    NSURL *url = [applicationFilesDirectory URLByAppendingPathComponent:@"Turms.storedata"];
    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:mom];
    if (![coordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]) {
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
    _managedObjectContext = [[NSManagedObjectContext alloc] init];
    [_managedObjectContext setPersistentStoreCoordinator:coordinator];
    
    return _managedObjectContext;
}

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

- (void)preferencesForDirectory {
    if(!self.prefsController) {
        self.prefsController = [[IAMPrefsWindowController alloc] initWithWindowNibName:@"IAMPrefsWindowController"];
    }
    // sender is nil, this is called because we need a password now...
    self.prefsController.directoryNeeded = YES;
    [self.prefsController showWindow:self];
}

- (IBAction)preferencesAction:(id)sender {
    if(!self.prefsController) {
        self.prefsController = [[IAMPrefsWindowController alloc] initWithWindowNibName:@"IAMPrefsWindowController"];
    }
    // sender is nil, this is called because we need a password now...
    if(!sender) {
        self.prefsController.aPasswordIsNeededASAP = YES;
    }
    [self.prefsController showWindow:self];
}

- (IBAction)notesWindowAction:(id)sender {
    if(!self.collectionController) {
        self.collectionController = [[IAMTableUIWindowController alloc] initWithWindowNibName:@"IAMTableUIWindowController"];
    }
    [self.collectionController showUIWindow:self];
}

- (IBAction)newNoteAction:(id)sender {
    [self.collectionController addNote:sender];
}

- (IBAction)editNoteAction:(id)sender {
    [self.collectionController editNote:sender];
}

- (IBAction)closeNoteAction:(id)sender {
    [self.collectionController.window performClose:sender];
}

- (IBAction)deleteNoteAction:(id)sender {
    [self.collectionController deleteNote:sender];
}

- (IBAction)refreshNotesAction:(id)sender {
    [self.collectionController refresh:sender];
}

- (IBAction)showInFinderAction:(id)sender {
    [self.collectionController showInFinder:sender];
}

- (IBAction)saveNoteAndContinueAction:(id)sender {
    [self.collectionController saveNoteAndContinueAction:sender];
}

- (IBAction)saveNoteAndCloseAction:(id)sender {
    [self.collectionController saveNoteAndCloseAction:sender];
}

- (IBAction)closeNote:(id)sender {
    [self.collectionController closeNote:sender];
}

- (IBAction)addAttachmentToNoteAction:(id)sender {
    [self.collectionController addAttachmentToNoteAction:sender];
}

- (IBAction)removeAttachmentFromNoteAction:(id)sender {
    [self.collectionController removeAttachmentFromNoteAction:sender];
}

- (IBAction)getIOSApp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id651150600"]];
}

- (IBAction)getFullVersion:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"macappstore://itunes.apple.com/app/id651141191?mt=12"]];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Save changes in the application's managed object context before the application terminates.
    
    if (!_managedObjectContext) {
        return NSTerminateNow;
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

#if DEMO

#pragma mark - demo management

- (void)lifeSaver {
    NSError *error;
    NSString *whatever = [STKeychain getPasswordForUsername:@"decrypt" andServiceName:@"it.iltofa.turms" error:&error];
    NSInteger uno = [whatever integerValue];
    NSInteger due = [[NSUserDefaults standardUserDefaults] integerForKey:@"time"];
    NSString *lastS = [STKeychain getPasswordForUsername:@"last" andServiceName:@"it.iltofa.turms" error:&error];
    NSDate *last1 = [NSDate dateWithTimeIntervalSinceReferenceDate:[lastS doubleValue]];
    NSDate *last2 = [NSDate dateWithTimeIntervalSinceReferenceDate:[[NSUserDefaults standardUserDefaults] doubleForKey:@"last"]];
    // Validate
    self.tampered = YES;
    if(whatever == nil && due == 0) {
        ALog(@"1");
        self.tampered = NO;
    }
    if(uno != due) {
        ALog(@"2");
        self.tampered = NO;
    }
    if(lastS == nil && due == 0) {
        ALog(@"3");
        self.tampered = NO;
    }
    if(![last1 isEqualToDate:last2]) {
        ALog(@"4");
        self.tampered = NO;
    }
    // now...
    // uno & due are the numbers of days remaining to test
    // last1 & last2 are the time of the last login.
    if(whatever == nil && due == 0) {
        // This is the first init
        _lifeline = 15;
        NSTimeInterval last = [[NSDate date] timeIntervalSinceReferenceDate];
        [STKeychain storeUsername:@"last" andPassword:[NSString stringWithFormat:@"%.0f", last] forServiceName:@"it.iltofa.turms" updateExisting:YES error:&error];
        [[NSUserDefaults standardUserDefaults] setDouble:last forKey:@"last"];
    } else {
        // Restore the other value if tampered with
        _lifeline = (uno < due) ? uno : due;
        NSDate *useThisDate = [last1 earlierDate:last2];
        NSTimeInterval timePassedFromLastStart = -[useThisDate timeIntervalSinceNow];
        if(timePassedFromLastStart > (60 * 60 * 24)) {
            // A day is passed, reduce remaining time...
            _lifeline--;
            NSTimeInterval last = [[NSDate date] timeIntervalSinceReferenceDate];
            [STKeychain storeUsername:@"last" andPassword:[NSString stringWithFormat:@"%.0f", last] forServiceName:@"it.iltofa.turms" updateExisting:YES error:&error];
            [[NSUserDefaults standardUserDefaults] setDouble:last forKey:@"last"];
        }
    }
    [STKeychain storeUsername:@"decrypt" andPassword:[NSString stringWithFormat:@"%ld", _lifeline] forServiceName:@"it.iltofa.turms" updateExisting:YES error:&error];
    [[NSUserDefaults standardUserDefaults] setInteger:_lifeline forKey:@"time"];
}

#endif

// TODO: fix url paths

- (IBAction)showFAQs:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/faq.html"]];
}

- (IBAction)showMarkdownHelp:(id)sender {
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:@"https://github.com/adam-p/markdown-here/wiki/Markdown-Cheatsheet"]];
}

- (IBAction)sendAComment:(id)sender {
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
    NSString *subject = [NSString stringWithFormat:@"Feedback on Turms OS X app version %@ (%@) on a %@/%@", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"], model, [[NSProcessInfo processInfo] operatingSystemVersionString]];
    NSString *urlString = [[NSString stringWithFormat:@"mailto:gt+turmssupport@iltofa.com?subject=%@", subject] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];;
    [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:urlString]];
}
@end
