//
//  IAMTextNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMTextNoteEdit.h"

#import "IAMAppDelegate.h"
#import "UIFont+GTFontMapper.h"
#import "UIViewController+GTFrames.h"

@interface IAMTextNoteEdit () <UITextViewDelegate>

@property IAMAppDelegate *appDelegate;
@property CGRect oldFrame;
@property UIBarButtonItem *doneButton;
@property UIBarButtonItem *saveButton;

@end

@implementation IAMTextNoteEdit

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    self.saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave target:self action:@selector(save:)];
    self.navigationItem.rightBarButtonItem = self.saveButton;
    self.doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(done:)];
    self.titleEdit.text = self.editedNote.title;
    self.titleEdit.font = [UIFont gt_getStandardFontWithFaceID:[UIFont gt_getStandardFontFaceIdFromUserDefault] andSize:[UIFont gt_getStandardFontSizeFromUserDefault]+3];
    self.textEdit.attributedText = self.editedNote.attributedText;
    self.textEdit.font = [UIFont gt_getStandardFontFromUserDefault];
    self.linkEdit.text = self.editedNote.link;
    self.linkEdit.font = [UIFont gt_getStandardFontWithFaceID:[UIFont gt_getStandardFontFaceIdFromUserDefault] andSize:[UIFont gt_getStandardFontSizeFromUserDefault]];
    self.titleEdit.textColor = self.linkEdit.textColor = self.textEdit.textColor = self.appDelegate.textColor;
    self.view.backgroundColor = self.appDelegate.backgroundColor;
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

#pragma mark - UiTextViewDelegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
    // Maximize edit view and change button.
    if(textView == self.textEdit)
    {
        DLog(@"This is textViewDidBeginEditing: for the main text editor");
        self.oldFrame = textView.frame;
        [textView setFrame:[self gt_maximumUsableFrame]];
        self.lowerDivider.hidden = self.upperDivider.hidden = self.titleEdit.hidden = self.linkEdit.hidden = YES;
        self.navigationItem.rightBarButtonItem = self.doneButton;
    }
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
    // Resize back the view.
    if(textView == self.textEdit)
    {
        DLog(@"This is textViewDidEndEditing: for the main text editor");
        [textView setFrame:self.oldFrame];
        self.lowerDivider.hidden = self.upperDivider.hidden = self.titleEdit.hidden = self.linkEdit.hidden = NO;
        self.navigationItem.rightBarButtonItem = self.saveButton;
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
    self.editedNote.link = self.linkEdit.text;
    DLog(@"Text: %@\nAttributed text: %@", self.textEdit.attributedText.string, self.textEdit.attributedText);
    self.editedNote.attributedText = self.textEdit.attributedText;
    self.editedNote.text = self.textEdit.attributedText.string;
    NSError *error;
    if(![self.moc save:&error])
    {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
