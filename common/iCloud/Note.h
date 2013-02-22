//
//  Note.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Note : NSManagedObject

@property (nonatomic, retain) NSDate * created;
@property (nonatomic, retain) NSData * image;
@property (nonatomic, retain) NSString * link;
@property (nonatomic, retain) NSDate * modified;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSData * thumbnail;
@property (nonatomic, retain) NSString * uuid;

@end
