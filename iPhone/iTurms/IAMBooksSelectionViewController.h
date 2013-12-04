//
//  IAMBooksSelectionViewController.h
//  iTurms
//
//  Created by Giacomo Tufano on 04/12/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

#define kBookSelectionPopoverCanBeDismissed @"BookSelectionPopoverCanBeDismissed"

@class IAMBooksSelectionViewController;

@protocol IAMBooksSelectionViewControllerDelegate <NSObject>
- (void)booksSelectionController:(IAMBooksSelectionViewController *)controller didSelectBooks:(NSArray *)booksArray;
@end

@interface IAMBooksSelectionViewController : UITableViewController

@property (weak) id<IAMBooksSelectionViewControllerDelegate> delegate;
@property NSArray *selectedBooks;

@end
