//
//  IAMDataExporter.m
//  Turms
//
//  Created by Giacomo Tufano on 16/04/14.
//  Copyright (c) 2014 Giacomo Tufano. All rights reserved.
//

#import "IAMDataExporter.h"

@implementation IAMDataExporter

+(IAMDataExporter *)sharedExporter {
    static dispatch_once_t pred;
    static RPRadio *shared = nil;
    
    dispatch_once(&pred, ^{
        shared = [[RPRadio alloc] init];
    });
    return shared;
}


@end
