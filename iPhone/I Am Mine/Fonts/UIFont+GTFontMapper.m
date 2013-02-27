//
//  UIFont+GTFontMapper.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "UIFont+GTFontMapper.h"

@implementation UIFont (GTFontMapper)

+(NSInteger)gt_getStandardFontFaceIdFromUserDefault
{
    int fontFace = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontFace"];
    return fontFace;
}

+(NSInteger)gt_getStandardFontSizeFromUserDefault
{
    int fontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if(fontSize == 0)
        fontSize = 14;
    return fontSize;
}

+(UIFont *)gt_getStandardFontFromUserDefault
{
    NSString *fontName;
    switch ([UIFont gt_getStandardFontFaceIdFromUserDefault]) {
        case 0:
            fontName = @"Cochin";
            break;
        case 1:
            fontName = @"Georgia";
            break;
        case 2:
            fontName = @"Helvetica";
            break;
        case 3:
            fontName = @"Marker Felt";
            break;
        default:
            fontName = @"Cochin";
            break;
    }
    return [UIFont fontWithName:fontName size:[UIFont gt_getStandardFontSizeFromUserDefault]];
}

+(UIFont *)gt_getStandardFontWithFaceID:(NSInteger)fontFace andSize:(NSInteger)fontSize
{
    NSString *fontName;
    switch (fontFace) {
        case 0:
            fontName = @"Cochin";
            break;
        case 1:
            fontName = @"Georgia";
            break;
        case 2:
            fontName = @"Helvetica";
            break;
        case 3:
            fontName = @"Marker Felt";
            break;
        default:
            fontName = @"Cochin";
            break;
    }
    return [UIFont fontWithName:fontName size:fontSize];
    
}

+(void)gt_setStandardFontInUserDefaultWithFaceID:(NSInteger)fontFace andSize:(NSInteger)fontSize
{
    [[NSUserDefaults standardUserDefaults] setInteger:fontFace forKey:@"fontFace"];
    [[NSUserDefaults standardUserDefaults] setInteger:fontSize forKey:@"fontSize"];
}

@end
