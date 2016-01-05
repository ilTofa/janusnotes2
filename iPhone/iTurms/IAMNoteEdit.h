//
//  IAMTextNoteEdit.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <UIKit/UIKit.h>

#import "Note.h"

@interface IAMNoteEdit : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *titleEdit;
@property (weak, nonatomic) IBOutlet UITextView *textEdit;
@property (weak, nonatomic) IBOutlet UIImageView *greyRowImage;
@property (weak, nonatomic) IBOutlet UIImageView *attachmentsGreyRow;
@property (weak, nonatomic) IBOutlet UIToolbar *theToolbar;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *addImageButton;
@property (nonatomic, weak) IBOutlet UIBarButtonItem *recordingButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *currentBookButton;

@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textToToolbarConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *attachmentGreyRowToToolbarConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *titleEditHeightConstraint;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *textEditSpaceToTopConstraint;

@property NSManagedObjectID *idForTheNoteToBeEdited;

- (IBAction)save:(id)sender;
- (IBAction)addImageToNote:(id)sender;
- (IBAction)recordAudio:(id)sender;

@end
