//
//  Note.m
// Janus Notes 2
//
//  Created by Giacomo Tufano on 28/11/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import "Note.h"
#import "Attachment.h"
#import "Books.h"
#import "PublishedOn.h"
#import "Tags.h"

#import "IAMAppDelegate.h"
#import "RNEncryptor.h"
#import "RNDecryptor.h"

#import "markdown.h"
#import "html.h"

@implementation Note

@dynamic creationDate;
@dynamic primitiveCreationDate;
@dynamic creationIdentifier;
@dynamic primitiveCreationIdentifier;
@dynamic sectionIdentifier;
@dynamic primitiveSectionIdentifier;
@dynamic text;
@dynamic primitiveText;
@dynamic encryptedText;
@dynamic timeStamp;
@dynamic primitiveTimeStamp;
@dynamic title;
@dynamic uuid;
@dynamic attachment;
@dynamic book;
@dynamic publishedOn;
@dynamic tags;

#pragma mark - awakeFromInsert: setup initial values

- (void) awakeFromInsert
{
    [super awakeFromInsert];
    [self setText:@""];
    [self setTitle:@""];
    [self setUuid:[[NSUUID UUID] UUIDString]];
    [self setTimeStamp:[NSDate date]];
    [self setCreationDate:[NSDate date]];
    [self setAttachment:nil];
}

- (void)awakeFromFetch {
    [super awakeFromFetch];
    NSData *encryptedValue = [self encryptedText];
    if (encryptedValue != nil) {
        NSError *error;
#if TARGET_OS_IPHONE
        NSString *password = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
#else
        NSString *password = [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] cryptPassword];
#endif
        NSData *decryptedData = [RNDecryptor decryptData:encryptedValue withPassword:password error:&error];
        NSString *text;
        if (decryptedData) {
            text = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
        } else {
            text = @"Wrong encryption key. Please change it in Preferences.";
        }
        [self setPrimitiveText:text];
    }
}

#pragma mark - Transient properties

- (NSString *)text {
    [self willAccessValueForKey:@"text"];
    NSString *text = [self primitiveText];
    [self didAccessValueForKey:@"text"];
    return text;
}

- (void)setText:(NSString *)aText {
    [self willChangeValueForKey:@"text"];
    [self setPrimitiveValue:aText forKey:@"text"];
    [self didChangeValueForKey:@"text"];
    NSError *error;
#if TARGET_OS_IPHONE
    NSString *password = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
#else
    NSString *password = [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] cryptPassword];
#endif
    NSData *encryptedValue = [RNEncryptor encryptData:[aText dataUsingEncoding:NSUTF8StringEncoding] withSettings:kRNCryptorAES256Settings password:password error:&error];
    [self setValue:encryptedValue forKey:@"encryptedText"];
}

- (NSString *)sectionIdentifier
{
    // Create and cache the section identifier on demand.
    [self willAccessValueForKey:@"sectionIdentifier"];
    NSString *tmp = [self primitiveSectionIdentifier];
    [self didAccessValueForKey:@"sectionIdentifier"];
    if (!tmp) {
        // Sections are organized by month and year. Create the section identifier as a string representing the number (year * 1000) + month; this way they will be correctly ordered chronologically regardless of the actual name of the month.
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:[self timeStamp]];
        tmp = [NSString stringWithFormat:@"%d", (int)(([components year] * 1000) + [components month])];
        [self setPrimitiveSectionIdentifier:tmp];
    }
    return tmp;
}

- (NSString *)creationIdentifier
{
    // Create and cache the section identifier on demand.
    [self willAccessValueForKey:@"creationIdentifier"];
    NSString *tmp = [self primitiveCreationIdentifier];
    [self didAccessValueForKey:@"creationIdentifier"];
    if (!tmp) {
        // Sections are organized by month and year. Create the section identifier as a string representing the number (year * 1000) + month; this way they will be correctly ordered chronologically regardless of the actual name of the month.
        NSCalendar *calendar = [NSCalendar currentCalendar];
        NSDateComponents *components = [calendar components:(NSCalendarUnitYear | NSCalendarUnitMonth) fromDate:[self creationDate]];
        tmp = [NSString stringWithFormat:@"%d", (int)(([components year] * 1000) + [components month])];
        [self setPrimitiveCreationIdentifier:tmp];
    }
    return tmp;
}

#pragma mark - Time stamp setter

- (void)setTimeStamp:(NSDate *)newDate {
    // If the time stamp changes, the section identifier become invalid.
    [self willChangeValueForKey:@"timeStamp"];
    [self setPrimitiveTimeStamp:newDate];
    [self didChangeValueForKey:@"timeStamp"];
    [self setPrimitiveSectionIdentifier:nil];
}

- (void)setCreationDate:(NSDate *)newDate {
    // If the creation date changes, the creation identifier become invalid.
    [self willChangeValueForKey:@"creationDate"];
    [self setPrimitiveCreationDate:newDate];
    [self didChangeValueForKey:@"creationDate"];
    [self setPrimitiveCreationIdentifier:nil];
}

#pragma mark - Key path dependencies

