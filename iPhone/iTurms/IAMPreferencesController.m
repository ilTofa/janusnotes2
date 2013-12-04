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
#import "iRate.h"

typedef enum {
    supportJanus = 0,
    sortSelector,
} sectionIdentifiers;

typedef enum {
    supportHelp = 0,
    supportUnsatisfied,
    supportSatisfied,
    supportCoffee,
    supportRestore
} supportOptions;

@interface IAMPreferencesController () <MFMailComposeViewControllerDelegate, SKProductsRequestDelegate>

@property NSArray *products;

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
    self.versionLabel.text = [NSString stringWithFormat:@"This is Turms %@ (%@)\n©2013 Giacomo Tufano - All rights reserved.\nIcons from icons8, licensed CC BY-ND 3.0", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]];
    // Load base values
    self.sortSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateSelector.selectedSegmentIndex = [[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    [self.tableView setContentOffset:CGPointZero animated:YES];
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
    for (NSString * invalidProductIdentifier in response.invalidProductIdentifiers) {
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
    if(indexPath.section == sortSelector) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
    }
    // Support
    if (indexPath.section == supportJanus) {
        if (indexPath.row == supportHelp) {
            DLog(@"Call help site.");
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://www.janusnotes.com/help/"]];
        } else if (indexPath.row == supportUnsatisfied) {
            DLog(@"Prepare email to support");
            [self sendCommentAction:self];
        } else if (indexPath.row == supportSatisfied) {
            DLog(@"Call iRate for rating");
            [[iRate sharedInstance] openRatingsPageInAppStore];
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
    [controller setSubject:[NSString stringWithFormat:@"Feedback on Turms iOS app version %@ (%@)", [[NSBundle mainBundle] infoDictionary][@"CFBundleShortVersionString"], [[NSBundle mainBundle] infoDictionary][@"CFBundleVersion"]]];
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

@end
