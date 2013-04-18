//
//  IAMDataSyncController.h
//  iJanus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

#import <Dropbox/Dropbox.h>

#define kIAMDataSyncControllerReady @"IAMDataSyncControllerReady"
#define kIAMDataSyncControllerStopped @"IAMDataSyncControllerStopped"
#define kIAMDataSyncRefreshTerminated @"IAMDataSyncRefreshTerminated"

@interface IAMDataSyncController : NSObject

@property BOOL syncControllerReady;
@property BOOL syncControllerInited;
@property (nonatomic, readonly) NSManagedObjectContext *dataSyncThreadContext;

+ (IAMDataSyncController *)sharedInstance;

- (void)refreshContentFromRemote;
- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename;

@end
