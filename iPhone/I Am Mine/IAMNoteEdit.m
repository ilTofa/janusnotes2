//
//  IAMTextNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEdit.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import "UIViewController+GTFrames.h"
#import "Attachment.h"
#import "IAMAddLinkViewController.h"
#import "IAMAttachmentCell.h"
#import "IAMAttachmentDetailViewController.h"
#import "MicrophoneWindow.h"
#import "GTThemer.h"
#import "UIImage+FixOrientation.h"

@interface IAMNoteEdit () <UITextViewDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate, IAMAddLinkViewControllerDelegate, UICollectionViewDataSource, UICollectionViewDelegate, AttachmentDeleter, MicrophoneWindowDelegate>

@property CGRect oldFrame;
@property UIBarButtonItem *doneButton;
@property UIBarButtonItem *saveButton;

@property NSArray *attachmentsArray;

@property(nonatomic, weak) IBOutlet UICollectionView *collectionView;

@property (strong, nonatomic) MicrophoneWindow *recordView;

@property BOOL attachmensAreHidden;

@property UIPopoverController *popover;

@end

@implementation IAMNoteEdit

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
    // Keyboard notifications (iPhone only)
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    }
    // Right button(s)
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save:)];
    self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    self.navigationItem.rightBarButtonItem = self.saveButton;
    // Preset the note
    [[GTThemer sharedInstance] applyColorsToView:self.titleEdit];
    self.titleEdit.text = self.editedNote.title;
    self.textEdit.attributedText = self.editedNote.attributedText;
    [[GTThemer sharedInstance] applyColorsToView:self.textEdit];
    [[GTThemer sharedInstance] applyColorsToView:self.view];
    [[GTThemer sharedInstance] applyColorsToView:self.collectionView];
    [[GTThemer sharedInstance] applyColorsToView:self.theToolbar];
    self.attachmensAreHidden = NO;
    [self refreshAttachments];
    // If this is a new note, set the cursor on title field
    if([self.titleEdit.text isEqualToString:@""])
        [self.titleEdit becomeFirstResponder];
}

-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

-(void)refreshAttachments
{
    // Set attachment quantity
    self.attachmentQuantityLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Files: %lu", nil), [self.editedNote.attachment count]];
    self.attachmentsArray = [self.editedNote.attachment allObjects];
    if([self.attachmentsArray count] == 0 && !self.attachmensAreHidden) {
        DLog(@"No attachments. Hiding collection view");
        [UIView animateWithDuration:0.5
                         animations:^{
                             CGRect textRect = self.textEdit.frame;
                             textRect.size.height += self.collectionView.frame.size.height;
                             self.textEdit.frame = textRect;
                             self.collectionView.alpha = self.attachmentsGreyRow.alpha = 0.0;
                         }
                         completion:^(BOOL finished){
                             self.collectionView.hidden = self.attachmentsGreyRow.hidden = YES;
                             self.attachmensAreHidden = YES;
                         }];
    }
    if([self.attachmentsArray count] != 0 && self.attachmensAreHidden){
        DLog(@"Attachments found. Showing collection view");
        self.collectionView.hidden = self.attachmentsGreyRow.hidden = NO;
        [UIView animateWithDuration:0.5
                         animations:^{
                             CGRect textRect = self.textEdit.frame;
                             textRect.size.height -= self.collectionView.frame.size.height;
                             self.textEdit.frame = textRect;
                             self.collectionView.alpha = self.attachmentsGreyRow.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                             self.attachmensAreHidden = NO;
                         }];
    }
    [self.collectionView reloadData];
}

