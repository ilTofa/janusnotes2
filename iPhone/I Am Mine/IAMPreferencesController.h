//
//  IAMPreferencesController.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IAMPreferencesController : UITableViewController

@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UIStepper *sizeStepper;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;

- (IBAction)sizePressed:(id)sender;
- (IBAction)done:(id)sender;
@end
