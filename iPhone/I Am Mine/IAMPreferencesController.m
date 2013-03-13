//
//  IAMPreferencesController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPreferencesController.h"

#import "GTThemer.h"

@interface IAMPreferencesController ()

@property NSInteger fontFace, fontSize, colorSet;

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
    self.versionLabel.text = [NSString stringWithFormat:@"This I Am Mine version %@ (%@)\n©2013 Giacomo Tufano - All rights reserved.", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    // Load base values
    self.fontSize = [[GTThemer sharedInstance] getStandardFontSize];
    [self.sizeStepper setValue:self.fontSize];
    self.colorSet = [[GTThemer sharedInstance] getStandardColorsID];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.colorSet inSection:2] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    self.fontFace = [[GTThemer sharedInstance] getStandardFontFaceID];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.fontFace inSection:0] animated:false scrollPosition:UITableViewScrollPositionTop];
    [self sizePressed:nil];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Mark selected color...
    UITableViewCell * tableCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.colorSet inSection:2]];
    tableCell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DLog(@"This is tableView didSelectRowAtIndexPath:%@", indexPath);
    // Change font
    if(indexPath.section == 0)
    {
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:self.fontFace inSection:0];
        DLog(@"Changing font from %d to %d.", self.fontFace, indexPath.row);
        [tableView deselectRowAtIndexPath:oldIndexPath animated:YES];
        self.fontFace = indexPath.row;
    }
    // Change colors
    if(indexPath.section == 2)
    {
        NSInteger oldColorsSet = [[GTThemer sharedInstance] getStandardColorsID];
        DLog(@"Changing colors set from %d to %d.", oldColorsSet, indexPath.row);
        UITableViewCell * tableCell = [self.tableView cellForRowAtIndexPath:indexPath];
        tableCell.accessoryType = UITableViewCellAccessoryCheckmark;
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:oldColorsSet inSection:2];
        tableCell = [self.tableView cellForRowAtIndexPath:oldIndexPath];
        tableCell.accessoryType = UITableViewCellAccessoryNone;
        [tableView deselectRowAtIndexPath:oldIndexPath animated:YES];
        self.colorSet = indexPath.row;
    }
    [self sizePressed:nil];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willDeselectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DLog(@"This is tableView willDeselectRowAtIndexPath: %@", indexPath);
    // Don't deselect the selected row.
    if(indexPath.section == 0 && indexPath.row == self.fontFace)
        return nil;
    if(indexPath.section == 2 && indexPath.row == self.colorSet)
        return nil;
    return indexPath;
}

#pragma mark - Actions

-(IBAction)sizePressed:(id)sender
{
    DLog(@"This is sizePressed: called for a value of: %.0f", self.sizeStepper.value);
    self.fontSize = self.sizeStepper.value;
    self.sizeLabel.text = [NSString stringWithFormat:@"Text Size is %d", self.fontSize];
    [[GTThemer sharedInstance] applyColorsToLabel:self.sizeLabel withFontSize:self.fontSize];
    [[GTThemer sharedInstance] saveStandardColors:self.colorSet];
    
}

- (IBAction)done:(id)sender
{
    DLog(@"Saving. ColorSet n° %d, fontFace n° %d, fontSize %d", self.colorSet, self.fontFace, self.fontSize);
    [[GTThemer sharedInstance] saveStandardColors:self.colorSet];
    [[GTThemer sharedInstance] saveStandardFontsWithFaceID:self.fontFace andSize:self.fontSize];
    // Dismiss (or ask for dismissing)
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesPopoverCanBeDismissed object:self];
    else
        [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
