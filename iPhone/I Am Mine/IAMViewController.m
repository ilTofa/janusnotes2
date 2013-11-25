//
//  IAMViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMViewController.h"

#import <iAd/iAd.h>

#import "IAMAppDelegate.h"
#import "IAMNoteCell.h"
#import "Note.h"
#import "IAMNoteEdit.h"
#import "GTThemer.h"
#import "MBProgressHUD.h"
#import "IAMPreferencesController.h"
#import "NSManagedObjectContext+FetchedObjectFromURI.h"

@interface IAMViewController () <UISearchBarDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic) NSDateFormatter *dateFormatter;
@property MBProgressHUD *hud;

@property BOOL dropboxSyncStillPending;
@property (atomic) NSDate *lastDropboxSync;
@property NSTimer *pendingRefreshTimer;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *preferencesButton;

@property IAMAppDelegate *appDelegate;

@property UIPopoverController* popSegue;

@property SortKey sortKey;
@property DateShownKey dateShownKey;

- (IBAction)preferencesAction:(id)sender;

@end

@implementation IAMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dropboxSyncStillPending = NO;
    [self loadPreviousSearchKeys];
    // Load & set some sane defaults
    self.appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    self.dateFormatter = [[NSDateFormatter alloc] init];
	[self.dateFormatter setLocale:[NSLocale currentLocale]];
	[self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.dateFormatter setDoesRelativeDateFormatting:YES];
    NSArray *leftButtons = @[self.editButtonItem, self.preferencesButton];
    self.navigationItem.leftBarButtonItems = leftButtons;
    // Notifications to be honored during controller lifecycle
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissPopoverRequested:) name:kPreferencesPopoverCanBeDismissed object:nil];
    }
    [self processAds:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dynamicFontChanged:) name:UIContentSizeCategoryDidChangeNotification object:nil];
    [self setupFetchExecAndReload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
//        // Workaround a modification on tableView content inset that happens on returning from note editor.
//        self.tableView.contentInset = UIEdgeInsetsMake(64.0, 0, 0, 0);
//    }
    [self sortAgain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAds:) name:kSkipAdProcessingChanged object:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSkipAdProcessingChanged object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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

-(void)colorize
{
    [[GTThemer sharedInstance] applyColorsToView:self.tableView];
    [[GTThemer sharedInstance] applyColorsToView:self.navigationController.navigationBar];
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
    [[GTThemer sharedInstance] applyColorsToView:self.searchBar];
    [self.tableView reloadData];
}

- (void)sortAgain {
    self.sortKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateShownKey = [[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    DLog(@"Sort: %d, date: %d", self.sortKey, self.dateShownKey);
    [self setupFetchExecAndReload];
}

#pragma mark -
#pragma mark Search and search delegate

-(void)loadPreviousSearchKeys {
    self.searchText = [[NSUserDefaults standardUserDefaults] stringForKey:@"searchText"];
    if(!self.searchText)
        self.searchText = @"";
    self.searchBar.text = self.searchText;
}

-(void)saveSearchKeys {
    [[NSUserDefaults standardUserDefaults] setObject:self.searchText forKey:@"searchText"];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:YES animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    searchBar.text = self.searchText = @"";
    [self setupFetchExecAndReload];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    self.searchText = searchBar.text;
    [self setupFetchExecAndReload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    self.searchText = searchBar.text;
    // Perform search... :)
    [self setupFetchExecAndReload];
}

- (void)setupFetchExecAndReload {
    // Set up the fetched results controller
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number
    [fetchRequest setFetchBatchSize:25];
    
    // Edit the sort key as appropriate.
    NSString *sortField = @"timeStamp";
    BOOL sortDirectionAscending = NO;
    if (self.sortKey == sortModification) {
        sortField = @"timeStamp";
    } else if (self.sortKey == sortCreation) {
        sortField = @"creationDate";
    } else if (self.sortKey == sortTitle) {
        sortField = @"title";
        sortDirectionAscending = YES;
    }
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:sortField ascending:sortDirectionAscending];
    NSArray *sortDescriptors = @[dateAddedSortDesc];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSString *queryString = nil;
    if(![self.searchText isEqualToString:@""])
    {
        // Complex NSPredicate needed to match any word in the search string
        NSArray *terms = [self.searchText componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        for(NSString *term in terms)
        {
            if([term length] == 0)
                continue;
            if(queryString == nil)
                queryString = [NSString stringWithFormat:@"(text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
            else
                queryString = [queryString stringByAppendingFormat:@" AND (text contains[cd] \"%@\" OR title contains[cd] \"%@\")", term, term];
        }
    }
    else
        queryString = @"text  like[c] \"*\"";
//    DLog(@"Fetching again. Query string is: '%@'", queryString);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:queryString];
    [fetchRequest setPredicate:predicate];
    
    NSString *sectionNameKeyPath = @"sectionIdentifier";
    if (self.sortKey == sortTitle) {
        sectionNameKeyPath = nil;
    } else if (self.sortKey == sortCreation) {
        sectionNameKeyPath = @"creationIdentifier";
    }
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:sectionNameKeyPath
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
    [self saveSearchKeys];
}

#pragma mark -
#pragma mark Fetched results controller delegate

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller {
    [self.tableView reloadData];
}

#pragma mark - Table view data source

- (void)configureCell:(IAMNoteCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Note *note = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.titleLabel.text = note.title;
    cell.noteTextLabel.text = note.text;
    if (self.dateShownKey == modificationDateShown) {
        cell.dateLabel.text = [self.dateFormatter stringFromDate:note.timeStamp];
    } else {
        cell.dateLabel.text = [self.dateFormatter stringFromDate:note.creationDate];
    }
    cell.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleHeadline];
    cell.noteTextLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCaption1];
    NSUInteger attachmentsQuantity = 0;
    if(note.attachment) {
        attachmentsQuantity = [note.attachment count];
    }
    cell.attachmentsQuantityLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu attachment(s)", nil), attachmentsQuantity];
}

// Override to customize the look of a cell representing an object. The default is to display
// a UITableViewCellStyleDefault style cell with the label being the first key in the object.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"TextCell";
    IAMNoteCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[IAMNoteCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
	NSInteger count = [[self.fetchedResultsController sections] count];
	return count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	id <NSFetchedResultsSectionInfo> sectionInfo = [[self.fetchedResultsController sections] objectAtIndex:section];
	NSInteger count = [sectionInfo numberOfObjects];
	return count;
}

// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete)
    {
        // Delete on main moc
        NSError *error;
        Note *note = [self.fetchedResultsController objectAtIndexPath:indexPath];
        DLog(@"Deleting note %@", note.title);
        [self.managedObjectContext deleteObject:note];
        if(![self.managedObjectContext save:&error])
            ALog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    // No sections (and section title) if sort by title
    if (self.sortKey == sortTitle) {
        return nil;
    }
	id <NSFetchedResultsSectionInfo> theSection = [[self.fetchedResultsController sections] objectAtIndex:section];
    /*
     Section information derives from an event's sectionIdentifier, which is a string representing the number (year * 1000) + month.
     To display the section title, convert the year and month components to a string representation.
     */
    static NSArray *monthSymbols = nil;
    
    if (!monthSymbols) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setCalendar:[NSCalendar currentCalendar]];
        monthSymbols = [formatter monthSymbols];
    }
    NSInteger numericSection = [[theSection name] integerValue];
	NSInteger year = numericSection / 1000;
	NSInteger month = numericSection - (year * 1000);
	NSString *titleString = [NSString stringWithFormat:@"%@ %d", [monthSymbols objectAtIndex:month-1], year];
	return titleString;
}

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    return NO;
}

