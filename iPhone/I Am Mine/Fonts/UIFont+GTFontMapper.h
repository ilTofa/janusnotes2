//
//  UIFont+GTFontMapper.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface UIFont (GTFontMapper)

+(UIFont *)gt_getStandardFontFromUserDefault;
+(NSInteger)gt_getStandardFontSizeFromUserDefault;
+(NSInteger)gt_getStandardFontFaceIdFromUserDefault;
+(UIFont *)gt_getStandardFontWithFaceID:(NSInteger)fontFace andSize:(NSInteger)fontSize;
+(void)gt_setStandardFontInUserDefaultWithFaceID:(NSInteger)fontFace andSize:(NSInteger)fontSize;

@end
