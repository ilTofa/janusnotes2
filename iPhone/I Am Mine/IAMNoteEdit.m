//
//  IAMTextNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteEdit.h"

#import <MobileCoreServices/MobileCoreServices.h>

#import "IAMAppDelegate.h"
#import "UIFont+GTFontMapper.h"
#import "UIViewController+GTFrames.h"
#import "Attachment.h"

@interface IAMNoteEdit () <UITextViewDelegate, UIActionSheetDelegate, UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property IAMAppDelegate *appDelegate;
@property CGRect oldFrame;
@property UIBarButtonItem *doneButton;
@property UIBarButtonItem *saveButton;

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
    self.appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    // Keyboard notifications
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    // Right button(s)
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save:)];
    self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    NSArray *rightButtons = @[self.saveButton, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareAction:)]];
    self.navigationItem.rightBarButtonItems = rightButtons;
    // Preset the note
    self.titleEdit.text = self.editedNote.title;
    self.titleEdit.font = [UIFont gt_getStandardFontWithFaceID:[UIFont gt_getStandardFontFaceIdFromUserDefault] andSize:[UIFont gt_getStandardFontSizeFromUserDefault]+3];
    self.textEdit.attributedText = self.editedNote.attributedText;
    self.textEdit.font = [UIFont gt_getStandardFontFromUserDefault];
    self.titleEdit.textColor = self.textEdit.textColor = self.appDelegate.textColor;
    self.view.backgroundColor = self.appDelegate.backgroundColor;
    [self attachmentsInterfaceSetup];
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

-(void)attachmentsInterfaceSetup
{
    // Set attachment quantity
    self.attachmentQuantityLabel.text = [NSString stringWithFormat:NSLocalizedString(@"Files: %lu", nil), [self.editedNote.attachment count]];
    self.viewButton.enabled = (self.attachmentQuantityLabel != 0);
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
        self.navigationItem.rightBarButtonItems = nil;
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
        NSArray *rightButtons = @[self.saveButton, [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(shareAction:)]];
        self.navigationItem.rightBarButtonItems = rightButtons;
    }
}


// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    DLog(@"This is keyboardWasShown:");
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
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", nil) message:NSLocalizedString(@"No images available on this device", nil) delegate:nil cancelButtonTitle:nil otherButtonTitles:nil];
        [alert show];
        [self.addImageButton setEnabled:NO];
    }
}

- (IBAction)addLinkToNote:(id)sender {
}

- (IBAction)viewAttachments:(id)sender {
}

#pragma mark UIActionSheetDelegate

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
    [self presentViewController:imagePicker animated:YES completion:^{}];
}

#pragma mark UIImagePickerControllerDelegate

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
        [picker dismissViewControllerAnimated:YES completion:^{}];
        // Now add attachment...
        Attachment *newAttachment = [NSEntityDescription insertNewObjectForEntityForName:@"Attachment" inManagedObjectContext:self.moc];
        newAttachment.uti = (__bridge NSString *)(kUTTypeImage);
        newAttachment.extension = (__bridge_transfer NSString *)UTTypeCopyPreferredTagWithClass(kUTTypeImage, kUTTagClassFilenameExtension);
        if(!newAttachment.extension)
            newAttachment.extension = @"png";
        newAttachment.filename = @"";
        newAttachment.type = @"Image";
        newAttachment.data = UIImagePNGRepresentation(pickedImage);
        // Now link attachment to the note
        newAttachment.note = self.editedNote;
        [self.editedNote addAttachmentObject:newAttachment];
        [self attachmentsInterfaceSetup];
        // Don't save now... the moc will be saved on exit.
    }
	else
	{
		// user don't want to do something, dismiss
        [picker dismissViewControllerAnimated:YES completion:^{}];
	}
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker
{
    [picker dismissViewControllerAnimated:YES completion:^{}];
}

- (IBAction)shareAction:(id)sender
{
    // Save (but not return)
    [self save:nil];
    NSMutableArray *activityItems = [[NSMutableArray alloc] initWithObjects:self.editedNote.title, self.editedNote.attributedText, nil];
//    if(self.editedNote.image)
//    {
//        UIImage *imageToAdd = [UIImage imageWithData:self.editedNote.image];
//        if(imageToAdd)
//            [activityItems addObject:imageToAdd];
//    }
//    if(self.editedNote.link)
//    {
//        NSURL *linkToAdd = [NSURL URLWithString:self.editedNote.link];
//        if(linkToAdd)
//            [activityItems addObject:linkToAdd];
//    }
    UIActivityViewController *activityVC = [[UIActivityViewController alloc] initWithActivityItems:activityItems applicationActivities:nil];
    activityVC.excludedActivityTypes = @[UIActivityTypeSaveToCameraRoll, UIActivityTypeAssignToContact, UIActivityTypePrint, UIActivityTypePostToWeibo];
    [self presentViewController:activityVC animated:TRUE completion:nil];
}

@end
