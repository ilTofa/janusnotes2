//
//  Note.h
//  Turms
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Attachment, Books, PublishedOn, Tags;

@interface Note : NSManagedObject

@property (nonatomic, retain) NSDate * creationDate;
@property (nonatomic, retain) NSDate * primitiveCreationDate;
@property (nonatomic, retain) NSString * creationIdentifier;
@property (nonatomic, retain) NSString *primitiveCreationIdentifier;
@property (nonatomic, retain) NSString * sectionIdentifier;
@property (nonatomic, retain) NSString *primitiveSectionIdentifier;
@property (nonatomic, retain) NSString * text;
@property (nonatomic, retain) NSString * primitiveText;
@property (nonatomic, retain) NSData * encryptedText;
@property (nonatomic, retain) NSDate * timeStamp;
@property (nonatomic, retain) NSDate *primitiveTimeStamp;
@property (nonatomic, retain) NSString * title;
@property (nonatomic, retain) NSString * uuid;
@property (nonatomic, retain) NSSet *attachment;
@property (nonatomic, retain) Books *book;
@property (nonatomic, retain) NSSet *publishedOn;
@property (nonatomic, retain) NSSet *tags;
@end

@interface Note (CoreDataGeneratedAccessors)

- (void)addAttachmentObject:(Attachment *)value;
- (void)removeAttachmentObject:(Attachment *)value;
- (void)addAttachment:(NSSet *)values;
- (void)removeAttachment:(NSSet *)values;

- (void)addPublishedOnObject:(PublishedOn *)value;
- (void)removePublishedOnObject:(PublishedOn *)value;
- (void)addPublishedOn:(NSSet *)values;
- (void)removePublishedOn:(NSSet *)values;

- (void)addTagsObject:(Tags *)value;
- (void)removeTagsObject:(Tags *)value;
- (void)addTags:(NSSet *)values;
- (void)removeTags:(NSSet *)values;

@end
