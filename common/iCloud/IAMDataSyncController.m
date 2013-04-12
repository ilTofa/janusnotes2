//
//  IAMDataSyncController.m
//  iJanus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMDataSyncController.h"

#import "IAMAppDelegate.h"
#import "CoreDataController.h"

@interface IAMDataSyncController() {
    dispatch_queue_t _syncQueue;
}

@property (weak) CoreDataController *coreDataController;
@property DBFilesystem *fileSystem;

@end

@implementation IAMDataSyncController

- (id)init
{
    self = [super init];
    if (self) {
        // check if the data controller is ready
        self.coreDataController = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).coreDataController;
        NSAssert(self.coreDataController.psc, @"DataSyncController inited when CoreDataController Persistent Storage is still invalid");
        _syncQueue = dispatch_queue_create("dataSyncControllerQueue", DISPATCH_QUEUE_SERIAL);
        dispatch_sync(_syncQueue, ^{
            _dataSyncThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
            [_dataSyncThreadContext setPersistentStoreCoordinator:self.coreDataController.psc];
        });
        [self dropboxSyncInit];
    }
    return self;
}

+ (IAMDataSyncController *)sharedInstance
{
    static dispatch_once_t pred = 0;
    __strong static IAMDataSyncController *_sharedObject = nil;
    dispatch_once(&pred, ^{
        _sharedObject = [[self alloc] init];
    });
    return _sharedObject;
}

- (void)asyncSyncronize {
    DLog(@"Syncronization init");
    dispatch_async(_syncQueue, ^{
        // do the work on the private queue
    });
    DLog(@"Syncronization end");
}

- (void)mergeSyncChanges:(NSNotification *)note {
    // merge changes on the private queue and sync back
    dispatch_async(_syncQueue, ^{
        [self.dataSyncThreadContext mergeChangesFromContextDidSaveNotification:note];
        [self asyncSyncronize];
    });
}

#pragma mark - Dropbox init

- (void)gotNewDropboxUser:(DBAccount *)account {
    DBAccount *currentAccount = [DBAccountManager sharedManager].linkedAccount;
    if(currentAccount) {
        DBFilesystem *filesystem = [[DBFilesystem alloc] initWithAccount:currentAccount];
        [DBFilesystem setSharedFilesystem:filesystem];
        // Notify interested parties that the sync engine is ready to be used (and set the flag)
        dispatch_async(dispatch_get_main_queue(), ^{
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerReady object:self]];
            _syncControllerReady = YES;
            DLog(@"IAMDataSyncController is ready.");
        });
    } else {
        // Stop the sync engine
        dispatch_async(dispatch_get_main_queue(), ^{
            // TODO: we should probably kill the private queue and reset our moc
            [[NSNotificationCenter defaultCenter] postNotification:[NSNotification notificationWithName:kIAMDataSyncControllerStopped object:self]];
            _syncControllerReady = NO;
            DLog(@"IAMDataSyncController is stopped.");
        });
    }
}

- (void)dropboxSyncInit {
    // Init dropbox sync API
    DBAccountManager* accountMgr = [[DBAccountManager alloc] initWithAppKey:@"8mwm9fif4s1fju2" secret:@"pvafyx258qkx2fm"];
    [DBAccountManager setSharedManager:accountMgr];
    DBAccount *account = accountMgr.linkedAccount;
    [self gotNewDropboxUser:account];
    // Observe account changes and reset the shared filesystem just in case.
    [accountMgr addObserver:self block:^(DBAccount *account) {
        [self gotNewDropboxUser:account];
    }];
    // Listen to the mainThreadMOC, so to sync changes
    NSAssert(self.coreDataController.mainThreadContext, @"The Managed Object Context for CoreDataController is still invalid");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeSyncChanges:) name:NSManagedObjectContextDidSaveNotification object:self.coreDataController.mainThreadContext];
}

@end
