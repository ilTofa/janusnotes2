//
//  IAMPreferencesController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import "IAMPreferencesController.h"

#import "GTThemer.h"
#import <MessageUI/MessageUI.h>
#import <LocalAuthentication/LocalAuthentication.h>
#import "IAMAppDelegate.h"
#import "THPinViewController.h"
#import "STKeychain.h"

typedef enum {
    supportTurms = 0,
    cryptPassword,
    lockSelector,
    sortSelector,
} sectionIdentifiers;

typedef enum {
    supportHelp = 0,
    supportUnsatisfied,
    supportSatisfied,
} supportOptions;

@interface IAMPreferencesController () <MFMailComposeViewControllerDelegate, THPinViewControllerDelegate>

@property NSArray *products;
@property NSString *oldEncryptionKey;
@property BOOL deviceHaveFingerprintReader;

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
    NSError *error;
    LAContext *context = [[LAContext alloc] init];
    if ([context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:nil]) {
        self.deviceHaveFingerprintReader = YES;
    } else {
        self.deviceHaveFingerprintReader = NO;
    }
    self.versionLabel.text = [NSString stringWithFormat:@"This is Janus Notes 2 %@ (%@)\n©2013 Giacomo Tufano - Licensed with MIT License.\nIcons from icons8, licensed CC BY-ND 3.0", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    // Load base values
    self.sortSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    [self.tableView setContentOffset:CGPointZero animated:YES];
    self.cryptPasswordField.text = self.oldEncryptionKey = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
    self.lockSwitch.on = ([STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error] != nil);
    self.fingerprintSwitch.on = [[NSUserDefaults standardUserDefaults] boolForKey:@"useFingerprint"];
    if (self.deviceHaveFingerprintReader) {
        if (self.lockSwitch.on) {
            [self.fingerprintSwitch setEnabled:YES];
        } else {
            [self.fingerprintSwitch setEnabled:NO];
        }
    } else {
        [self.fingerprintSwitch setEnabled:NO];
    }
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] setCurrentController:self];
    [self.navigationController setToolbarHidden:YES animated:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidDisappear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Sorting
    if(indexPath.section == sortSelector || indexPath.section == cryptPassword) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    // Support
    if (indexPath.section == supportTurms) {
        if (indexPath.row == supportHelp) {
            DLog(@"Call help site.");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/"] options:@{} completionHandler:nil];
        } else if (indexPath.row == supportUnsatisfied) {
            DLog(@"Prepare email to support");
            [self sendCommentAction:self];
        } else if (indexPath.row == supportSatisfied) {
            DLog(@"Call iRate for rating");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=879143273&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8"] options:@{} completionHandler:nil];
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
}

#pragma mark - Comment by email

- (IBAction)sendCommentAction:(id)sender {
    MFMailComposeViewController* controller = [[MFMailComposeViewController alloc] init];
    controller.mailComposeDelegate = self;
    [controller setToRecipients:@[@"gt+iTurmsSupport@ilTofa.com"]];
    [controller setSubject:[NSString stringWithFormat:@"Feedback on Janus Notes Mobile version %@ (%@)", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]]];
    [controller setMessageBody:@"" isHTML:NO];
    if (controller)
        [self presentViewController:controller animated:YES completion:nil];
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    NSString *title;
    NSString *text;
    BOOL dismiss = NO;
    if (result == MFMailComposeResultSent) {
        title = @"Information";
        text = @"E-mail successfully sent. Thank you for the feedback!";
        dismiss = YES;
    } else if (result == MFMailComposeResultFailed) {
        title = @"Warning";
        text = @"Could not send email, please try again later.";
    } else {
        dismiss = YES;
    }
    if (text) {
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:title message:text preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) { }];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    }
    if(dismiss) {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}

#pragma mark - THPinViewControllerDelegate

// mandatory delegate methods

- (NSUInteger)pinLengthForPinViewController:(THPinViewController *)pinViewController {
    return 4;
}

