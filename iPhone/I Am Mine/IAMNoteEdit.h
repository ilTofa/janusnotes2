//
//  IAMNoteEdit.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "Note.h"

@interface IAMNoteEdit : UIViewController

@property (weak, nonatomic) IBOutlet UITextField *titleEdit;
@property (weak, nonatomic) IBOutlet UITextField *linkEdit;
@property (weak, nonatomic) IBOutlet UITextView *textEdit;

// The edited note and the corresponding moc
@property Note *editedNote;
@property NSManagedObjectContext *moc;

- (IBAction)done:(id)sender;

@end
