//
//  IAMBooksSelectionViewController.h
//  Janus Notes
//
//  Created by Giacomo Tufano on 04/12/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

@class IAMBooksSelectionViewController;

@protocol IAMBooksSelectionViewControllerDelegate <NSObject>
- (void)booksSelectionController:(IAMBooksSelectionViewController *)controller didSelectBooks:(NSArray *)booksArray;
@end

@interface IAMBooksSelectionViewController : UITableViewController

@property (weak) id<IAMBooksSelectionViewControllerDelegate> delegate;
@property NSArray *selectedBooks;

@property BOOL multiSelectionAllowed;

// If this one is not setup from the caller, it is setup from the main one.
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

- (IBAction)doneAction:(id)sender;

@end