#pragma mark Segues

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // If on iPad and we already have an active popover for preferences, don't perform segue
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && [identifier isEqualToString:@"Preferences7"] && [self.popSegue isPopoverVisible])
        return NO;
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
/*    if ([[segue identifier] isEqualToString:@"AddTextNote"])
    {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        // Create a new note
        IAMAppDelegate *appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.coreDataController.mainThreadContext];
        noteEditor.editedNote = newNote;
        noteEditor.moc = appDelegate.coreDataController.mainThreadContext;
    }*/
    if ([[segue identifier] isEqualToString:@"EditNote"])
    {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        Note *selectedNote =  [[self fetchedResultsController] objectAtIndexPath:self.tableView.indexPathForSelectedRow];
        selectedNote.timeStamp = [NSDate date];
        noteEditor.idForTheNoteToBeEdited = [selectedNote objectID];
    }
}

- (void)dismissPopoverRequested:(NSNotification *) notification
{
    DLog(@"This is dismissPopoverRequested: called for %@", notification.object);
    if ([self.popSegue isPopoverVisible])
    {
        [self.popSegue dismissPopoverAnimated:YES];
        self.popSegue = nil;
        [self sortAgain];
    }
}

- (IBAction)preferencesAction:(id)sender {
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self performSegueWithIdentifier:@"Preferences7" sender:self];
    } else {
        if ([self.popSegue isPopoverVisible]) {
            // protect double instancing
            return;
        }
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"MainStoryboard_iPad" bundle:nil];
        IAMPreferencesController *pc = [storyboard instantiateViewControllerWithIdentifier:@"Preferences7"];
        self.popSegue = [[UIPopoverController alloc] initWithContentViewController:pc];
        [self.popSegue presentPopoverFromBarButtonItem:self.preferencesButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

@end
