//
//  IAMPreferencesController.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kPreferencesPopoverCanBeDismissed @"PreferencesPopoverCanBeDismissed"

typedef enum {
    sortModification = 0,
    sortCreation,
    sortTitle
} SortKey;

typedef enum {
    modificationDateShown = 0,
    creationDataShown
} DateShownKey;

@interface IAMPreferencesController : UITableViewController

@property (weak, nonatomic) IBOutlet UILabel *versionLabel;
@property (weak, nonatomic) IBOutlet UISegmentedControl *sortSelector;
@property (weak, nonatomic) IBOutlet UISegmentedControl *dateSelector;
@property (weak, nonatomic) IBOutlet UILabel *productCoffeeLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *productCoffeeCell;
@property (weak, nonatomic) IBOutlet UILabel *productCoffeePriceLabel;
@property (weak, nonatomic) IBOutlet UITableViewCell *restoreCell;
@property (weak, nonatomic) IBOutlet UILabel *restoreCellLabel;
@property (weak, nonatomic) IBOutlet UITextField *cryptPasswordField;
@property (weak, nonatomic) IBOutlet UISwitch *lockSwitch;
@property (weak, nonatomic) IBOutlet UISwitch *fingerprintSwitch;

- (IBAction)done:(id)sender;
- (IBAction)sortSelectorAction:(id)sender;
- (IBAction)dateSelectorAction:(id)sender;
- (IBAction)cryptPasswordChangeAction:(id)sender;
- (IBAction)lockCodeAction:(id)sender;
- (IBAction)fingerprintAction:(id)sender;

@end
