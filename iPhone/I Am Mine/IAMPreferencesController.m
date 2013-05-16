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
#import "IAMDataSyncController.h"
#import "MBProgressHUD.h"

typedef enum {
    syncManagement = 0,
    fontSelector,
    sizeSelector,
    colorSelector
} sectionIdentifiers;

@interface IAMPreferencesController ()

@property NSInteger fontFace, fontSize, colorSet;

@property MBProgressHUD *hud;

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
    self.encryptionSwitch.on = [[IAMDataSyncController sharedInstance] notesAreEncrypted];
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
        self.encryptionSwitch.enabled = NO;
        self.encryptionLabel.text = @"";
    }
    else {
        self.dropboxLinked = YES;
        self.dropboxLabel.text = NSLocalizedString(@"Stop Notes Sync with Dropbox", nil);
        self.encryptionSwitch.enabled = YES;
        if(self.encryptionSwitch.isOn) {
            self.encryptionLabel.text = NSLocalizedString(@"Change Encryption Password", nil);
        } else {
            self.encryptionLabel.text = @"";
        }
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
        // Dropbox link
        if(indexPath.row == 0) {
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
        // Change password (only if already encrypted)
        if(indexPath.row == 2) {
            if ([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
                [self changePassword];
            }
        }
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

- (void)pleaseNotNow {
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil)
                                                        message:NSLocalizedString(@"Please wait for the dropbox sync to finish before starting re-encrytion", nil)
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
    [alertView show];
    self.encryptionSwitch.on = [[IAMDataSyncController sharedInstance] notesAreEncrypted];
}

- (void)changePassword {
    if ([[DBFilesystem sharedFilesystem] status]) {
        [self pleaseNotNow];
        return;
    }
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Set Crypt Password", nil)
                                                        message:NSLocalizedString(@"This password will crypt and decrypt your notes.\nPlease choose a strong password and note it somewhere. Your notes will *not* be readable anymore without the password! Don't lose or forget it!", nil)
                                                       delegate:self
                                              cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                              otherButtonTitles:NSLocalizedString(@"OK. Crypt!", nil), nil];
    alertView.alertViewStyle = UIAlertViewStylePlainTextInput;
    if ([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
        [alertView textFieldAtIndex:0].text = [[IAMDataSyncController sharedInstance] cryptPassword];
    }
    [alertView show];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex{
    NSLog(@"Button %d clicked, text is: \'%@\'", buttonIndex, [alertView textFieldAtIndex:0].text);
    if(buttonIndex == 1 && ![[alertView textFieldAtIndex:0].text isEqualToString:@""]) {
        self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.hud.labelText = NSLocalizedString(@"Encrypting Notes", nil);
        if([[IAMDataSyncController sharedInstance] notesAreEncrypted]) {
            DLog(@"Notes are already encrypted. Re-Crypt with new password: %@", [alertView textFieldAtIndex:0].text);
            self.hud.detailsLabelText = NSLocalizedString(@"Please wait while we crypt the notes...", nil);
            [[IAMDataSyncController sharedInstance] cryptNotesWithPassword:[alertView textFieldAtIndex:0].text andCompletionBlock:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(self.hud) {
                        [self.hud hide:YES];
                        self.hud = nil;
                    }
                });
            }];
        } else {
            DLog(@"Crypt now the notes with key: \'%@\'", [alertView textFieldAtIndex:0].text);
            self.hud.detailsLabelText = NSLocalizedString(@"Please wait while we re-encrypt the notes...", nil);
            [[IAMDataSyncController sharedInstance] cryptNotesWithPassword:[alertView textFieldAtIndex:0].text andCompletionBlock:^{
                dispatch_async(dispatch_get_main_queue(), ^{
                    if(self.hud) {
                        [self.hud hide:YES];
                        self.hud = nil;
                    }
                });
            }];
        }
    } else {
        self.encryptionSwitch.on = [[IAMDataSyncController sharedInstance] notesAreEncrypted];
    }
}

- (IBAction)encryptionAction:(id)sender {
    if (self.encryptionSwitch.isOn) {
        [self changePassword];
    } else {
        if ([[DBFilesystem sharedFilesystem] status]) {
            [self pleaseNotNow];
            return;
        }
        DLog(@"Remove crypt now.");
        self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.hud.labelText = NSLocalizedString(@"Decrypting Notes", nil);
        self.hud.detailsLabelText = NSLocalizedString(@"Please wait while we decrypt the notes...", nil);
        [[IAMDataSyncController sharedInstance] decryptNotesWithCompletionBlock:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                if(self.hud) {
                    [self.hud hide:YES];
                    self.hud = nil;
                }
            });
        }];
    }
}

@end
