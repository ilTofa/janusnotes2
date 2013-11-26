//
//  IAMPrefsWindowController.m
// Turms
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPrefsWindowController.h"

@interface IAMPrefsWindowController ()

@property NSArray *nibTopElements;

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
}

- (IBAction)actionChangeFont:(id)sender {
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setSelectedFont:self.currentFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
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
