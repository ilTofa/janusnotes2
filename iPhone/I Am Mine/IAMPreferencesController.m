//
//  IAMPreferencesController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPreferencesController.h"

#import "GTThemer.h"
#import <Dropbox/Dropbox.h>

typedef enum {
    syncManagement = 0,
    fontSelector,
    sizeSelector,
    colorSelector
} sectionIdentifiers;

@interface IAMPreferencesController ()

@property NSInteger fontFace, fontSize, colorSet;

@property BOOL dropboxLinked;

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
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.colorSet inSection:3] animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    self.fontFace = [[GTThemer sharedInstance] getStandardFontFaceID];
    [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.fontFace inSection:1] animated:false scrollPosition:UITableViewScrollPositionTop];
    [self sizePressed:nil];
    [self.tableView setContentOffset:CGPointZero animated:YES];
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    // Mark selected color...
    UITableViewCell * tableCell = [self.tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:self.colorSet inSection:3]];
    tableCell.accessoryType = UITableViewCellAccessoryCheckmark;
    [self updateDropboxUI];
}

-(void)updateDropboxUI {
    // Check Dropbox linking
    DBAccount *dropboxAccount = [[DBAccountManager sharedManager] linkedAccount];
    if(!dropboxAccount) {
        self.dropboxLinked = NO;
        self.dropboxLabel.text = NSLocalizedString(@"Syncronize Notes with Dropbox", nil);
    }
    else {
        self.dropboxLinked = YES;
        self.dropboxLabel.text = NSLocalizedString(@"Stop Notes Sync with Dropbox", nil);
    }    
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
    // Dropbox
    if(indexPath.section == syncManagement) {
        if(self.dropboxLinked) {
            DLog(@"Logout from dropbox");
            [[[DBAccountManager sharedManager] linkedAccount] unlink];
        } else {
            DLog(@"Login into dropbox");
            [[DBAccountManager sharedManager] linkFromController:self];
            // Wait a while for app syncing.
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0 * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
                [self updateDropboxUI];
            });
        }
        [self updateDropboxUI];
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    // Change font
    if(indexPath.section == fontSelector) {
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:self.fontFace inSection:fontSelector];
        DLog(@"Changing font from %d to %d.", self.fontFace, indexPath.row);
        [tableView deselectRowAtIndexPath:oldIndexPath animated:YES];
        self.fontFace = indexPath.row;
    }
    // Change colors
    if(indexPath.section == colorSelector) {
        NSInteger oldColorsSet = [[GTThemer sharedInstance] getStandardColorsID];
        DLog(@"Changing colors set from %d to %d.", oldColorsSet, indexPath.row);
        UITableViewCell * tableCell = [self.tableView cellForRowAtIndexPath:indexPath];
        tableCell.accessoryType = UITableViewCellAccessoryCheckmark;
        NSIndexPath *oldIndexPath = [NSIndexPath indexPathForRow:oldColorsSet inSection:colorSelector];
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
    if(indexPath.section == fontSelector && indexPath.row == self.fontFace)
        return nil;
    if(indexPath.section == colorSelector && indexPath.row == self.colorSet)
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
