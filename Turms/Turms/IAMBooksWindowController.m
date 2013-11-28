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
#import "IAMAddBookWindowController.h"

@interface IAMBooksWindowController ()

@property (weak) NSManagedObjectContext *managedObjectContext;
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
    [self.arrayController setAutomaticallyRearrangesObjects:YES];
    [self reloadBookArray];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mocChanged:) name:NSManagedObjectContextDidSaveNotification object:self.managedObjectContext];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudDataChanged:) name:kCoreDataStoreExternallyChanged object:nil];
}

- (void)iCloudDataChanged:(NSNotification *)n {
    DLog(@"Triggering refresh of book array because new data came via iCloud refresh.");
    [self reloadBookArray];
}

- (void)mocChanged:(NSNotification *)n {
    DLog(@"Triggering refresh of book array because moc saved.");
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

- (IBAction)deleteBookAction:(id)sender {
    NSString *bookToBeDeleted = [self.arrayController selectedObjects][0];
    if (!bookToBeDeleted || [bookToBeDeleted isEqualToString:@"Any"]) {
        return;
    }
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
        NSString *bookToBeDeleted = [self.arrayController selectedObjects][0];
        DLog(@"User confirmed delete, now really deleting note: %@", bookToBeDeleted);
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        // Edit the entity name as appropriate.
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Books" inManagedObjectContext:self.managedObjectContext];
        [fetchRequest setEntity:entity];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name = %@", bookToBeDeleted];
        [fetchRequest setPredicate:predicate];
        NSArray *results = [self.managedObjectContext executeFetchRequest:fetchRequest error:&error];
        if (!results) {
            NSLog(@"Error fetching bookList: %@", [error description]);
        } else {
            [self.managedObjectContext deleteObject:results[0]];
            if(![self.managedObjectContext save:&error]) {
                ALog(@"Unresolved error deleting %@: %@", bookToBeDeleted, [error userInfo]);
            }
        }
        [self.tableView reloadData];
    }
}

- (IBAction)addBookAction:(id)sender {
    self.addBookCtr = [[IAMAddBookWindowController alloc] initWithWindowNibName:@"IAMAddBookWindowController"];
    [self.window beginSheet:self.addBookCtr.window completionHandler:^(NSModalResponse returnCode) {
        DLog(@"Returned %ld", (long)returnCode);
    }];
}

@end
