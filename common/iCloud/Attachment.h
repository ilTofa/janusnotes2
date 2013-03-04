//
//  Attachment.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 04/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Note;

@interface Attachment : NSManagedObject

@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSData * data;
@property (nonatomic, retain) NSDate * creationDate;
@property (nonatomic, retain) Note *note;

@end
