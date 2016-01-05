//
//  PublishedOn.h
// Janus Notes 2
//
//  Created by Giacomo Tufano on 28/11/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Note, Site;

@interface PublishedOn : NSManagedObject

@property (nonatomic, retain) NSDate * publishDate;
@property (nonatomic, retain) NSString * publishedText;
@property (nonatomic, retain) NSString * url;
@property (nonatomic, retain) Note *note;
@property (nonatomic, retain) Site *site;

@end
