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
#import "Books.h"
#import "IAMNoteEdit.h"
#import "GTThemer.h"
#import "IAMPreferencesController.h"
#import "IAMBooksSelectionViewController.h"
#import "NSManagedObjectContext+FetchedObjectFromURI.h"
#import "THPinViewController.h"
#import "STKeychain.h"

@interface IAMViewController () <UISearchBarDelegate, NSFetchedResultsControllerDelegate, IAMBooksSelectionViewControllerDelegate, UIPopoverControllerDelegate>

@property (nonatomic) NSDateFormatter *dateFormatter;

@property NSTimer *pendingRefreshTimer;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *booksSelectionButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *preferencesButton;

@property NSString *booksQueryString;
@property (strong) NSArray *selectedBooks;

@property IAMAppDelegate *appDelegate;

@property UIPopoverController* popSegue;

@property SortKey sortKey;
@property DateShownKey dateShownKey;

- (IBAction)preferencesAction:(id)sender;

@end

@implementation IAMViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    if (self.appDelegate.pinRequestNeeded) {
        DLog(@"App wants PIN, show the dialog, then");
        [self getPin:nil];
    }
    [self loadPreviousSearchKeys];
    // Load & set some sane defaults
    self.managedObjectContext = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    self.dateFormatter = [[NSDateFormatter alloc] init];
	[self.dateFormatter setLocale:[NSLocale currentLocale]];
	[self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.dateFormatter setDoesRelativeDateFormatting:YES];
    // Ad support
    [self processAds:nil];
    self.navigationItem.leftBarButtonItem = self.editButtonItem;
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
    [(IAMAppDelegate *)[[UIApplication sharedApplication] delegate] setCurrentController:self];
    [self.navigationController setToolbarHidden:NO animated:YES];
    [self sortAgain];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(processAds:) name:kSkipAdProcessingChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(iCloudChangesComing:) name:kCoreDataStoreExternallyChanged object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(getPin:) name:kViewControllerShouldShowPINRequest object:nil];
    // Ad support
    [self processAds:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kSkipAdProcessingChanged object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kViewControllerShouldShowPINRequest object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kCoreDataStoreExternallyChanged object:nil];
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)iCloudChangesComing:(NSNotification *)note {
    DLog(@"Detected core data icloud changes, reloading.");
    [self sortAgain];
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
    self.sortKey = (SortKey)[[NSUserDefaults standardUserDefaults] integerForKey:@"sortBy"];
    self.dateShownKey = (DateShownKey)[[NSUserDefaults standardUserDefaults] integerForKey:@"dateShown"];
    DLog(@"Sort: %d, date: %d", self.sortKey, self.dateShownKey);
    [self setupFetchExecAndReload];
}

- (void)getPin:(NSNotification *)note {
    if (note) {
        DLog(@"Called from notification.");
    }
    [self.appDelegate getPinOnWindow:self];
}

#pragma mark - Search and search delegate

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
                queryString = [NSString stringWithFormat:@"title contains[cd] \"%@\"", term];
            else
                queryString = [queryString stringByAppendingFormat:@" AND title contains[cd] \"%@\"", term];
        }
    }
    if (self.booksQueryString) {
        if (!queryString) {
            queryString = @"title like \"*\" ";
        }
        queryString = [queryString stringByAppendingString:self.booksQueryString];
    }
    DLog(@"Fetching again. Query string is: '%@'", queryString);
    if (queryString) {
        NSPredicate *predicate = [NSPredicate predicateWithFormat:queryString];
        [fetchRequest setPredicate:predicate];
    }    
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

#pragma mark - Book Selection delegate

