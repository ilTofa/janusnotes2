//
//  GTTransientMessage.m
//
//  Created by Giacomo Tufano on 24/08/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import "GTTransientMessage.h"

#import "MBProgressHUD.h"

@implementation GTTransientMessage

+ (void)showWithTitle:(NSString *)title andSubTitle:(NSString *)subTitle forSeconds:(double)secondsDelay {
    UIView *topView = [[[[UIApplication sharedApplication] keyWindow] subviews] lastObject];
    if(topView) {
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:topView animated:YES];
        hud.mode = MBProgressHUDModeText;
        hud.label.text = title;
        if (subTitle) {
            hud.detailsLabel.text = subTitle;
        }
        [hud hideAnimated:YES afterDelay:secondsDelay];
    }
}

@end
