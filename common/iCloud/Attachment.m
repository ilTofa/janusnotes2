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

@end