- (void)booksSelectionController:(IAMBooksSelectionViewController *)controller didSelectBooks:(NSArray *)booksArray {
    self.selectedBooks = booksArray;
    self.booksQueryString = nil;
    for (Books *selectedBook in booksArray) {
        if(self.booksQueryString == nil) {
            self.booksQueryString = [NSString stringWithFormat:@" AND (book.name = \"%@\"", selectedBook.name];
        } else {
            self.booksQueryString = [self.booksQueryString stringByAppendingFormat:@" OR book.name = \"%@\"", selectedBook.name];
        }
    }
    if (self.booksQueryString) {
        self.booksQueryString = [self.booksQueryString stringByAppendingFormat:@")"];
        DLog(@"Book selection string: '%@'", self.booksQueryString);
        [self.booksSelectionButton setTitle:@"Books: Some"];
    } else {
        [self.booksSelectionButton setTitle:@"Books: All"];
    }
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    UINavigationController *navigationController = (UINavigationController *)popoverController.contentViewController;
    IAMBooksSelectionViewController *controller = [[navigationController viewControllers] lastObject];
    [controller doneAction:self];
    self.selectedBooks = controller.selectedBooks;
    self.booksQueryString = nil;
    NSString *buttonTitleString;
    for (Books *selectedBook in self.selectedBooks) {
        if(self.booksQueryString == nil) {
            self.booksQueryString = [NSString stringWithFormat:@" AND (book.name = \"%@\"", selectedBook.name];
            buttonTitleString = [NSString stringWithFormat:@"Books: %@", selectedBook.name];
        } else {
            self.booksQueryString = [self.booksQueryString stringByAppendingFormat:@" OR book.name = \"%@\"", selectedBook.name];
            buttonTitleString = [buttonTitleString stringByAppendingFormat:@", %@", selectedBook.name];
        }
    }
    if (self.booksQueryString) {
        self.booksQueryString = [self.booksQueryString stringByAppendingFormat:@")"];
        if ([buttonTitleString length] > 35) {
            buttonTitleString = [NSString stringWithFormat:@"%@…", [buttonTitleString substringToIndex:35]];
        }
        [self.booksSelectionButton setTitle:buttonTitleString];
    } else {
        [self.booksSelectionButton setTitle:@"Books: All"];
    }
    [self sortAgain];
    if ([self.popSegue isPopoverVisible]) {
        self.popSegue = nil;
    }
    return YES;
}

#pragma mark - Fetched results controller delegate

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
	NSString *titleString = [NSString stringWithFormat:@"%@ %ld", [monthSymbols objectAtIndex:month-1], (long)year];
	return titleString;
}

/*
 // Override to support rearranging the table view.
 - (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
 {
 }
 */


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    return NO;
}

#pragma mark Segues

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // If on iPad and we already have an active popover for preferences, don't perform segue
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad && ([identifier isEqualToString:@"Preferences7"] || [identifier isEqualToString:@"BooksSelection"]) && [self.popSegue isPopoverVisible])
        return NO;
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"EditNote"]) {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        Note *selectedNote =  [[self fetchedResultsController] objectAtIndexPath:self.tableView.indexPathForSelectedRow];
        selectedNote.timeStamp = [NSDate date];
        noteEditor.idForTheNoteToBeEdited = [selectedNote objectID];
    }
    if ([[segue identifier] isEqualToString:@"BooksSelection"]) {
        IAMBooksSelectionViewController *booksSelector;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
            booksSelector = [segue destinationViewController];
        } else {
            UINavigationController *navigationController = (UINavigationController *)segue.destinationViewController;
            booksSelector = [[navigationController viewControllers] lastObject];
        }
        booksSelector.delegate = self;
        booksSelector.selectedBooks = self.selectedBooks;
        booksSelector.multiSelectionAllowed = YES;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            self.popSegue = ((UIStoryboardPopoverSegue *)segue).popoverController;
            self.popSegue.delegate = self;
        }
    }
}

- (void)dismissPopoverRequested:(NSNotification *) notification
{
    DLog(@"This is dismissPopoverRequested: called for %@", notification.object);
    if ([self.popSegue isPopoverVisible]) {
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
