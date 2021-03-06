//
//  IAMBooksSelectionViewController.m
//  Janus Notes
//
//  Created by Giacomo Tufano on 04/12/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import "IAMBooksSelectionViewController.h"

#import <CoreData/CoreData.h>
#import <iAd/iAd.h>

#import "IAMAppDelegate.h"
#import "Books.h"

@interface IAMBooksSelectionViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;

@end

@implementation IAMBooksSelectionViewController

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    NSAssert(self.delegate, @"IAMBooksSelectionViewController instantiated without delegate");
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.tableView.allowsMultipleSelection = self.multiSelectionAllowed;
    if (!self.managedObjectContext) {
        self.managedObjectContext = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self setupFetchExecAndReload];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dynamicFontChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)dynamicFontChanged:(NSNotification *)aNotification {
    [self.tableView reloadData];
}

#pragma mark - Data Fetching

- (void)setupFetchExecAndReload {
    // Set up the fetched results controller
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Books" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    // Set the batch size to a suitable number
    [fetchRequest setFetchBatchSize:25];
    NSArray *sortDescriptors = @[[[NSSortDescriptor alloc] initWithKey:@"name" ascending:YES]];
    [fetchRequest setSortDescriptors:sortDescriptors];
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
    self.fetchedResultsController.delegate = self;
    NSError *error = nil;
    if (self.fetchedResultsController != nil) {
        if (![[self fetchedResultsController] performFetch:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
        else {
            [self.tableView reloadData];
        }
    }
}

#pragma mark -
#pragma mark Fetched results controller delegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    if ([cell isSelected]) {
        // Deselect manually.
        if ([tableView.delegate respondsToSelector:@selector(tableView:willDeselectRowAtIndexPath:)]) {
            [tableView.delegate tableView:tableView willDeselectRowAtIndexPath:indexPath];
        }
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([tableView.delegate respondsToSelector:@selector(tableView:didDeselectRowAtIndexPath:)]) {
            [tableView.delegate tableView:tableView didDeselectRowAtIndexPath:indexPath];
        }
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didDeselectRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryNone;
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	NSInteger count = [[self.fetchedResultsController sections] count];
	return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
	NSInteger count = [sectionInfo numberOfObjects];
	return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Book";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier forIndexPath:indexPath];
    Books *book = [self.fetchedResultsController objectAtIndexPath:indexPath];
    // Check if already selected before
    cell.accessoryType = UITableViewCellAccessoryNone;
    for (Books *oldBooks in self.selectedBooks) {
        if ([book isEqual:oldBooks]) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.01 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^(void){
                cell.accessoryType = UITableViewCellAccessoryCheckmark;
            });
            [tableView selectRowAtIndexPath:indexPath animated:NO scrollPosition: UITableViewScrollPositionNone];
        }
    }
    cell.textLabel.text = book.name;
    return cell;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete on main moc
        NSError *error;
        Books *book = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DLog(@"Deleting book %@", book.name);
        [self.managedObjectContext deleteObject:book];
        if(![self.managedObjectContext save:&error])
            ALog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
}

- (IBAction)doneAction:(id)sender {
    // Get selected books.
    NSMutableArray *returnArray;
    NSArray *selectedRows = [self.tableView indexPathsForSelectedRows];
    if (!selectedRows) {
        DLog(@"No books selected.");
    } else {
        returnArray = [[NSMutableArray alloc] initWithCapacity:[selectedRows count]];
        DLog(@"%lu books selected.", (unsigned long)[selectedRows count]);
        for (NSIndexPath *indexPath in selectedRows) {
            Books *book = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [returnArray addObject:book];
        }
    }
    [self.delegate booksSelectionController:self didSelectBooks:returnArray];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
