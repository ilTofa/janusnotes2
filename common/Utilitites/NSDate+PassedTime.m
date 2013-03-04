//
//  NSDate+PassedTime.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 01/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "NSDate+PassedTime.h"

@implementation NSDate (PassedTime)

-(NSString *)gt_timePassed
{
    NSTimeInterval timeDifference = [[NSDate date] timeIntervalSinceDate:self];
    int iminutes = timeDifference / 60;
    int ihours = iminutes / 60;
    int idays = iminutes / 1440;
    iminutes = iminutes - ihours * 60;
    ihours = ihours - idays * 24;
    NSString *timePassed;
    if(idays > 1)
        timePassed = [NSString stringWithFormat:@"%dd ago", idays];
    else if(idays == 1)
        timePassed = @"yesterday";
    else if(ihours == 0 && iminutes == 0)
        timePassed = @"now";
    else if(ihours == 0)
        timePassed = [NSString stringWithFormat:@"%dm ago", iminutes];
    else
        timePassed = [NSString stringWithFormat:@"%dh %dm ago", ihours, iminutes];
    return timePassed;
}

@end
