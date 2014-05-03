//
//  IAMNoteEditTextView.m
// Turms Notes
//
//  Created by Giacomo Tufano on 23/10/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEditTextView.h"

@interface IAMNoteEditTextView ()

@property NSString *cacheDirectory;

@end

@implementation IAMNoteEditTextView

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
        NSError *error;
        _cacheDirectory = [[[NSFileManager defaultManager] URLForDirectory:NSCachesDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:&error] absoluteString];
    }
    return self;
}

-(BOOL)performDragOperation:(id<NSDraggingInfo>)sender {
    NSPasteboard *pb = [sender draggingPasteboard];
    DLog(@"Pasteboard contains: %@", [pb types]);
    // Intercept file URLS and cut the cache directory
    if ( [[pb types] containsObject:@"public.file-url"] ) {
        NSString *urlString = [pb propertyListForType:@"public.file-url"];
        NSString *fileExtension = [urlString pathExtension];
        DLog("File extension: %@", fileExtension);
        CFStringRef fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, (__bridge CFStringRef)(fileExtension), NULL);
        if ([fileExtension isEqualToString:@"url"]) {
            NSData *data = [NSData dataWithContentsOfURL:[NSURL URLWithString:urlString]];
            NSString *realURL = [NSString stringWithUTF8String:[data bytes]];
            NSRange urlRange = [realURL rangeOfString:@"URL="];
            if (urlRange.location == NSNotFound) {
                DLog(@"Directly loading the url: '%@'", realURL);
            } else {
                realURL = [realURL substringFromIndex:urlRange.location + 4];
                realURL = [realURL stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
                DLog(@"Loading the parsed url: '%@'", realURL);
            }
            urlString = [NSString stringWithFormat:@"[](%@)", realURL];
        } else if (UTTypeConformsTo(fileUTI, kUTTypeImage)) {
            DLog(@"It's an image");
            urlString = [NSString stringWithFormat:@"![](%@)", urlString];
        } else if (UTTypeConformsTo(fileUTI, kUTTypeText)) {
            DLog(@"It's text, loading the real thing (if possible and encoded UTF-8)");
            NSError *error;
            NSString *stringFromFileAtURL = [[NSString alloc] initWithContentsOfURL:[NSURL URLWithString:urlString] encoding:NSUTF8StringEncoding error:&error];
            if (!stringFromFileAtURL) {
                urlString = stringFromFileAtURL;
            } else {
                urlString = [NSString stringWithFormat:@"[](%@)", urlString];
            }
        }
        CFRelease(fileUTI);
        NSString *retVal = [urlString stringByReplacingOccurrencesOfString:self.cacheDirectory withString:@"$attachment$!"];
        [pb setString:retVal forType:NSPasteboardTypeString];
    }
    return [super performDragOperation:sender];
}

@end