- (BOOL)pinViewController:(THPinViewController *)pinViewController isPinValid:(NSString *)pin {
    DLog(@"PIN is: %@", pin);
    NSError *error;
    [STKeychain storeUsername:@"lockCode" andPassword:pin forServiceName:@"it.iltofa.turms" updateExisting:YES error:&error];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Lock Code Set", nil)
                                                                   message:[NSString stringWithFormat:NSLocalizedString(@"You just set the application lock code to %@.", @"application code locked to pin"), pin]
                                                            preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *okButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"OK", @"") style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) { }];
    [alert addAction:okButton];
    [self presentViewController:alert animated:YES completion:nil];
    if (self.deviceHaveFingerprintReader) {
        [self.fingerprintSwitch setEnabled:YES];
    }
    return YES;
}

- (BOOL)userCanRetryInPinViewController:(THPinViewController *)pinViewController{
    return YES;
}

- (void)pinViewControllerDidDismissAfterPinEntryWasCancelled:(THPinViewController *)pinViewController {
    DLog(@"Restore PIN lock status.");
    NSError *error;
    self.lockSwitch.on = ([STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error] != nil);
}

#pragma mark - Actions

- (IBAction)done:(id)sender {
    // Dismiss (or ask for dismissing)
    [self dismissViewControllerAnimated:YES completion:nil];
//    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
//        [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesPopoverCanBeDismissed object:self];
//    else
//        [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)sortSelectorAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:self.sortSelector.selectedSegmentIndex forKey:@"sortBy"];
}

- (IBAction)dateSelectorAction:(id)sender {
    [[NSUserDefaults standardUserDefaults] setInteger:self.dateSelector.selectedSegmentIndex forKey:@"dateShown"];
}

- (IBAction)cryptPasswordChangeAction:(id)sender {
    if ([self.oldEncryptionKey isEqualToString:self.cryptPasswordField.text]) {
        return;
    }
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Warning" message:NSLocalizedString(@"Are you sure you want to change the encryption key?", @"") preferredStyle:UIAlertControllerStyleAlert];
    UIAlertAction *cancelButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"Cancel", @"") style:UIAlertActionStyleCancel handler:^(UIAlertAction * action) {
        self.cryptPasswordField.text = self.oldEncryptionKey;
    }];
    UIAlertAction *changeButton = [UIAlertAction actionWithTitle:NSLocalizedString(@"Change It", @"change the encryption key") style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        DLog(@"User confirmed changing the key, now really changing it from: '%@' to '%@'", self.oldEncryptionKey, self.cryptPasswordField.text);
        [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] setCryptPassword:self.cryptPasswordField.text];
        self.oldEncryptionKey = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
        [self.cryptPasswordField resignFirstResponder];
    }];
    [alert addAction:cancelButton];
    [alert addAction:changeButton];
    [self presentViewController:alert animated:YES completion:nil];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self cryptPasswordChangeAction:self];
    return NO;
}

- (IBAction)lockCodeAction:(id)sender {
    if(self.lockSwitch.on) {
        THPinViewController *pinViewController = [[THPinViewController alloc] initWithDelegate:self];
        pinViewController.promptTitle = @"Set Pin for Janus Notes";
        pinViewController.squareButtons = YES;
        pinViewController.promptColor = [UIColor colorWithRed:1.000 green:0.671 blue:0.051 alpha:1.000];
        pinViewController.view.tintColor = [UIColor colorWithRed:1.000 green:0.671 blue:0.051 alpha:1.000];
        pinViewController.backgroundColor = [UIColor whiteColor];
        pinViewController.hideLetters = YES;
        [self presentViewController:pinViewController animated:YES completion:nil];
    } else {
        NSError *error;
        [STKeychain deleteItemForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error];
        [self.fingerprintSwitch setEnabled:NO];
    }
}

- (IBAction)fingerprintAction:(id)sender {
    if (self.fingerprintSwitch.on) {
        DLog(@"Set useFingerprint");
        [[NSUserDefaults standardUserDefaults] setBool:YES forKey:@"useFingerprint"];
    } else {
        DLog(@"Set useFingerprint to NO");
        [[NSUserDefaults standardUserDefaults] setBool:NO forKey:@"useFingerprint"];
    }
}

@end
