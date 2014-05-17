//
//  IAMPrefsWindowController.m
// Turms
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPrefsWindowController.h"

#import "IAMAppDelegate.h"

@interface IAMPrefsWindowController () <SKProductsRequestDelegate>

@property NSArray *nibTopElements;
@property NSString *oldEncryptionKey;
@property NSArray *products;

@end

@implementation IAMPrefsWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        // Initialization code here.
    }
    
    return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    NSAssert(fontName, @"Default font not set in user defaults");
    double fontSize = [[NSUserDefaults standardUserDefaults] doubleForKey:@"fontSize"];
    self.currentFont = [NSFont fontWithName:fontName size:fontSize];
    self.encryptionKeyField.stringValue = self.oldEncryptionKey = [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] cryptPassword];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(skipAdProcessed:) name:kSkipAdProcessingChanged object:nil];
    [self updateStoreUI];
}

- (IBAction)actionChangeFont:(id)sender {
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setSelectedFont:self.currentFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (IBAction)changeEncryptionKey:(id)sender {
    if ([self.oldEncryptionKey isEqualToString:self.encryptionKeyField.stringValue]) {
        return;
    }
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Are you sure you want to change the encryption key?", nil)];
    [alert setMessageText:NSLocalizedString(@"Warning", @"")];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Change It"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void)skipAdProcessed:(NSNotification *)aNotification {
    DLog(@"Got a notifaction for store processing");
    [self updateStoreUI];
}

- (void)disableAllStoreUIOptions {
    self.productCoffeeLabel.enabled = self.restoreCellLabel.enabled = NO;
    self.productCoffeePriceLabel.enabled = NO;
    self.productCoffeePriceLabel.stringValue = @"-";
}

- (void)updateStoreUI {
    // Disable store while we look for the products
    [self disableAllStoreUIOptions];
    // No money? No products!
    if (![SKPaymentQueue canMakePayments]) {
        self.productCoffeePriceLabel.stringValue = @"Payments disabled.";
        return;
    }
    // If user already paid, leave disabled
    if (((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).skipAds) {
        self.productCoffeePriceLabel.stringValue = @"Already bought. Thank you!";
        return;
    }
    // If a transaction is already in progress, leave disabled
    if (((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).processingPurchase) {
        self.productCoffeePriceLabel.stringValue = @"Transaction still in progress.";
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
    [self.productCoffeeLabel setTitle:product.localizedTitle];
    NSNumberFormatter * numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    [numberFormatter setLocale:product.priceLocale];
    NSString * formattedPrice = [numberFormatter stringFromNumber:product.price];
    self.productCoffeePriceLabel.stringValue = formattedPrice;
    self.productCoffeeLabel.enabled = YES;
    self.restoreCellLabel.enabled = YES;
}

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error {
    DLog(@"request failed: %@,  %@", request, error);
}

- (IBAction)restorePurchase:(id)sender {
    DLog(@"Restore Ads Removal");
    [[SKPaymentQueue defaultQueue] restoreCompletedTransactions];
    [self disableAllStoreUIOptions];
}

- (IBAction)removeAds:(id)sender {
    DLog(@"Buy Ads Removal");
    SKPayment *payment = [SKPayment paymentWithProduct:self.products[0]];
    [[SKPaymentQueue defaultQueue] addPayment:payment];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertSecondButtonReturn) {
        DLog(@"User confirmed changing the key, now really changing it from: '%@' to '%@'", self.oldEncryptionKey, self.encryptionKeyField.stringValue);
    }
    [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] setCryptPassword:self.encryptionKeyField.stringValue];
    self.oldEncryptionKey = [(IAMAppDelegate *)[[NSApplication sharedApplication] delegate] cryptPassword];
}


- (void)changeFont:(id)sender {
    NSFont *newFont = [sender convertFont:self.currentFont];
    DLog(@"New selected font: %@", newFont);
    self.currentFont = newFont;
    [[NSUserDefaults standardUserDefaults] setObject:self.currentFont.fontName forKey:@"fontName"];
    [[NSUserDefaults standardUserDefaults] setDouble:self.currentFont.pointSize forKey:@"fontSize"];
    return;
}

@end
