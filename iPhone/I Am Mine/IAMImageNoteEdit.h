//
//  IAMImageNoteEdit.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 23/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Note.h"

@interface IAMImageNoteEdit : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *titleEdit;
@property (weak, nonatomic) IBOutlet UIImageView *imageThumbnail;
@property (weak, nonatomic) IBOutlet UITextView *textEdit;

// The edited note and the corresponding moc
@property Note *editedNote;
@property NSManagedObjectContext *moc;

- (IBAction)done:(id)sender;

@end