#pragma mark - UiTextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    // Maximize edit view and change button.
    if(textView == self.textEdit)
    {
        DLog(@"This is textViewDidBeginEditing: for the main text editor");
        self.oldFrame = textView.frame;
        [UIView animateWithDuration:0.2 animations:^{
            [textView setFrame:[self gt_maximumUsableFrame]];
            self.greyRowImage.alpha = self.titleEdit.alpha = 0.0;
        }
                         completion:^(BOOL finished){
                             self.greyRowImage.hidden = self.titleEdit.hidden = YES;
                         }];
        self.navigationItem.rightBarButtonItem = self.doneButton;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    // Resize back the view.
    if(textView == self.textEdit)
    {
        DLog(@"This is textViewDidEndEditing: for the main text editor");
        self.greyRowImage.hidden = self.titleEdit.hidden = NO;
        [UIView animateWithDuration:0.2 animations:^{
            [textView setFrame:self.oldFrame];
            self.greyRowImage.alpha = self.titleEdit.alpha = 1.0;
        }];
        self.navigationItem.rightBarButtonItem = self.saveButton;
    }
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [info[UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height, 0.0);
    self.textEdit.contentInset = contentInsets;
    self.textEdit.scrollIndicatorInsets = contentInsets;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    self.textEdit.contentInset = contentInsets;
    self.textEdit.scrollIndicatorInsets = contentInsets;
}

- (IBAction)done:(id)sender
{
    [self.textEdit resignFirstResponder];
}

- (IBAction)save:(id)sender
{
    // save (if useful) and pop back
    if([self.titleEdit.text isEqualToString:@""] || [self.textEdit.text isEqualToString:@""])
        return;
    self.editedNote.title = self.titleEdit.text;
    self.editedNote.attributedText = self.textEdit.attributedText;
    self.editedNote.text = self.textEdit.attributedText.string;
    NSError *error;
    if(![self.moc save:&error])
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    // If called via action
    if(sender)
        [self.navigationController popToRootViewControllerAnimated:YES];
}

- (IBAction)addImageToNote:(id)sender
{
    // Check what the client have.
    BOOL library = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary];
    BOOL camera = [UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera];
    if(library && camera) {
        // Let the user choose
        UIActionSheet *chooseIt = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"New Attachment", nil)
                                                              delegate:self
                                                     cancelButtonTitle:NSLocalizedString(@"Cancel", nil)
                                                destructiveButtonTitle:nil
                                                     otherButtonTitles:NSLocalizedString(@"Image from Library", nil), NSLocalizedString(@"Image from Camera", nil), nil];
        [chooseIt showInView:self.view];
    } else if (camera) {
        [self showMediaPickerFor:UIImagePickerControllerSourceTypeCamera];
    } else if (library) {
        [self showMediaPickerFor:UIImagePickerControllerSourceTypePhotoLibrary];
    } else {
        // If no images available, tell user and disable button...
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No images available on this device", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
        [self.addImageButton setEnabled:NO];
    }
}

#pragma mark - UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    DLog(@"Clicked button at index %d", buttonIndex);
    if (buttonIndex == 0) {
        DLog(@"Library requested");
        [self showMediaPickerFor:UIImagePickerControllerSourceTypePhotoLibrary];
    } else if (buttonIndex == 1) {
        DLog(@"Camera requested");
        [self showMediaPickerFor:UIImagePickerControllerSourceTypeCamera];
    } else {
        DLog(@"Cancel selected");
    }
}

-(void)showMediaPickerFor:(UIImagePickerControllerSourceType)type
{
	UIImagePickerController *imagePicker = [[UIImagePickerController alloc] init];
	imagePicker.delegate = self;
	imagePicker.sourceType = type;
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone || type == UIImagePickerControllerSourceTypeCamera)
        [self presentViewController:imagePicker animated:YES completion:^{}];
    else
    {
         self.popover = [[UIPopoverController alloc] initWithContentViewController:imagePicker];
        [self.popover presentPopoverFromBarButtonItem:self.addImageButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
    }
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info
{
	// MediaType can be kUTTypeImage or kUTTypeMovie. If it's a movie then you
    // can get the URL to the actual file itself. This example only looks for images.
    NSLog(@"info: %@", info);
    NSString* mediaType = info[UIImagePickerControllerMediaType];
    // Try getting the edited image first. If it doesn't exist then you get the
    // original image.
    //
    if (CFStringCompare((CFStringRef) mediaType, kUTTypeImage, 0) == kCFCompareEqualTo)
	{
        UIImage *pickedImage = info[UIImagePickerControllerEditedImage];
        if (!pickedImage)
			pickedImage = info[UIImagePickerControllerOriginalImage];
        // Fix orientation
        pickedImage = [pickedImage normalizedImage];
        // Now add attachment...
        Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.moc];
        newAttachment.uti = (__bridge NSString *)(kUTTypeImage);
        newAttachment.extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(kUTTypeImage, kUTTagClassFilenameExtension);
        if(!newAttachment.extension)
            newAttachment.extension = @"png";
        newAttachment.filename = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], newAttachment.extension];
        newAttachment.type = @"Image";
        newAttachment.data = UIImagePNGRepresentation(pickedImage);
        // Now link attachment to the note
        newAttachment.note = self.editedNote;
        [self.editedNote addAttachmentObject:newAttachment];
        [self refreshAttachments];
        // Don't save now... the moc will be saved on exit.
    }
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [picker dismissViewControllerAnimated:YES completion:^{}];
    else
        [self.popover dismissPopoverAnimated:YES];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        [picker dismissViewControllerAnimated:YES completion:^{}];
    else
        [self.popover dismissPopoverAnimated:YES];
}

