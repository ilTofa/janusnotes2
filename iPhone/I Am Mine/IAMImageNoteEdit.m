//
//  IAMImageNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 23/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMImageNoteEdit.h"

#import "IAMAppDelegate.h"
#import "UIFont+GTFontMapper.h"

@interface IAMImageNoteEdit ()

@property IAMAppDelegate *appDelegate;

@end

@implementation IAMImageNoteEdit

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
    self.titleEdit.text = self.editedNote.title;
    self.titleEdit.font = [UIFont gt_getStandardFontWithFaceID:[UIFont gt_getStandardFontFaceIdFromUserDefault] andSize:[UIFont gt_getStandardFontSizeFromUserDefault]+3];
    self.textEdit.attributedText = self.editedNote.attributedText;
    self.textEdit.font = [UIFont gt_getStandardFontFromUserDefault];
    self.imageThumbnail.image = [UIImage imageWithData:self.editedNote.image];
    self.titleEdit.textColor = self.textEdit.textColor = self.appDelegate.textColor;
    self.view.backgroundColor = self.appDelegate.backgroundColor;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)done:(id)sender
{
    // save (if useful) and pop back
    if([self.titleEdit.text isEqualToString:@""])
        return;
    self.editedNote.title = self.titleEdit.text;
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
