//
//  GTColorizer.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 08/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "GTColorizer.h"

@implementation GTColorizer

+ (GTColorizer *)sharedInstance
{
    static GTColorizer *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[GTColorizer alloc] init];
    });
    return sharedInstance;
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
