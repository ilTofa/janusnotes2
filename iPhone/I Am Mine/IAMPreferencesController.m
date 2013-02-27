//
//  IAMPreferencesController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPreferencesController.h"

#import "UIFont+GTFontMapper.h"

@interface IAMPreferencesController ()

@property NSInteger fontFace, fontSize;

@end

@implementation IAMPreferencesController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    self.clearsSelectionOnViewWillAppear = NO;
    
    self.versionLabel.text = [NSString stringWithFormat:@"This I Am Mine version %@ (%@)\n©2013 Giacomo Tufano - All rights reserved.", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    // Load base values
    self.fontFace = [UIFont gt_getStandardFontFaceIdFromUserDefault];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.fontFace inSection:0] animated:false scrollPosition:UITableViewScrollPositionMiddle];
    self.fontSize = [UIFont gt_getStandardFontSizeFromUserDefault];
    [self fontChanged:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Change font
    self.fontFace = indexPath.row;
    [self fontChanged:nil];
}

- (IBAction)fontChanged:(id)sender
{
    DLog(@"This is sizeChanged: called for a value of: %.0f", self.sizeStepper.value);
    self.fontSize = self.sizeStepper.value;
    self.sizeLabel.text = [NSString stringWithFormat:@"Text Size is %d", self.fontSize];
    self.sizeLabel.font = [UIFont gt_getStandardFontWithFaceID:self.fontFace andSize:self.fontSize];
}

- (IBAction)done:(id)sender
{
    [UIFont gt_setStandardFontInUserDefaultWithFaceID:self.fontFace andSize:self.fontSize];
    [self.navigationController popToRootViewControllerAnimated:YES];
}
@end