+ (NSSet *)keyPathsForValuesAffectingSectionIdentifier {
    // If the value of timeStamp changes, the section identifier may change as well.
    return [NSSet setWithObject:@"timeStamp"];
}

+ (NSSet *)keyPathsForValuesAffectingCreationIdentifier {
    // If the value of creationDate changes, the creation identifier may change as well.
    return [NSSet setWithObject:@"creationDate"];
}

+ (NSSet *)keyPathsForValuesAffectingEncryptedText {
    // If the value of text changes, the encrypted text should change as well
    return [NSSet setWithObject:@"text"];
}

#pragma mark - Re-encrypt if needed

- (void)reencryptIfNeededFromOldCryptKey:(NSString *)oldCryptKey {
    // Get what we have on file
    NSData *encryptedValue = [self encryptedText];
    if (encryptedValue != nil) {
        NSError *error;
#if TARGET_OS_IPHONE
        NSString *password = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
#else
        NSString *password = [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] cryptPassword];
#endif
        NSData *decryptedData = [RNDecryptor decryptData:encryptedValue withPassword:password error:&error];
        // if decrypting with the new password is OK, then keep this else decrypt with the new key
        if (decryptedData) {
            NSString *newText = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
            if ([newText isEqualToString:self.text]) {
                DLog(@"'%@' decrypted with the new password, no need to do anything.", self.title);
            } else {
                DLog(@"'%@' decrypts with new password, but plain text is still not decoded. Decrypting.", self.title);
                [self willChangeValueForKey:@"text"];
                [self setPrimitiveValue:newText forKey:@"text"];
                [self didChangeValueForKey:@"text"];
            }
        } else {
            decryptedData = [RNDecryptor decryptData:encryptedValue withPassword:oldCryptKey error:&error];
            // if we have some valid data at this point, write them into the db (if needed) else show error
            NSString *newText = [[NSString alloc] initWithData:decryptedData encoding:NSUTF8StringEncoding];
            if (decryptedData) {
                DLog(@"'%@' decrypted with old password. Reencrypting.", self.title);
                [self setText:newText];
            } else {
                NSString *errorMessage = [NSString stringWithFormat:@"Cannot decrypt note '%@' with both old and new crypt password. It's probably better to restore from the backup.", self.title];
                ALog(@"%@", errorMessage);
#if TARGET_OS_IPHONE
                [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] presentError:errorMessage];
#else
                NSAlert *alert = [[NSAlert alloc] init];
                [alert setInformativeText:errorMessage];
                [alert setMessageText:NSLocalizedString(@"Error", @"")];
                [alert addButtonWithTitle:@"Bad."];
                [alert runModal];
#endif
            }
        }
    }
}

#pragma mark - Export

- (BOOL)exportAsTextToURL:(NSURL *)exportUrl error:(NSError **)error {
    NSError *localError;
    // Don't save attachments
    NSMutableString *mdString = [NSMutableString new];
    [mdString appendString:[NSString stringWithFormat:@"%@\n\n", self.title]];
    [mdString appendString:self.text];
    [mdString replaceOccurrencesOfString:@"$attachment$!" withString:@"" options:NSLiteralSearch range:NSMakeRange(0, [mdString length])];
    BOOL retValue = [mdString writeToURL:exportUrl atomically:NO encoding:NSUTF8StringEncoding error:&localError];
    if (!retValue) {
        *error = localError;
    }
    return retValue;
}


- (BOOL)exportAsHTMLToURL:(NSURL *)exportUrl error:(NSError **)error {
    NSURL *exportDirectory = [exportUrl URLByDeletingLastPathComponent];
    // Save attachments (if any)
    for (Attachment *attachment in self.attachment) {
        [attachment generateFileToDirectory:exportDirectory error:error];
    }
    // Load preview support files
    NSString *filePath = [[NSBundle mainBundle] pathForResource:@"MarkdownPreview" ofType:@"html"];
    NSMutableString *htmlString = [[NSString stringWithContentsOfFile:filePath encoding:NSUTF8StringEncoding error:error] mutableCopy];
    [htmlString replaceOccurrencesOfString:@"this_is_where_the_title_goes" withString:self.title options:NSLiteralSearch range:NSMakeRange(0, [htmlString length])];

    const char * prose = [self.text UTF8String];
    struct buf *ib, *ob;
    
    unsigned long length = [self.text lengthOfBytesUsingEncoding:NSUTF8StringEncoding] + 1;
    
    ib = bufnew(length);
    bufgrow(ib, length);
    memcpy(ib->data, prose, length);
    ib->size = length;
    
    ob = bufnew(64);
    
    struct sd_callbacks callbacks;
    struct html_renderopt options;
    struct sd_markdown *markdown;
    
    sdhtml_renderer(&callbacks, &options, 0);
    markdown = sd_markdown_new(0, 16, &callbacks, &options);
    
    sd_markdown_render(ob, ib->data, ib->size, markdown);
    sd_markdown_free(markdown);
    
    [htmlString replaceOccurrencesOfString:@"this_is_where_the_text_goes" withString:[NSString stringWithUTF8String:(const char *)ob->data] options:NSLiteralSearch range:NSMakeRange(0, [htmlString length])];
    [htmlString replaceOccurrencesOfString:@"$attachment$!" withString:[exportDirectory absoluteString] options:NSLiteralSearch range:NSMakeRange(0, [htmlString length])];

    BOOL retValue = [htmlString writeToURL:exportUrl atomically:NO encoding:NSUTF8StringEncoding error:error];

    bufrelease(ib);
    bufrelease(ob);
    return retValue;
}

