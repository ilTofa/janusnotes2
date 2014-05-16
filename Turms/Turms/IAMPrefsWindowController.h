//
//  IAMPrefsWindowController.h
// Turms
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMPrefsWindowController : NSWindowController

@property NSFont *currentFont;
@property (weak) IBOutlet NSTextField *encryptionKeyField;
@property (weak) IBOutlet NSTextField *productCoffeePriceLabel;
@property (weak) IBOutlet NSButton *productCoffeeLabel;
@property (weak) IBOutlet NSButton *restoreCellLabel;

- (IBAction)actionChangeFont:(id)sender;
- (IBAction)changeEncryptionKey:(id)sender;
- (IBAction)restorePurchase:(id)sender;
- (IBAction)removeAds:(id)sender;

@end
