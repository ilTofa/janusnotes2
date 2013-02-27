//
//  IAMTextNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMTextNoteEdit.h"

#import "IAMAppDelegate.h"

@interface IAMTextNoteEdit ()

@property IAMAppDelegate *appDelegate;

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
    self.titleEdit.text = self.editedNote.title;
    self.textEdit.attributedText = self.editedNote.attributedText;
    self.linkEdit.text = self.editedNote.link;
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

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
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
    // save (if useful) and pop back
    if([self.titleEdit.text isEqualToString:@""] || [self.textEdit.text isEqualToString:@""])
        return;
    self.editedNote.modified = [NSDate date];
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
