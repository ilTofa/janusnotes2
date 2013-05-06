//
//  GTPiwikAddOn.h
//  iJanus
//
//  Created by Giacomo Tufano on 06/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface GTPiwikAddOn : NSObject

+ (void)trackEvent:(NSString *)event;

@end
