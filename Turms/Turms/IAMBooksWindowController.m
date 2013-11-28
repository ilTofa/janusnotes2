//
//  IAMBooksWindowController.m
//  Turms
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMBooksWindowController.h"
#import "IAMAppDelegate.h"
#import "Books.h"

@interface IAMBooksWindowController ()

@property (weak) NSManagedObjectContext *managedObjectContext;

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
    [self reloadBookArray];
}

- (void)reloadBookArray {
    self.bookList = [[NSMutableArray alloc] initWithObjects:@"Any", nil];
    // Set up the fetched results controller
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Books" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES];
    [fetchRequest setSortDescriptors:@[sortDescriptor]];
    NSError *error;
    NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
    if (!results) {
        NSLog(@"Error fetching bookList: %@", [error description]);
    } else {
        for (Books *book in results) {
            [self.bookList addObject:book.name];
        }
    }
    [self.tableView reloadData];
}

@end