- (IBAction)shareAction:(id)sender
{
    // Save (but not return)
    [self save:nil];
    NSMutableArray *activityItems = [[NSMutableArray alloc] initWithObjects:self.editedNote.title, self.editedNote.attributedText, nil];
    // loop on the attachments...
    for (Attachment *attachment in self.editedNote.attachment) {
        if([attachment.type isEqualToString:@"Link"]) {
            NSURL *linkToAdd = [NSURL URLWithString:[[NSString alloc] initWithData:attachment.data encoding:NSUTF8StringEncoding]];
            if(linkToAdd)
                [activityItems addObject:linkToAdd];
        } else if([attachment.type isEqualToString:@"Image"]) {
            UIImage *imageToAdd = [[UIImage alloc] initWithData:attachment.data];
            if(imageToAdd)
                [activityItems addObject:imageToAdd];
        }
    }
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll, UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypePostToWeibo];
    [self presentViewController:activityVC animated:TRUE completion:nil];
}

#pragma mark - IAMAddLinkViewControllerDelegate

- (void)addLinkViewController:(IAMAddLinkViewController *)addLinkViewController didAddThisLink:(NSString *)theLink {
    // Now add attachment...
    DLog(@"This is addLinkViewController: didAddThisLink: for '%@'", theLink);
    Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.moc];
    newAttachment.uti = (__bridge NSString *)(kUTTypeURL);
    newAttachment.extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(kUTTypeURL, kUTTagClassFilenameExtension);
    if(!newAttachment.extension)
        newAttachment.extension = @"url";
    newAttachment.filename = [NSString stringWithFormat:@"%@.%@", [[NSUUID UUID] UUIDString], newAttachment.extension];
    newAttachment.type = @"Link";
    newAttachment.data = [theLink dataUsingEncoding:NSUTF8StringEncoding];
    // Now link attachment to the note
    newAttachment.note = self.editedNote;
    [self.editedNote addAttachmentObject:newAttachment];
    [self refreshAttachments];
}

- (void)addLinkViewControllerDidCancelAction:(IAMAddLinkViewController *)addLinkViewController {
    DLog(@"This is addLinkViewControllerDidCancelAction:");
}

#pragma mark - AttachmentDeleter

-(void)deleteAttachment:(Attachment *)toBeDeleted
{
    [self.editedNote removeAttachmentObject:toBeDeleted];
    [self save:nil];
    [self refreshAttachments];
}

#pragma mark - Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([[segue identifier] isEqualToString:@"AddLink"])
    {
        IAMAddLinkViewController *segueController = [segue destinationViewController];
        segueController.delegate = self;
    }
    if ([[segue identifier] isEqualToString:@"AttachmentDetail"]) {
        IAMAttachmentDetailViewController *segueController = [segue destinationViewController];
        NSArray *indexPaths = [self.collectionView indexPathsForSelectedItems];
        NSIndexPath *index = [indexPaths objectAtIndex:0];
        DLog(@"Opening the detail for cell %d", index.row);
        Attachment *attachment = self.attachmentsArray[index.row];
        segueController.theAttachment = attachment;
        segueController.deleterObject = self;
    }
}

