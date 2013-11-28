//
//  IAMAddBookWindowController.m
//  Turms
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAddBookWindowController.h"

#import "IAMAppDelegate.h"
#import "Books.h"

@interface IAMAddBookWindowController ()

@end

@implementation IAMAddBookWindowController

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
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

- (void)awakeFromNib {
    DLog(@"Pippo!");
}

- (IBAction)OKAction:(id)sender {
    if ([self.bookNameField.stringValue isEqualToString:@""]) {
        DLog(@"void book, canceling.");
        [self cancelAction:self];
    } else {
        DLog(@"Now save %@ to book list!", self.bookNameField.stringValue);
        NSManagedObjectContext *moc = ((IAMAppDelegate *)[[NSApplication sharedApplication] delegate]).managedObjectContext;
        NSError *error;
        Books *newBook = [NSEntityDescription insertNewObjectForEntityForName:@"Books" inManagedObjectContext:moc];
        newBook.name = self.bookNameField.stringValue;
        if (![moc save:&error]) {
            ALog(@"Unresolved error saving book %@, %@", error, [error userInfo]);
        } else {
            [self cancelAction:self];
        }
    }
}

- (IBAction)cancelAction:(id)sender {
    [self.window.sheetParent endSheet:self.window];
}
@end
