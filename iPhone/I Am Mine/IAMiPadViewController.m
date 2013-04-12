//
//  IAMiPadViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 11/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMiPadViewController.h"

#import "IAMiPadNoteCell.h"
#import "IAMiPadSectionHeader.h"

#import "IAMAppDelegate.h"
#import "Note.h"
#import "IAMNoteEdit.h"
#import "NSDate+PassedTime.h"
#import "GTThemer.h"
#import "IAMPreferencesController.h"
#import "IAMDataSyncController.h"

@interface IAMiPadViewController () <UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout, UIActionSheetDelegate>

@property NSMutableArray *objectChanges;
@property NSMutableArray *sectionChanges;

@property (weak, nonatomic) IBOutlet UISearchBar *searchBar;
@property (strong, nonatomic) NSString *searchText;

@property (nonatomic) NSDateFormatter *dateFormatter;
@property IAMAppDelegate *appDelegate;

@property (nonatomic, weak) IBOutlet UICollectionView *collectionView;

@property NSIndexPath *selectedCell;
- (IBAction)deleteCell:(id)sender;

@property UIStoryboardPopoverSegue* popSegue;

@end

@implementation IAMiPadViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.objectChanges = [NSMutableArray array];
    self.sectionChanges = [NSMutableArray array];
    [self loadPreviousSearchKeys];
    // Set some sane defaults
    self.appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = self.appDelegate.coreDataController.mainThreadContext;
    self.dateFormatter = [[NSDateFormatter alloc] init];
	[self.dateFormatter setLocale:[NSLocale currentLocale]];
	[self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.dateFormatter setDoesRelativeDateFormatting:YES];
    // Notifications to be honored during controller lifecycle
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFetchedResults:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:self.appDelegate.coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFetchedResults:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:self.appDelegate.coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(dismissPopoverRequested:) name:kPreferencesPopoverCanBeDismissed object:nil];
    NSManagedObjectContext *syncMOC = [IAMDataSyncController sharedInstance].dataSyncThreadContext;
    NSAssert(syncMOC, @"The Managed Object Context for the Sync Engine is still not set while setting main view.");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeSyncChanges:) name:NSManagedObjectContextDidSaveNotification object:syncMOC];
    [self setupFetchExecAndReload];
}

- (void)viewDidAppear:(BOOL)animated
{
    DLog(@"This is IAMiPadViewController:viewDidAppear:");
    [super viewDidAppear:animated];
    // If we're getting back from an edit without saving...
    if([self.managedObjectContext hasChanges])
        [self.managedObjectContext rollback];
    [self colorize];
}

-(void)colorize
{
    [[GTThemer sharedInstance] applyColorsToView:self.collectionView];
    [[GTThemer sharedInstance] applyColorsToView:self.navigationController.navigationBar];
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
    [[GTThemer sharedInstance] applyColorsToView:self.searchBar];
    [self.collectionView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark -
#pragma mark Search and search delegate

-(void)loadPreviousSearchKeys
{
    DLog(@"Loading previous search keys.");
    self.searchText = [[NSUserDefaults standardUserDefaults] stringForKey:@"searchText"];
    if(!self.searchText)
        self.searchText = @"";
    self.searchBar.text = self.searchText;
}

-(void)saveSearchKeys
{
    DLog(@"Saving search keys for later use.");
    [[NSUserDefaults standardUserDefaults] setObject:self.searchText forKey:@"searchText"];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar
{
    [searchBar setShowsCancelButton:YES animated:YES];
    self.collectionView.allowsSelection = NO;
    self.collectionView.scrollEnabled = NO;
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
    DLog(@"End editing on search bar. Last search and restoring colelctionView");
    [self searchBarSearchButtonClicked:searchBar];
}


- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    DLog(@"Cancel clicked");
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    self.collectionView.allowsSelection = YES;
    self.collectionView.scrollEnabled = YES;
    searchBar.text = self.searchText = @"";
    [self setupFetchExecAndReload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    DLog(@"Search clicked, should start for '%@'", searchBar.text);
    [searchBar resignFirstResponder];
    self.searchText = searchBar.text;
    self.collectionView.allowsSelection = YES;
    self.collectionView.scrollEnabled = YES;
    // Perform search... :)
    DLog(@"Now searching %@", self.searchText);
    [self setupFetchExecAndReload];
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText
{
    self.searchText = searchBar.text;
    DLog(@"Now searching (continous) %@", self.searchText);
    [self setupFetchExecAndReload];
}

- (void)mergeSyncChanges:(NSNotification *)note {
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:note];
    [self setupFetchExecAndReload];
}

- (void)reloadFetchedResults:(NSNotification *)note
{
    DLog(@"this is reloadFetchedResults: that got a notification.");
    dispatch_async(dispatch_get_main_queue(), ^{
        NSError *error = nil;
        
        if (self.fetchedResultsController)
        {
            if (![[self fetchedResultsController] performFetch:&error])
            {
                /*
                 Replace this implementation with code to handle the error appropriately.
                 
                 abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
                 */
                NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
                abort();
            } else {
                [self.collectionView reloadData];
            }
        }
    });
}

- (void)setupFetchExecAndReload
{
    // Set up the fetched results controller
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Note" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number
    [fetchRequest setFetchBatchSize:25];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
    NSArray *sortDescriptors = @[dateAddedSortDesc];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    NSString *queryString = nil;
    if(![self.searchText isEqualToString:@""])
    {
        // Complex NSPredicate needed to match any word in the search string
        DLog(@"Fetching again. Query string is: '%@'", self.searchText);
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
    DLog(@"Fetching again. Query string is: '%@'", queryString);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:queryString];
    [fetchRequest setPredicate:predicate];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:@"sectionIdentifier"
                                                                                   cacheName:nil];
    self.fetchedResultsController.delegate = self;
    DLog(@"Fetch setup to: %@", self.fetchedResultsController);
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
        else
            [self.collectionView reloadData];
    }
    [self saveSearchKeys];
}

#pragma mark - UICollectionVIew

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects];
}