#pragma mark - UICollectionViewDataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    NSInteger retValue = [self.editedNote.attachment count];
    DLog(@"This is collectionView:numberOfItemsInSection: called for section %d, returning %d", section, retValue);
    return retValue;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    IAMAttachmentCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"AttachmentCell" forIndexPath:indexPath];
    Attachment *attachment = self.attachmentsArray[indexPath.row];
    cell.cellLabelView.text = attachment.type;
    if([attachment.type isEqualToString:@"Link"]) {
        cell.cellImageView.image = [UIImage imageNamed:@"link-icon-big"];
    } else if([attachment.type isEqualToString:@"Image"]) {
        cell.cellImageView.image = [[UIImage alloc] initWithData:attachment.data];
    } else {
        cell.cellImageView.image = [UIImage imageNamed:@"link-unknown-big"];
    }
    return cell;
}

#pragma mark - UICollectionViewDelegate

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    DLog(@"This is collectionView:didSelectItemAtIndexPath:%d", indexPath.row);
    [self performSegueWithIdentifier:@"AttachmentDetail" sender:nil];
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
    DLog(@"This is collectionView:didDeselectItemAtIndexPath:%d", indexPath.row);
}

#pragma mark - UICollectionViewDelegateFlowLayout

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout*)collectionViewLayout sizeForItemAtIndexPath:(NSIndexPath *)indexPath {
    return CGSizeMake(100, 100);
}

#pragma mark - AudioRecording Management

-(void)recordingOK:(NSString *)recordingFilename
{
	DLog(@"Received a record on %@", recordingFilename);
	// Now get rid of the view
	[self recordingCancelled];
    Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.moc];
    NSURL *url = [NSURL fileURLWithPath:recordingFilename];
    newAttachment.uti = (__bridge NSString *)(kUTTypeAudio);
    newAttachment.extension = [url pathExtension];
    newAttachment.filename = [url lastPathComponent];
    newAttachment.data = [NSData dataWithContentsOfURL:url];
    newAttachment.type = @"Audio";
    // Now link attachment to the note
    newAttachment.note = self.editedNote;
    [self.editedNote addAttachmentObject:newAttachment];
    [self refreshAttachments];
    // Don't save now... the moc will be saved on exit.
}

- (void)recordingCancelled
{
	if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
		[self.recordView.view removeFromSuperview];
	else
		[self.popover dismissPopoverAnimated:YES];
	self.recordView = nil;
	self.recordView = nil;
}

- (IBAction)recordAudio:(id)sender
{
	NSLog(@"This is voiceMail: handler");
	// Check for audio... (only on actual device)
	if(![[AVAudioSession sharedInstance] inputIsAvailable])
	{
		UIAlertView *theAlert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
                                                           message:NSLocalizedString(@"No audio input available", @"")
                                                          delegate:nil
                                                 cancelButtonTitle:@"OK"
                                                 otherButtonTitles:nil];
		[theAlert show];
		return;
	}
	if(self.recordView == nil)
	{
		if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
			self.recordView = [[MicrophoneWindow alloc] initWithNibName:@"MicrophoneWindow-iPad" bundle:nil];
		else
			self.recordView = [[MicrophoneWindow alloc] initWithNibName:@"MicrophoneWindow" bundle:nil];
		self.recordView.delegate = self;
		if (UI_USER_INTERFACE_IDIOM() != UIUserInterfaceIdiomPad)
			[self.view addSubview:self.recordView.view];
	}
	if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
	{
		UIPopoverController* aPopover = [[UIPopoverController alloc]
										 initWithContentViewController:self.recordView];
		aPopover.popoverContentSize = CGSizeMake(220.0, 300.0);
		
		// Store the popover in a custom property for later use.
		self.popover = aPopover;
		[self.popover presentPopoverFromBarButtonItem:self.recordingButton permittedArrowDirections:UIPopoverArrowDirectionAny animated:YES];
	}
}

@end
