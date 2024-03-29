//
//  IAMAddBookViewController.m
//  Janus Notes
//
//  Created by Giacomo Tufano on 05/12/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import "IAMAddBookViewController.h"

#import "IAMAppDelegate.h"
#import "Books.h"

@interface IAMAddBookViewController ()

@property (weak, nonatomic) IBOutlet UITextField *bookNameField;

- (IBAction)cancelAction:(id)sender;
- (IBAction)saveAction:(id)sender;

@end

@implementation IAMAddBookViewController

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
    [self.bookNameField becomeFirstResponder];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)textFieldShouldReturn:(UITextField *)aTextfield {
    [self saveAction:self];
    return YES;
}

- (IBAction)cancelAction:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)saveAction:(id)sender {
    DLog(@"Now saving book: '%@'.", self.bookNameField.text);
    NSManagedObjectContext *moc = ((IAMAppDelegate *)[[UIApplication sharedApplication] delegate]).managedObjectContext;
    NSError *error;
    Books *newBook = [NSEntityDescription insertNewObjectForEntityForName:@"Books" inManagedObjectContext:moc];
    newBook.name = self.bookNameField.text;
    if (![moc save:&error]) {
        ALog(@"Unresolved error saving book %@, %@", error, [error userInfo]);
        NSString *errorMessage = [NSString stringWithFormat:@"Unresolved error saving book %@", error];
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error" message:errorMessage preferredStyle:UIAlertControllerStyleAlert];
        UIAlertAction *okButton = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) { }];
        [alert addAction:okButton];
        [self presentViewController:alert animated:YES completion:nil];
    } else {
        [self dismissViewControllerAnimated:YES completion:nil];
    }
}
@end
