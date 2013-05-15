//
//  IAMPrefsWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPrefsWindowController.h"
#import "IAMFilesystemSyncController.h"

#import "GTPiwikAddOn.h"
#import "IAMCryptPasswordWC.h"
#import "IAMWaitingWindowController.h"

@interface IAMPrefsWindowController ()

@property (copy) NSString *currentURL;
@property IAMCryptPasswordWC *cryptPasswordController;
@property IAMWaitingWindowController *waitingWindowController;
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
    [GTPiwikAddOn trackEvent:@"preferencesControllerLoaded"];
    NSData *originalDataPath = [[NSUserDefaults standardUserDefaults] dataForKey:@"syncDirectory"];
    NSAssert(originalDataPath, @"syncDirectory userdefault is not set!");
    NSString *fontName = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontName"];
    NSAssert(fontName, @"Default font not set in user defaults");
    double fontSize = [[NSUserDefaults standardUserDefaults] doubleForKey:@"fontSize"];
    self.currentFont = [NSFont fontWithName:fontName size:fontSize];
    self.encryptStatusButton = @([[IAMFilesystemSyncController sharedInstance] notesAreEncrypted]);
    BOOL staleData;
    NSError *error;
    NSURL *originalSyncDirectory = [NSURL URLByResolvingBookmarkData:originalDataPath options:NSURLBookmarkResolutionWithSecurityScope relativeToURL:nil bookmarkDataIsStale:&staleData error:&error];
    self.currentURL = [originalSyncDirectory path];
    [self.pathToLabel setStringValue:[NSString stringWithFormat:NSLocalizedString(@"Path to Notes: %@", nil), [originalSyncDirectory path]]];
}

- (IBAction)changePath:(id)sender {
    DLog(@"still to be implemented");
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.allowsMultipleSelection = NO;
    openPanel.canChooseDirectories = YES;
    openPanel.canChooseFiles = NO;
    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelCancelButton) {
            DLog(@"User canceled");
        } else {
            DLog(@"User selected URL %@", openPanel.URL);
            self.currentURL = [openPanel.URL path];
            [[IAMFilesystemSyncController sharedInstance] modifySyncDirectory:openPanel.URL];
            [GTPiwikAddOn trackEvent:@"notesPathChanged"];
        }
    }];
}

- (IBAction)actionChangeFont:(id)sender {
    NSFontManager * fontManager = [NSFontManager sharedFontManager];
    [fontManager setTarget:self];
    [fontManager setSelectedFont:self.currentFont isMultiple:NO];
    [fontManager orderFrontFontPanel:self];
}

- (IBAction)encryptButtonAction:(id)sender {
    DLog(@"Button status: %@", self.encryptStatusButton);
    if ([self.encryptStatusButton boolValue]) {
        DLog(@"Notes were not crypted, now set the password to crypt");
        [self changePasswordAction:self];
    } else {
        DLog(@"Remove crypt now.");
        [self showWaitingControllerWithString:@"Please wait while we decrypt the notes..."];
        [[IAMFilesystemSyncController sharedInstance] decryptNotesWithCompletionBlock:^{
            [[NSApplication sharedApplication] endSheet:self.waitingWindowController.window];
        }];
    }
}

- (IBAction)changePasswordAction:(id)sender {
    if(!self.cryptPasswordController) {
        self.cryptPasswordController = [[IAMCryptPasswordWC alloc] initWithWindowNibName:@"IAMCryptPasswordWC"];
    }
    [[NSApplication sharedApplication] beginSheet:self.cryptPasswordController.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
}

- (void)didEndSheet:(NSWindow *)sheet returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
    if(sheet == self.cryptPasswordController.window) {
        [self.cryptPasswordController.window orderOut:self];
        if(self.cryptPasswordController.validPassword) {
            NSAssert([self.encryptStatusButton boolValue], @"Crypt password set, but no encryption set or requested.");
            if([[IAMFilesystemSyncController sharedInstance] notesAreEncrypted]) {
                DLog(@"Notes are already encrypted. Re-Crypt with new password: %@", self.cryptPasswordController.validPassword);
                [self showWaitingControllerWithString:@"Please wait while we crypt the notes..."];
                [[IAMFilesystemSyncController sharedInstance] cryptNotesWithPassword:self.cryptPasswordController.validPassword andCompletionBlock:^{
                    [[NSApplication sharedApplication] endSheet:self.waitingWindowController.window];
                }];
            } else {
                DLog(@"Crypt now the notes with key: %@", self.cryptPasswordController.validPassword);
                [self showWaitingControllerWithString:@"Please wait while we re-encrypt the notes..."];
                [[IAMFilesystemSyncController sharedInstance] cryptNotesWithPassword:self.cryptPasswordController.validPassword andCompletionBlock:^{
                    [[NSApplication sharedApplication] endSheet:self.waitingWindowController.window];
                }];
            }
        } else {
            DLog(@"No valid password, reset the buttno to the \"actual\" status");
            self.encryptStatusButton = @([[IAMFilesystemSyncController sharedInstance] notesAreEncrypted]);
        }
        self.cryptPasswordController = nil;
    } else {
        // This is a windowWaiting controller
        [self.waitingWindowController.window orderOut:self];
    }
}

- (void)showWaitingControllerWithString:(NSString *)waitingString {
    if (!self.waitingWindowController) {
        self.waitingWindowController = [[IAMWaitingWindowController alloc] initWithWindowNibName:@"IAMWaitingWindowController"];
    }
    self.waitingWindowController.waitString = waitingString;
    [[NSApplication sharedApplication] beginSheet:self.waitingWindowController.window modalForWindow:self.window modalDelegate:self didEndSelector:@selector(didEndSheet:returnCode:contextInfo:) contextInfo:nil];
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
