//
//  IAMTextNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMTextNoteEdit.h"

@interface IAMTextNoteEdit ()

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
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWasShown:) name:UIKeyboardDidShowNotification object:nil];    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillBeHidden:) name:UIKeyboardWillHideNotification object:nil];
    self.titleEdit.text = self.editedNote.title;
    self.textEdit.text = self.editedNote.text;
    [self.titleEdit becomeFirstResponder];
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
    // save and pop back
    self.editedNote.modified = [NSDate date];
    self.editedNote.title = self.titleEdit.text;
    DLog(@"Text: %@\nAttributed text: %@", self.textEdit.text, self.textEdit.attributedText);
    self.editedNote.text = self.textEdit.text;
    NSError *error;
    if(![self.moc save:&error])
    {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