- (BOOL)exportAsMarkdownForPelican:(NSURL *)exportDirectory error:(NSError **)error {
    NSString * const attachmentsSubfolder = @"images";
    NSError *localError;
    // Save attachments (if any)
    if (self.attachment && [self.attachment count] > 0) {
        NSURL *attachmentDirectory = [exportDirectory URLByAppendingPathComponent:attachmentsSubfolder isDirectory:YES];
        // Create directory
        if (![[NSFileManager defaultManager] createDirectoryAtURL:attachmentDirectory withIntermediateDirectories:YES attributes:nil error:&localError]) {
            ALog(@"Error creating attachment directory: %@", localError);
            *error = localError;
            return NO;
        }
        for (Attachment *attachment in self.attachment) {
            [attachment generateFileToDirectory:attachmentDirectory error:error];
        }
    }
    NSMutableString *mdString = [NSMutableString new];
    [mdString appendString:[NSString stringWithFormat:@"Title: %@\n", self.title]];
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm"];
    NSString *dateString = [dateFormatter stringFromDate:date];
    [mdString appendString:[NSString stringWithFormat:@"Date: %@\n", dateString]];
    if (self.book && ![self.book.name isEqualToString:@""]) {
        [mdString appendString:[NSString stringWithFormat:@"Category: %@\n", self.book.name]];
    }
    if (self.tags && [self.tags count] > 0) {
        [mdString appendString:@"Tags:"];
        for (Tags *tag in self.tags) {
            [mdString appendString:[NSString stringWithFormat:@" %@", tag]];
        }
        [mdString appendString:@"\n"];
    }
    NSString *slug = [self.title stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    [mdString appendString:[NSString stringWithFormat:@"Slug: %@\n", slug]];
    [mdString appendString:self.text];
    [mdString replaceOccurrencesOfString:@"$attachment$!" withString:attachmentsSubfolder options:NSLiteralSearch range:NSMakeRange(0, [mdString length])];
    NSURL *exportUrl = [exportDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.md", self.title]];
    BOOL retValue = [mdString writeToURL:exportUrl atomically:NO encoding:NSUTF8StringEncoding error:error];
    return retValue;
}

- (BOOL)exportAsMarkdownForHugo:(NSURL *)exportDirectory error:(NSError **)error {
    NSString * const attachmentsSubfolder = @"/img/";
    NSError *localError;
    // Save attachments (if any)
    if (self.attachment && [self.attachment count] > 0) {
        NSURL *attachmentDirectory = [exportDirectory URLByAppendingPathComponent:attachmentsSubfolder isDirectory:YES];
        // Create directory
        if (![[NSFileManager defaultManager] createDirectoryAtURL:attachmentDirectory withIntermediateDirectories:YES attributes:nil error:&localError]) {
            ALog(@"Error creating attachment directory: %@", localError);
            *error = localError;
            return NO;
        }
        for (Attachment *attachment in self.attachment) {
            [attachment generateFileToDirectory:attachmentDirectory error:error];
        }
    }
    NSMutableString *mdString = [NSMutableString new];
    [mdString appendString:[NSString stringWithFormat:@"---\ntitle: %@\n", self.title]];
    [mdString appendString:[NSString stringWithFormat:@"description: %@\n", self.title]];
    NSDate *date = [NSDate date];
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setLocale:[NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"]];
    [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ssZZZZZ"];
    NSString *dateString = [dateFormatter stringFromDate:date];
    [mdString appendString:[NSString stringWithFormat:@"date: %@\n", dateString]];
    if (self.book && ![self.book.name isEqualToString:@""]) {
        [mdString appendString:[NSString stringWithFormat:@"categories:\n - %@\n", self.book.name]];
    }
    [mdString appendString:@"tags: ["];
    if (self.tags && [self.tags count] > 0) {
        for (Tags *tag in self.tags) {
            [mdString appendString:[NSString stringWithFormat:@" \"%@\",", tag]];
        }
    }
    [mdString appendString:@"]\n"];
    NSString *slug = [self.title stringByReplacingOccurrencesOfString:@" " withString:@"-"];
    [mdString appendString:[NSString stringWithFormat:@"Slug: %@\n---\n", slug]];
    [mdString appendString:self.text];
    [mdString replaceOccurrencesOfString:@"$attachment$!" withString:attachmentsSubfolder options:NSLiteralSearch range:NSMakeRange(0, [mdString length])];
    NSURL *exportUrl = [exportDirectory URLByAppendingPathComponent:[NSString stringWithFormat:@"%@.md", self.title]];
    BOOL retValue = [mdString writeToURL:exportUrl atomically:NO encoding:NSUTF8StringEncoding error:error];
    return retValue;
}

@end
