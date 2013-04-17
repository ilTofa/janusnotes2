//
//  IAMViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 18/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMViewController.h"

#import "IAMAppDelegate.h"
#import "IAMNoteCell.h"
#import "Note.h"
#import "IAMNoteEdit.h"
#import "NSDate+PassedTime.h"
#import "GTThemer.h"
#import "IAMDataSyncController.h"
#import "MBProgressHUD.h"

@interface IAMViewController () <UISearchBarDelegate, NSFetchedResultsControllerDelegate>

@property (nonatomic) NSDateFormatter *dateFormatter;
@property MBProgressHUD *hud;

@property (atomic) BOOL dropboxSyncronizedSomething;
@property (atomic) NSDate *lastDropboxSync;

@property NSTimer *syncStatusTimer;

@property IAMAppDelegate *appDelegate;

@end

@implementation IAMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.dropboxSyncronizedSomething = YES;
    [self loadPreviousSearchKeys];
    // Set some sane defaults
    self.appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = self.appDelegate.coreDataController.mainThreadContext;
    self.dateFormatter = [[NSDateFormatter alloc] init];
	[self.dateFormatter setLocale:[NSLocale currentLocale]];
	[self.dateFormatter setDateStyle:NSDateFormatterMediumStyle];
	[self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    [self.dateFormatter setDoesRelativeDateFormatting:YES];
    NSArray *leftButtons = @[self.editButtonItem,
                             [[UIBarButtonItem alloc] initWithTitle:@"Prefs" style:UIBarButtonItemStylePlain target:self action:@selector(launchPreferences:)]];
    self.navigationItem.leftBarButtonItems = leftButtons;
    // Notifications to be honored during controller lifecycle
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFetchedResults:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:self.appDelegate.coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFetchedResults:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:self.appDelegate.coreDataController.psc];
    NSManagedObjectContext *syncMOC = [IAMDataSyncController sharedInstance].dataSyncThreadContext;
    NSAssert(syncMOC, @"The Managed Object Context for the Sync Engine is still not set while setting main view.");
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(mergeSyncChanges:) name:NSManagedObjectContextDidSaveNotification object:syncMOC];
    if([IAMDataSyncController sharedInstance].syncControllerReady)
        [self refreshControlSetup];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreNotificationHandler:) name:kIAMDataSyncControllerReady object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(syncStoreNotificationHandler:) name:kIAMDataSyncControllerStopped object:nil];
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
    [self colorize];
    // if the dropbox backend have an user, but is not ready (that means it's waiting on something)
    if([IAMDataSyncController sharedInstance].syncControllerInited && ![IAMDataSyncController sharedInstance].syncControllerReady) {
        self.hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        self.hud.labelText = NSLocalizedString(@"Waiting for Dropbox", nil);
        self.hud.detailsLabelText = NSLocalizedString(@"First sync in progress, please wait.", nil);
    }
}

-(void)colorize
{
    [[GTThemer sharedInstance] applyColorsToView:self.tableView];
    [[GTThemer sharedInstance] applyColorsToView:self.navigationController.navigationBar];
    [self.navigationController.navigationBar setBarStyle:UIBarStyleBlackTranslucent];
    [[GTThemer sharedInstance] applyColorsToView:self.searchBar];
    [self.tableView reloadData];
}

- (void)refreshControlSetup {
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:NSLocalizedString(@"Dropbox refresh", nil)];
    [refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refreshControl;
    // Here we are sure there is an active dropbox link
    self.syncStatusTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(syncStatus:) userInfo:nil repeats:YES];
}

-(void)syncStatus:(NSTimer *)timer {
    
    DBSyncStatus status = [[DBFilesystem sharedFilesystem] status];
    NSMutableString *title = [[NSMutableString alloc] initWithString:@"Sync "];
    if(!status) {
        // If all is quiet and dropbox says it's fully synced (and it was not before), then reload (only if last reload were more than 45 seconds ago).
        [title appendString:@"✔"];
        if(self.dropboxSyncronizedSomething && [self.lastDropboxSync timeIntervalSinceNow] < -45.0) {
            DLog(@"Dropbox synced everything, time to reload! Last reload %.0f seconds ago", -[self.lastDropboxSync timeIntervalSinceNow]);
            self.dropboxSyncronizedSomething = NO;
            self.lastDropboxSync = [NSDate date];
            [[IAMDataSyncController sharedInstance] refreshContentFromRemote];
        }
    }
    if(status & DBSyncStatusOnline)
        [title appendString:@"📡"];
    if(status & DBSyncStatusSyncing)
        [title appendString:@"␖"];
    if(status & DBSyncStatusDownloading) {
        [title appendString:@"↓"];
        self.dropboxSyncronizedSomething = YES;
    }
    if(status & DBSyncStatusUploading)
        [title appendString:@"↑"];
    self.title = title;
}

