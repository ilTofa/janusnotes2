//
//  Site.h
//  Turms
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Site : NSManagedObject

@property (nonatomic, retain) NSString * key;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * password;
@property (nonatomic, retain) NSString * type;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) NSString * username;
@property (nonatomic, retain) NSSet *publications;
@end

@interface Site (CoreDataGeneratedAccessors)

- (void)addPublicationsObject:(NSManagedObject *)value;
- (void)removePublicationsObject:(NSManagedObject *)value;
- (void)addPublications:(NSSet *)values;
- (void)removePublications:(NSSet *)values;

@end
