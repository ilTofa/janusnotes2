//
//  ManagedObjectCloner.m
//  Janus
//
//  Created by Giacomo Tufano on 26/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "ManagedObjectCloner.h"

@implementation ManagedObjectCloner

+(NSManagedObject *) clone:(NSManagedObject *)source inContext:(NSManagedObjectContext *)context{
    NSString *entityName = [[source entity] name];
    //create new object in data store
    NSManagedObject *cloned = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:context];
    //loop through all attributes and assign then to the clone
    NSDictionary *attributes = [[NSEntityDescription entityForName:entityName inManagedObjectContext:context] attributesByName];
    for (NSString *attr in attributes) {
        [cloned setValue:[source valueForKey:attr] forKey:attr];
    }
    //Loop through all relationships, and clone them.
    NSDictionary *relationships = [[NSEntityDescription entityForName:entityName inManagedObjectContext:context] relationshipsByName];
    for (NSString *relName in [relationships allKeys]){
        NSRelationshipDescription *rel = [relationships objectForKey:relName];
        
        NSString *keyName = [NSString stringWithFormat:@"%@",rel];
        if ([rel isToMany]) {
            //get a set of all objects in the relationship
            NSMutableSet *sourceSet = [source mutableSetValueForKey:keyName];
            NSMutableSet *clonedSet = [cloned mutableSetValueForKey:keyName];
            NSEnumerator *e = [sourceSet objectEnumerator];
            NSManagedObject *relatedObject;
            while ( relatedObject = [e nextObject]){
                //Clone it, and add clone to set
                NSManagedObject *clonedRelatedObject = [ManagedObjectCloner clone:relatedObject inContext:context];
                [clonedSet addObject:clonedRelatedObject];
            }
        } else {
            [cloned setValue:[source valueForKey:keyName] forKey:keyName];
        }
    }
    return cloned;
}

@end
