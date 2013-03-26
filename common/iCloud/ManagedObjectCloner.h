//
//  ManagedObjectCloner.h
//  Janus
//
//  Created by Giacomo Tufano on 26/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface ManagedObjectCloner : NSObject

+(NSManagedObject *)clone:(NSManagedObject *)source inContext:(NSManagedObjectContext *)context;

@end
