//
//  IAMPreferencesController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 27/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPreferencesController.h"

#import "GTThemer.h"
#import <MessageUI/MessageUI.h>
#import <StoreKit/StoreKit.h>
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
    supportCoffee,
    supportRestore
} supportOptions;

@interface IAMPreferencesController () <MFMailComposeViewControllerDelegate, SKProductsRequestDelegate, THPinViewControllerDelegate>

@property NSArray *products;
@property NSString *oldEncryptionKey;

@property UIAlertView *lockCodeAlert;

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
    self.versionLabel.text = [NSString stringWithFormat:@"This is Janus Notes 2 %@ (%@)\n©2013 Giacomo Tufano - All rights reserved.\nIcons from icons8, licensed CC BY-ND 3.0", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    // Load base values
    self.sortSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    [self.tableView setContentOffset:CGPointZero animated:YES];
    self.cryptPasswordField.text = self.oldEncryptionKey = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
    NSError *error;
    self.lockSwitch.on = ([STKeychain getPasswordForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error] != nil);
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(skipAdProcessed:) name:kSkipAdProcessingChanged object:nil];
    [self updateStoreUI];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    [super viewDidDisappear:animated];
}

- (void)skipAdProcessed:(NSNotification *)aNotification {
    DLog(@"Got a notifaction for store processing");
    [self updateStoreUI];
}

- (void)disableAllStoreUIOptions {
    self.productCoffeeCell.userInteractionEnabled = self.restoreCell.userInteractionEnabled = NO;
    self.productCoffeeLabel.enabled = self.restoreCellLabel.enabled = NO;
    self.productCoffeePriceLabel.enabled = NO;
    self.productCoffeePriceLabel.text = @"-";
}

- (void)updateStoreUI {
    // Disable store while we look for the products
    [self disableAllStoreUIOptions];
    // No money? No products!
    if (![SKPaymentQueue canMakePayments]) {
        self.productCoffeePriceLabel.text = @"Payments disabled.";
        return;
    }
    // If user already paid, leave disabled
    if (((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).skipAds) {
        self.productCoffeePriceLabel.text = @"Already bought.";
        return;
    }
    // If a transaction is already in progress, leave disabled
    if (((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).processingPurchase) {
        self.productCoffeePriceLabel.text = @"Transaction still in progress.";
        return;
    }
    DLog(@"starting request for products.");
    NSURL *url = [[NSBundle mainBundle] URLForResource:@"In-App-Products" withExtension:@"plist"];
    NSArray *productIdentifiers = [NSArray arrayWithContentsOfURL:url];
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc] initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}

// SKProductsRequestDelegate protocol method
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    self.products = response.products;
    for (NSString __unused * invalidProductIdentifier in response.invalidProductIdentifiers) {
        // Handle any invalid product identifiers.
    }
    DLog(@"%@", self.products);
     // Custom method
    if ([self.products count] == 0) {
        DLog(@"Void or invalid product array, returning");
        return;
    }
    SKProduct *product = self.products[0];
    self.productCoffeeLabel.text = product.localizedTitle;
    NSNumberFormatter * numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString * formattedPrice = [numberFormatter stringFromNumber:product.price];
    self.productCoffeePriceLabel.text = formattedPrice;
    self.productCoffeeCell.userInteractionEnabled = self.productCoffeeLabel.enabled = self.productCoffeePriceLabel.enabled = YES;
    self.restoreCell.userInteractionEnabled = self.restoreCellLabel.enabled = YES;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DLog(@"request failed: %@,  %@", request, error);
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
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/"]];
        } else if (indexPath.row == supportUnsatisfied) {
            DLog(@"Prepare email to support");
            [self sendCommentAction:self];
        } else if (indexPath.row == supportSatisfied) {
            DLog(@"Call iRate for rating");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://itunes.apple.com/WebObjects/MZStore.woa/wa/viewContentsUserReviews?id=879143273&pageNumber=0&sortOrdering=2&type=Purple+Software&mt=8"]];
        } else if (indexPath.row == supportCoffee) {
            DLog(@"Buy Ads Removal");
            SKPayment *payment = [SKPayment paymentWithProduct:self.products[0]];
            [[SKPaymentQueue defaultQueue] addPayment:payment];
        } else if (indexPath.row == supportRestore) {
            DLog(@"Restore Ads Removal");
            [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
            [self disableAllStoreUIOptions];
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
        UIAlertView *alertBox = [[UIAlertView alloc] initWithTitle:title message:text delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
        [alertBox show];
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
    UIAlertView *lastAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Lock Code Set", nil)
                                                        message:[NSString stringWithFormat:NSLocalizedString(@"You just set the application lock code to %@.", nil), pin]
                                                       delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
    lastAlert.alertViewStyle = UIAlertViewStyleDefault;
    [lastAlert show];
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

- (IBAction)done:(id)sender
{
    // Dismiss (or ask for dismissing)
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
        [[NSNotificationCenter defaultCenter] postNotificationName:kPreferencesPopoverCanBeDismissed object:self];
    else
        [self.navigationController popToRootViewControllerAnimated:YES];
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
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle: @"Warning" message: @"Are you sure you want to change the encryption key?" delegate: self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Change It",nil];
    [alert show];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    [self cryptPasswordChangeAction:self];
    return NO;
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
	if (buttonIndex != alertView.cancelButtonIndex) {
        DLog(@"User confirmed changing the key, now really changing it from: '%@' to '%@'", self.oldEncryptionKey, self.cryptPasswordField.text);
        [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] setCryptPassword:self.cryptPasswordField.text];
        self.oldEncryptionKey = [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] cryptPassword];
        [self.cryptPasswordField resignFirstResponder];
	} else {
        self.cryptPasswordField.text = self.oldEncryptionKey;
    }
}

- (IBAction)lockCodeAction:(id)sender {
    if(self.lockSwitch.on) {
        THPinViewController *pinViewController = [[THPinViewController alloc] initWithDelegate:self];
        pinViewController.backgroundColor = [UIColor whiteColor];
        pinViewController.promptTitle = @"Enter PIN";
        pinViewController.promptColor = [UIColor colorWithRed:0.000 green:0.455 blue:0.780 alpha:1.000];
        pinViewController.view.tintColor = [UIColor colorWithRed:0.000 green:0.455 blue:0.780 alpha:1.000];
        pinViewController.hideLetters = YES;
        [self presentViewController:pinViewController animated:YES completion:nil];
    } else {
        NSError *error;
        [STKeychain deleteItemForUsername:@"lockCode" andServiceName:@"it.iltofa.turms" error:&error];
    }
}

@end