- (void)configureCell:(IAMiPadNoteCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Note *note = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.cellBackground.image = [UIImage imageNamed:[[GTThemer sharedInstance] backgroundImageName]];
    [[GTThemer sharedInstance] applyColorsToLabel:cell.titleLabel withFontSize:17];
    cell.titleLabel.text = note.title;
    [[GTThemer sharedInstance] applyColorsToLabel:cell.noteTextLabel withFontSize:12];
    cell.noteTextLabel.text = note.text;
    [[GTThemer sharedInstance] applyColorsToLabel:cell.dateLabel withFontSize:10];
    if(fabs([note.timeStamp timeIntervalSinceDate:note.creationDate]) < 2)
        cell.dateLabel.text = [NSString stringWithFormat:@"%@, never modified", [self.dateFormatter stringFromDate:note.creationDate]];
    else
        cell.dateLabel.text = [NSString stringWithFormat:@"%@, modified %@", [self.dateFormatter stringFromDate:note.creationDate], [note.timeStamp gt_timePassed]];
    [[GTThemer sharedInstance] applyColorsToLabel:cell.attachmentsQuantityLabel withFontSize:10];
    NSUInteger attachmentsQuantity = 0;
    if(note.attachment)
        attachmentsQuantity = [note.attachment count];
    cell.attachmentsQuantityLabel.text = [NSString stringWithFormat:NSLocalizedString(@"%lu attachment(s)", nil), attachmentsQuantity];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"iPadCell";
    IAMiPadNoteCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CellIdentifier forIndexPath:indexPath];
    [self configureCell:cell atIndexPath:indexPath];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    id <NSFetchedResultsSectionInfo> theSection = [[self.fetchedResultsController sections] objectAtIndex:indexPath.section];
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
    static NSString *HeaderIdentifier = @"SectionHeader";
    IAMiPadSectionHeader *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:HeaderIdentifier forIndexPath:indexPath];
    [[GTThemer sharedInstance] applyColorsToLabel:headerView.sectionHeaderTitleLabel withFontSize:19];
    headerView.sectionHeaderTitleLabel.text = titleString;
    return headerView;
}

#pragma mark - Fetched results controller delegate

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    
    NSMutableDictionary *change = [NSMutableDictionary new];
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = @(sectionIndex);
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = @(sectionIndex);
            break;
    }
    
    [_sectionChanges addObject:change];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    
    NSMutableDictionary *change = [NSMutableDictionary new];
    switch(type)
    {
        case NSFetchedResultsChangeInsert:
            change[@(type)] = newIndexPath;
            break;
        case NSFetchedResultsChangeDelete:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeUpdate:
            change[@(type)] = indexPath;
            break;
        case NSFetchedResultsChangeMove:
            change[@(type)] = @[indexPath, newIndexPath];
            break;
    }
    [_objectChanges addObject:change];
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    if ([_sectionChanges count] > 0)
    {
        [self.collectionView performBatchUpdates:^{
            
            for (NSDictionary *change in _sectionChanges)
            {
                [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
                    
                    NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                    switch (type)
                    {
                        case NSFetchedResultsChangeInsert:
                            [self.collectionView insertSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                            break;
                        case NSFetchedResultsChangeDelete:
                            [self.collectionView deleteSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                            break;
                        case NSFetchedResultsChangeUpdate:
                            [self.collectionView reloadSections:[NSIndexSet indexSetWithIndex:[obj unsignedIntegerValue]]];
                            break;
                    }
                }];
            }
        } completion:nil];
    }
    
    if ([_objectChanges count] > 0 && [_sectionChanges count] == 0)
    {
        
        if ([self shouldReloadCollectionViewToPreventKnownIssue]) {
            // This is to prevent a bug in UICollectionView from occurring.
            // The bug presents itself when inserting the first object or deleting the last object in a collection view.
            // http://stackoverflow.com/questions/12611292/uicollectionview-assertion-failure
            // This code should be removed once the bug has been fixed, it is tracked in OpenRadar
            // http://openradar.appspot.com/12954582
            [self.collectionView reloadData];
            
        } else {
            
            [self.collectionView performBatchUpdates:^{
                
                for (NSDictionary *change in _objectChanges)
                {
                    [change enumerateKeysAndObjectsUsingBlock:^(NSNumber *key, id obj, BOOL *stop) {
                        
                        NSFetchedResultsChangeType type = [key unsignedIntegerValue];
                        switch (type)
                        {
                            case NSFetchedResultsChangeInsert:
                                [self.collectionView insertItemsAtIndexPaths:@[obj]];
                                break;
                            case NSFetchedResultsChangeDelete:
                                [self.collectionView deleteItemsAtIndexPaths:@[obj]];
                                break;
                            case NSFetchedResultsChangeUpdate:
                                [self.collectionView reloadItemsAtIndexPaths:@[obj]];
                                break;
                            case NSFetchedResultsChangeMove:
                                [self.collectionView moveItemAtIndexPath:obj[0] toIndexPath:obj[1]];
                                break;
                        }
                    }];
                }
            } completion:nil];
        }
        
        [_sectionChanges removeAllObjects];
        [_objectChanges removeAllObjects];
    }
}

