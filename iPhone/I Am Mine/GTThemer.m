//
//  GTThemer.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 08/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "GTThemer.h"

@interface GTThemer()

// Values Arrays
@property NSArray *colorsConfigs;
@property NSArray *fontsConfigs;

// Saved Values
@property NSString *defaultFontFace;
@property NSInteger defaultFontSize;
@property NSDictionary *defaultColors;

@end

@implementation GTThemer

+ (GTThemer *)sharedInstance
{
    static GTThemer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GTThemer alloc] init];
        sharedInstance.colorsConfigs = @[
                                         @{
                                             @"textColor" : [UIColor whiteColor],
                                             @"backgroundColor" : [UIColor blackColor],
                                             @"tintColor" : [UIColor blackColor]},
                                         @{
                                             @"textColor" : [UIColor blackColor],
                                             @"backgroundColor" : [UIColor whiteColor],
                                             @"tintColor" : [UIColor colorWithWhite:0.667 alpha:1.000]},
                                         @{
                                             @"textColor" : [UIColor colorWithRed:0.216 green:0.212 blue:0.192 alpha:1.000],
                                             @"backgroundColor" : [UIColor colorWithRed:1.000 green:0.988 blue:0.922 alpha:1.000],
                                             @"tintColor" : [UIColor colorWithRed:0.502 green:0.251 blue:0.000 alpha:1.000]},
                                         @{
                                             @"textColor" : [UIColor blackColor],
                                             @"backgroundColor" : [UIColor colorWithWhite:0.950 alpha:1.000],
                                             @"tintColor" : [UIColor colorWithWhite:0.667 alpha:1.000]},
                                         ];
        sharedInstance.fontsConfigs = @[@"Cochin", @"Georgia", @"Helvetica", @"Marker Felt"];
        [sharedInstance getDefaultValues];
    });
    return sharedInstance;
}

- (void)getDefaultValues
{
    self.defaultFontFace = self.fontsConfigs[[[NSUserDefaults standardUserDefaults] integerForKey:@"fontFace"]];
    self.defaultColors = self.colorsConfigs[[[NSUserDefaults standardUserDefaults] integerForKey:@"standardColors"]];
    self.defaultFontSize = [[NSUserDefaults standardUserDefaults] integerForKey:@"fontSize"];
    if(self.defaultFontSize == 0)
        self.defaultFontSize = 14;
}

-(NSInteger)getStandardColorsID
{
    return [[NSUserDefaults standardUserDefaults] integerForKey:@"standardColors"];
}

-(void)applyStandardColors:(NSInteger)colorMix
{
    DLog(@"Applying color set n° %d", colorMix);
    [[NSUserDefaults standardUserDefaults] setInteger:colorMix forKey:@"standardColors"];
    // Get colors
    switch (colorMix) {
        case 1:
            self.textColor = [UIColor whiteColor];
            self.backgroundColor = [UIColor blackColor];
            self.tintColor = [UIColor blackColor];
            break;
        case 2:
            self.textColor = [UIColor blackColor];
            self.backgroundColor = [UIColor whiteColor];
            self.tintColor = [UIColor colorWithWhite:0.667 alpha:1.000];
            break;
        case 3:
            self.textColor = [UIColor colorWithRed:0.216 green:0.212 blue:0.192 alpha:1.000];
            self.backgroundColor = [UIColor colorWithRed:1.000 green:0.988 blue:0.922 alpha:1.000];
            self.tintColor = [UIColor colorWithRed:0.502 green:0.251 blue:0.000 alpha:1.000];
            break;
        case 0:
        default:
            self.textColor = [UIColor blackColor];
            self.backgroundColor = [UIColor colorWithWhite:0.950 alpha:1.000];
            self.tintColor = [UIColor colorWithWhite:0.667 alpha:1.000];
            break;
    }
}

@end
