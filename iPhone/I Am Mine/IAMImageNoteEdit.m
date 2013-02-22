//
//  IAMImageNoteEdit.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 23/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMImageNoteEdit.h"

@interface IAMImageNoteEdit ()

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
    self.titleEdit.text = self.editedNote.title;
    self.textEdit.text = self.editedNote.text;
    self.imageThumbnail.image = [UIImage imageWithData:self.editedNote.image];
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
    self.editedNote.modified = [NSDate date];
    self.editedNote.title = self.titleEdit.text;
    self.editedNote.text = self.textEdit.text;
    NSError *error;
    if(![self.moc save:&error])
    {
        NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
    }
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
