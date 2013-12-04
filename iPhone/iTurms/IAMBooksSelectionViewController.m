//
//  IAMBooksSelectionViewController.m
//  iTurms
//
//  Created by Giacomo Tufano on 04/12/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMBooksSelectionViewController.h"

#import <CoreData/CoreData.h>
#import <iAd/iAd.h>

#import "IAMAppDelegate.h"
#import "Books.h"

@interface IAMBooksSelectionViewController () <NSFetchedResultsControllerDelegate>

@property (nonatomic, strong) NSFetchedResultsController *fetchedResultsController;
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

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
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
    self.managedObjectContext = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    [self setupFetchExecAndReload];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self processAds:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAds:) name:kSkipAdProcessingChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dynamicFontChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)processAds:(NSNotification *)note {
    if (note) {
        DLog(@"Called by notification...");
    }
    if (!((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).skipAds) {
        DLog(@"Preparing Ads");
        self.canDisplayBannerAds = YES;
        self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyAutomatic;
    } else {
        DLog(@"Skipping ads");
        self.canDisplayBannerAds = NO;
        self.interstitialPresentationPolicy = ADInterstitialPresentationPolicyNone;
    }
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
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:nil
                                                                                   cacheName:nil];
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
    cell.textLabel.text = book.name;
    return cell;
}

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

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

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

/*
#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}

 */

@end
