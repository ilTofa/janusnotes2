//
//  IAMPreferencesController.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kPreferencesPopoverCanBeDismissed @"PreferencesPopoverCanBeDismissed"

@interface IAMPreferencesController : UITableViewController

@property (weak, nonatomic) IBOutlet UILabel *sizeLabel;
@property (weak, nonatomic) IBOutlet UIStepper *sizeStepper;
@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UILabel *dropboxLabel;
@property (weak, nonatomic) IBOutlet UISwitch *encryptionSwitch;
@property (weak, nonatomic) IBOutlet UILabel *encryptionLabel;
@property (weak, nonatomic) IBOutlet UISwitch *lockSwitch;

- (IBAction)sizePressed:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)encryptionAction:(id)sender;
- (IBAction)lockCodeAction:(id)sender;

@end