-(void)refresh {
    [self.refreshControl beginRefreshing];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(endSyncNotificationHandler:) name:kIAMDataSyncRefreshTerminated object:nil];
    [[IAMDataSyncController sharedInstance] refreshContentFromRemote];
}

- (void)syncStoreNotificationHandler:(NSNotification *)note {
    IAMDataSyncController *controller = note.object;
    if(controller.syncControllerReady) {
        [self refreshControlSetup];
        self.lastDropboxSync = [NSDate date];
    }
    else {
        self.refreshControl = nil;
        if(self.syncStatusTimer) {
            [self.syncStatusTimer invalidate];
            self.syncStatusTimer = nil;
        }
    }
    if(self.hud) {
        [self.hud hide:YES];
        self.hud = nil;
    }
}

- (void)endSyncNotificationHandler:(NSNotification *)note {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kIAMDataSyncRefreshTerminated object:nil];
    [self.refreshControl endRefreshing];
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
    self.tableView.allowsSelection = NO;
    self.tableView.scrollEnabled = NO;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    self.tableView.allowsSelection = YES;
    self.tableView.scrollEnabled = YES;
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
    self.tableView.allowsSelection = YES;
    self.tableView.scrollEnabled = YES;
    // Perform search... :)
    [self setupFetchExecAndReload];
}

- (void)mergeSyncChanges:(NSNotification *)note {
    DLog(@"Merging data from sync Engine");
    [self.managedObjectContext mergeChangesFromContextDidSaveNotification:note];
    // Reset the moc, so we don't get changes back to the background moc.
    [self.managedObjectContext reset];
    [self setupFetchExecAndReload];
}

- (void)reloadFetchedResults:(NSNotification *)note {
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
                [self.tableView reloadData];
            }
        }
    });
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
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:@"timeStamp" ascending:NO];
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
    DLog(@"Fetching again. Query string is: '%@'", queryString);
    NSPredicate *predicate = [NSPredicate predicateWithFormat:queryString];
    [fetchRequest setPredicate:predicate];
    
    self.fetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest
                                                                        managedObjectContext:self.managedObjectContext
                                                                          sectionNameKeyPath:@"sectionIdentifier"
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
        else
            [self.tableView reloadData];
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
    [[GTThemer sharedInstance] applyColorsToLabel:cell.titleLabel withFontSize:17];
    cell.titleLabel.text = note.title;
    [[GTThemer sharedInstance] applyColorsToLabel:cell.noteTextLabel withFontSize:12];
    cell.noteTextLabel.text = note.text;
    [[GTThemer sharedInstance] applyColorsToLabel:cell.dateLabel withFontSize:10];
    cell.dateLabel.text = [self.dateFormatter stringFromDate:note.creationDate];
    [[GTThemer sharedInstance] applyColorsToLabel:cell.attachmentsQuantityLabel withFontSize:10];
    NSUInteger attachmentsQuantity = 0;
    if(note.attachment)
        attachmentsQuantity = [note.attachment count];
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
        // Delete the managed object for the given index path
        NSManagedObjectContext *context = [self.fetchedResultsController managedObjectContext];
        [context deleteObject:[self.fetchedResultsController objectAtIndexPath:indexPath]];
        
        // Save the context.
        NSError *error = nil;
        if (![context save:&error]) {
            /*
             Replace this implementation with code to handle the error appropriately.
             
             abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development. If it is not possible to recover from the error, display an alert panel that instructs the user to quit the application by pressing the Home button.
             */
            NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
            abort();
        }
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	
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
        Note *selectedNote =  [[self fetchedResultsController] objectAtIndexPath:self.tableView.indexPathForSelectedRow];
        selectedNote.timeStamp = [NSDate date];
        noteEditor.editedNote = selectedNote;
        noteEditor.moc = self.managedObjectContext;
    }
}

- (IBAction)launchPreferences:(id)sender
{
    [self performSegueWithIdentifier:@"Preferences" sender:self];
}

@end
