//
//  GTTransientMessage.h
//
//  Created by Giacomo Tufano on 24/08/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <Foundation/Foundation.h>

@interface GTTransientMessage : NSObject

+ (void)showWithTitle:(NSString *)title andSubTitle:(NSString *)subTitle forSeconds:(double)secondsDelay;

@end
