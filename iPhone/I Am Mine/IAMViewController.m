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

@interface IAMViewController () <UIActionSheetDelegate, UIImagePickerControllerDelegate>

@property (nonatomic) NSDateFormatter *dateFormatter;

@property int textSelector, cameraSelector, librarySelector, savedAlbumsSelector;

@end

@implementation IAMViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self loadPreviousSearchKeys];
    // Set some sane defaults
    IAMAppDelegate *appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    self.managedObjectContext = appDelegate.coreDataController.mainThreadContext;
    self.dateFormatter = [[NSDateFormatter alloc] init];
	[self.dateFormatter setLocale:[NSLocale currentLocale]];
	[self.dateFormatter setDateStyle:NSDateFormatterLongStyle];
	[self.dateFormatter setTimeStyle:NSDateFormatterShortStyle];
    // Notifications to be honored during controller lifecycle
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFetchedResults:) name:NSPersistentStoreCoordinatorStoresDidChangeNotification object:appDelegate.coreDataController.psc];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadFetchedResults:) name:NSPersistentStoreDidImportUbiquitousContentChangesNotification object:appDelegate.coreDataController.psc];
    [self setupFetchExecAndReload];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated
{
    DLog(@"This is IAMViewController:viewDidAppear:");
    [super viewDidAppear:animated];
    [self.managedObjectContext rollback];
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
    self.tableView.allowsSelection = NO;
    self.tableView.scrollEnabled = NO;
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    DLog(@"Cancel clicked");
    [searchBar setShowsCancelButton:NO animated:YES];
    [searchBar resignFirstResponder];
    self.tableView.allowsSelection = YES;
    self.tableView.scrollEnabled = YES;
    searchBar.text = self.searchText = @"";
    [self setupFetchExecAndReload];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar
{
    DLog(@"Search should start for '%@'", searchBar.text);
    [searchBar resignFirstResponder];
    self.searchText = searchBar.text;
    self.tableView.allowsSelection = YES;
    self.tableView.scrollEnabled = YES;
    // Perform search... :)
    DLog(@"Now searching %@", self.searchText);
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
                [self.tableView reloadData];
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
    NSSortDescriptor *dateAddedSortDesc = [[NSSortDescriptor alloc] initWithKey:@"modified" ascending:YES];
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
                                                                          sectionNameKeyPath:nil
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
            [self.tableView reloadData];
    }
    [self saveSearchKeys];
}

#pragma mark -
#pragma mark Fetched results controller delegate

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    DLog(@"this is controllerWillChangeContent");
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    DLog(@"This is controller didChangeObject:atIndexPath:forChangeType:newIndexPath:");
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:(IAMNoteCell *)[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath]withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    DLog(@"This is controllerDidChangeContent:");
    [self.tableView endUpdates];
}


#pragma mark -
#pragma mark - Table view data source

- (void)configureCell:(IAMNoteCell *)cell atIndexPath:(NSIndexPath *)indexPath
{
    Note *note = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.titleLabel.text = note.title;
    cell.textLabel.text = note.text;
    cell.dateLabel.text = [self.dateFormatter stringFromDate:note.created];
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
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [[self.fetchedResultsController fetchedObjects] count];
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

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    DLog(@"This is tableView:didSelectRowAtIndexPath: called for row %d", indexPath.row);
}

#pragma mark Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"AddTextNote"])
    {
        IAMNoteEdit *textNoteEditor = [segue destinationViewController];
        // Create a new note
        IAMAppDelegate *appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
        Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.coreDataController.mainThreadContext];
        newNote.text = @"";
        newNote.title = @"";
        newNote.link = @"";
        newNote.uuid = [[NSUUID UUID] UUIDString];
        newNote.created = [NSDate date];
        newNote.modified = [NSDate date];
        textNoteEditor.editedNote = newNote;
        textNoteEditor.moc = appDelegate.coreDataController.mainThreadContext;
    }
    if ([[segue identifier] isEqualToString:@"EditNote"])
    {
        IAMNoteEdit *textNoteEditor = [segue destinationViewController];
        Note *selectedNote =  [[self fetchedResultsController] objectAtIndexPath:self.tableView.indexPathForSelectedRow];
        selectedNote.modified = [NSDate date];
        textNoteEditor.editedNote = selectedNote;
        textNoteEditor.moc = self.managedObjectContext;
    }
}

// DEBUG: add type of note management here (image, photo, text)
- (IBAction)addNote:(id)sender
{
    // Check what the client have.
    BOOL library = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    BOOL camera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    BOOL savedAlbums = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeSavedPhotosAlbum];
    NSString *b1, *b2, *b3;
    if(library) {
        b1 = @"Image from Library";
        self.librarySelector = 1;
        if(camera) {
            b2 = @"Image from Camera";
            self.cameraSelector = 2;
            if(savedAlbums) {
                b3 = @"Image from saved Albums";
                self.savedAlbumsSelector = 3;
            }
        } else if (savedAlbums) {
            b2 = @"Image from saved albums";
            self.savedAlbumsSelector = 2;
        }
    } else if(camera) {
        b1 = @"Image from Camera";
        self.cameraSelector = 1;
        if(savedAlbums) {
            b2 = @"Image from saved Albums";
            self.savedAlbumsSelector = 2;
        }
    } else if (savedAlbums) {
        b1 = @"Image from saved albums";
        self.savedAlbumsSelector = 1;
    } else {
        // If no images go with text note
        [self actionSheet:nil clickedButtonAtIndex:0];
    }
    UIActionSheet *chooseIt = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"New Note", nil)
                                                           delegate:self
                                                  cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:NSLocalizedString(@"Text", nil), b1, b2, b3, nil];
    [chooseIt showFromToolbar:self.navigationController.toolbar];
}

#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    DLog(@"Clicked button at index %d", buttonIndex);
    if(buttonIndex == 0) {
        DLog(@"Text requested");
        [self performSegueWithIdentifier:@"AddTextNote" sender:self];
    } else if (buttonIndex == self.librarySelector) {
        DLog(@"Library requested");
    } else if (buttonIndex == self.cameraSelector) {
        DLog(@"Camera requested");
    } else if (buttonIndex == self.savedAlbumsSelector) {
        DLog(@"Saved album selected");
    } else {
        DLog(@"Cancel selected");
    }
}

-(void)showMediaPickerFor:(UIImagePickerControllerSourceType)type
{
//	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
//	imagePicker.delegate = self;
//	imagePicker.sourceType = type;
//	[self presentModalViewController:imagePicker animated:YES];
}

#pragma mark UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
//	// MediaType can be kUTTypeImage or kUTTypeMovie. If it's a movie then you
//    // can get the URL to the actual file itself. This example only looks for images.
//    NSLog(@"info: %@", info);
//    NSString* mediaType = [info objectForKey:UIImagePickerControllerMediaType];
//    // NSString* videoUrl = [info objectForKey:UIImagePickerControllerMediaURL];
//	
//    // Try getting the edited image first. If it doesn't exist then you get the
//    // original image.
//    //
//    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo)
//	{
//        self.theImage = [info objectForKey:UIImagePickerControllerEditedImage];
//        if (!self.theImage)
//			self.theImage = [info objectForKey:UIImagePickerControllerOriginalImage];
//		[self dismissModalViewControllerAnimated:YES];
//		[self showImageSenderController];
//    }
//	else
//	{
//		// user don't want to do something, dismiss
//		[self dismissModalViewControllerAnimated:YES];
//		[self showImageSenderController];
//	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
//	[self dismissModalViewControllerAnimated:YES];
//	[self showImageSenderController];
}


@end
