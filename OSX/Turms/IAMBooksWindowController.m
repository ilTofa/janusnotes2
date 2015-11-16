//
//  IAMBooksWindowController.m
//  Janus Notes 2
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMBooksWindowController.h"
#import "IAMAppDelegate.h"
#import "Books.h"
#import "IAMAddBookWindowController.h"

@interface IAMBooksWindowController ()

@property IAMAddBookWindowController *addBookCtr;

@end

@implementation IAMBooksWindowController

- (id)initWithWindow:(NSWindow *)window
{
    self = [super initWithWindow:window];
    if (self) {
        DLog(@"Here");
    }
    return self;
}

- (void)awakeFromNib {
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
    DLog(@"Here");
    self.managedObjectContext = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).managedObjectContext;
}

- (IBAction)deleteBookAction:(id)sender {
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setInformativeText:NSLocalizedString(@"Are you sure you want to delete the book?", nil)];
    [alert setMessageText:NSLocalizedString(@"Warning", @"")];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addButtonWithTitle:@"Delete"];
    [alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:nil];
}

- (void) alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
    if(returnCode == NSAlertSecondButtonReturn)
    {
        // Delete on main moc
        NSError *error;
        DLog(@"User confirmed delete, now really deleting note: %@", ((Books *)([self.arrayController selectedObjects][0])).name);
        [self.managedObjectContext deleteObject:[self.arrayController selectedObjects][0]];
        if(![self.managedObjectContext save:&error]) {
            ALog(@"Unresolved error %@, %@", error, [error userInfo]);
        }
    }
}

- (IBAction)addBookAction:(id)sender {
    self.addBookCtr = [[IAMAddBookWindowController alloc] initWithWindowNibName:@"IAMAddBookWindowController"];
    [self.window beginSheet:self.addBookCtr.window completionHandler:^(NSModalResponse returnCode) {
        DLog(@"Returned %ld", (long)returnCode);
    }];
}

@end