- (BOOL)shouldReloadCollectionViewToPreventKnownIssue {
    __block BOOL shouldReload = NO;
    for (NSDictionary *change in self.objectChanges) {
        [change enumerateKeysAndObjectsUsingBlock:^(id key, id obj, BOOL *stop) {
            NSFetchedResultsChangeType type = [key unsignedIntegerValue];
            NSIndexPath *indexPath = obj;
            switch (type) {
                case NSFetchedResultsChangeInsert:
                    if ([self.collectionView numberOfItemsInSection:indexPath.section] == 0) {
                        shouldReload = YES;
                    } else {
                        shouldReload = NO;
                    }
                    break;
                case NSFetchedResultsChangeDelete:
                    if ([self.collectionView numberOfItemsInSection:indexPath.section] == 1) {
                        shouldReload = YES;
                    } else {
                        shouldReload = NO;
                    }
                    break;
                case NSFetchedResultsChangeUpdate:
                    shouldReload = NO;
                    break;
                case NSFetchedResultsChangeMove:
                    shouldReload = NO;
                    break;
            }
        }];
    }
    
    return shouldReload;
}

#pragma mark Segues

-(BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender
{
    // If we already have an active popover for preferences, don't perform segue
    if ([identifier isEqualToString:@"Preferences"] && [self.popSegue.popoverController isPopoverVisible])
        return NO;
    return YES;
}

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"AddTextNote"])
    {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        // Create a new note
        IAMAppDelegate *appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.coreDataController.mainThreadContext];
        noteEditor.editedNote = newNote;
        noteEditor.moc = appDelegate.coreDataController.mainThreadContext;
    }
    if ([[segue identifier] isEqualToString:@"EditNote"])
    {
        IAMNoteEdit *noteEditor = [segue destinationViewController];
        NSIndexPath *selectedItem = self.collectionView.indexPathsForSelectedItems[0];
        DLog(@"Calling EditNote for %@", selectedItem);
        if(selectedItem)
        {
            Note *selectedNote =  [[self fetchedResultsController] objectAtIndexPath:selectedItem];
            selectedNote.timeStamp = [NSDate date];
            noteEditor.editedNote = selectedNote;
            noteEditor.moc = self.managedObjectContext;
        }
    }
    if ([[segue identifier] isEqualToString:@"Preferences"])
        self.popSegue = (UIStoryboardPopoverSegue *)segue;
}

- (IBAction)deleteCell:(UIGestureRecognizer *)sender
{
    self.selectedCell = [self.collectionView indexPathForItemAtPoint:[sender locationInView:self.collectionView]];
    if (sender.state == UIGestureRecognizerStateEnded) {
        DLog(@"This is deleteCell: UIGestureRecognizerStateEnded called for %@", self.selectedCell);
    }
    else if (sender.state == UIGestureRecognizerStateBegan){
        DLog(@"This is deleteCell: UIGestureRecognizerStateBegan called for %@", self.selectedCell);
        UIActionSheet *chooseIt = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Delete This Note?", nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"No", nil)
                                                destructiveButtonTitle:NSLocalizedString(@"Yes, Delete It!", nil)
                                                     otherButtonTitles:nil];
        [chooseIt showFromRect:[[self.collectionView cellForItemAtIndexPath:self.selectedCell] frame] inView:self.collectionView animated:YES];
        [chooseIt showInView:self.view];
    }
}

- (void)dismissPopoverRequested:(NSNotification *) notification
{
    DLog(@"This is dismissPopoverRequested: called for %@", notification.object);
    if ([self.popSegue.popoverController isPopoverVisible])
    {
        [self.popSegue.popoverController dismissPopoverAnimated:YES];
        self.popSegue = nil;
        [self colorize];
    }
}

#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    DLog(@"Clicked button at index %d", buttonIndex);
    if(buttonIndex == 0)
    {
        // Delete the managed object for the given index path
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:self.selectedCell]];
        
        // Save the context.
        NSError *error = nil;
        if (![context save:&error]) {
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

@end
