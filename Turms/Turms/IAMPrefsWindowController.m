//
//  IAMPrefsWindowController.m
// Turms
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPrefsWindowController.h"

#import "IAMAppDelegate.h"

@interface IAMPrefsWindowController ()

@property NSArray *nibTopElements;

@property NSString *oldEncryptionKey;

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

- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertSecondButtonReturn) {
        DLog(@"User confirmed changing the key, now really changing it from: '%@' to '%@'", self.oldEncryptionKey, self.encryptionKeyField.stringValue);
    }
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
