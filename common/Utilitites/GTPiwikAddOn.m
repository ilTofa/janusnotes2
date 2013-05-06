//
//  GTPiwikAddOn.m
//  iJanus
//
//  Created by Giacomo Tufano on 06/05/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "GTPiwikAddOn.h"

#import "PiwikTracker.h"
#import "IAMAppDelegate.h"

@implementation GTPiwikAddOn

+ (void)trackEvent:(NSString *)event {
    DLog(@"Sanity check for PiwikTracker");
    DLog(@"tracker is: %@", ((IAMAppDelegate *)[UIApplication sharedApplication].delegate).tracker);
    DLog(@"Is traking: %c", ((IAMAppDelegate *)[UIApplication sharedApplication].delegate).tracker.isTracking);
    [((IAMAppDelegate *)[UIApplication sharedApplication].delegate).tracker trackPageview:event completionBlock:^(NSError *error) {
        if (error != nil) {
            ALog(@"Track event %@ failed with error message %@", event, [error description]);
        }
    }];
}

@end
