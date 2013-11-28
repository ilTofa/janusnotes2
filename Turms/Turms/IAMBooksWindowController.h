//
//  IAMBooksWindowController.h
//  Turms
//
//  Created by Giacomo Tufano on 28/11/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMBooksWindowController : NSWindowController <NSTableViewDelegate, NSTableViewDataSource>

@property NSMutableArray *bookList;
@property NSTableView *tableView;

@end
