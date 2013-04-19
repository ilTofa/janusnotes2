//
//  IAMFilesystemSyncController.h
//  Janus
//
//  Created by Giacomo Tufano on 12/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kIAMDataSyncControllerReady @"IAMDataSyncControllerReady"
#define kIAMDataSyncControllerStopped @"IAMDataSyncControllerStopped"
#define kIAMDataSyncRefreshTerminated @"IAMDataSyncRefreshTerminated"

@interface IAMFilesystemSyncController : NSObject

@property BOOL syncControllerReady;
@property BOOL syncControllerInited;
@property (nonatomic, readonly) NSManagedObjectContext *dataSyncThreadContext;

+ (IAMFilesystemSyncController *)sharedInstance;

- (BOOL)modifySyncDirectory:(NSURL *)newSyncDirectory;
- (void)refreshContentFromRemote;
- (void)deleteNoteTextWithUUID:(NSString *)uuid afterFilenameChangeFrom:(NSString *)oldFilename;

@end
