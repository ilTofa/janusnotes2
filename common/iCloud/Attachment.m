//
//  Attachment.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 04/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "Attachment.h"
#import "Note.h"


@implementation Attachment

@dynamic type;
@dynamic uuid;
@dynamic data;
@dynamic creationDate;
@dynamic uti;
@dynamic extension;
@dynamic filename;
@dynamic note;

#pragma mark - awakeFromInsert: setup initial values

- (void) awakeFromInsert
{
    [super awakeFromInsert];
    [self setUuid:[[NSUUID UUID] UUIDString]];
    [self setCreationDate:[NSDate date]];
}

#pragma mark - write out

- (NSURL *)generateFile {
    NSError *error;
    NSURL *cacheDirectory = [[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error];
    NSURL *cacheFile;
    if(self.filename && ![self.filename isEqualToString:@""])
        cacheFile = [cacheDirectory URLByAppendingPathComponent:self.filename];
    else
        cacheFile = [cacheDirectory URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    DLog(@"Filename will be: %@", cacheFile);
    if(![self.data writeToURL:cacheFile options:0 error:&error])
        NSLog(@"Error %@ writing attachment data to temporary file %@\nData: %@.", [error description], cacheFile, self);
    return cacheFile;
}

@end
