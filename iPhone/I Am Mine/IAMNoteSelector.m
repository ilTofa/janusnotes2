//
//  IAMNoteSelector.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMNoteSelector.h"

#import "IAMAppDelegate.h"
#import "Note.h"

#import "IAMTextNoteEdit.h"
#import "IAMLinkNoteEdit.h"

@interface IAMNoteSelector ()

@end

@implementation IAMNoteSelector

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
 
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark Segues

-(void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Create a new note
    IAMAppDelegate *appDelegate = (IAMAppDelegate *)[[UIApplication sharedApplication] delegate];
    Note *newNote = [NSEntityDescription insertNewObjectForEntityForName:@"Note" inManagedObjectContext:appDelegate.coreDataController.mainThreadContext];
    newNote.text = @"";
    newNote.title = @"";
    newNote.link = @"";
    newNote.uuid = [[NSUUID UUID] UUIDString];
    newNote.created = [NSDate date];
    newNote.modified = [NSDate date];
    if ([[segue identifier] isEqualToString:@"AddTextNote"])
    {
        IAMTextNoteEdit *textNoteEditor = [segue destinationViewController];
        textNoteEditor.editedNote = newNote;
        textNoteEditor.moc = appDelegate.coreDataController.mainThreadContext;
    }
    if ([[segue identifier] isEqualToString:@"ADDLinkNote"])
    {
        IAMLinkNoteEdit *textNoteEditor = [segue destinationViewController];
        textNoteEditor.editedNote = newNote;
        textNoteEditor.moc = appDelegate.coreDataController.mainThreadContext;
    }
}

@end
