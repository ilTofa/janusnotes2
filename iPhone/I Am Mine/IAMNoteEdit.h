//
//  IAMTextNoteEdit.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Note.h"

@interface IAMNoteEdit : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *titleEdit;
@property (weak, nonatomic) IBOutlet UITextView *textEdit;
@property (weak, nonatomic) IBOutlet UIImageView *greyRowImage;

@property (weak, nonatomic) IBOutlet UIBarButtonItem *addImageButton;
@property (weak, nonatomic) IBOutlet UILabel *attachmentQuantityLabel;

// The edited note and the corresponding moc
@property Note *editedNote;
@property NSManagedObjectContext *moc;

- (IBAction)save:(id)sender;
- (IBAction)addImageToNote:(id)sender;

@end
