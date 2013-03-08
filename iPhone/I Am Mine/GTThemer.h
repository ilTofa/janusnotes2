//
//  GTThemer.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 08/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GTThemer : NSObject

@property UIColor *backgroundColor, *textColor, *tintColor;
-(NSInteger)getStandardColorsID;
-(void)applyStandardColors:(NSInteger)colorMix;

+ (GTThemer *)sharedInstance;

@end
