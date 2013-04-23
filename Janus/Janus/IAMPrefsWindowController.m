//
//  IAMPrefsWindowController.m
//  Janus
//
//  Created by Giacomo Tufano on 23/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMPrefsWindowController.h"
#import "IAMFilesystemSyncController.h"

@interface IAMPrefsWindowController ()

@property (copy) NSString *currentURL;

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
    
    NSData *originalDataPath = [[NSUserDefaults standardUserDefaults] dataForKey:@"syncDirectory"];
    NSAssert(originalDataPath, @"syncDirectory userdefault is not set!");
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
//            [[IAMFilesystemSyncController sharedInstance] modifySyncDirectory:openPanel.URL];
        }
    }];
}

@end
