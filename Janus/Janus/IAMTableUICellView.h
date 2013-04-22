//
//  IAMTableUICellView.h
//  Janus
//
//  Created by Giacomo Tufano on 22/04/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface IAMTableUICellView : NSTableCellView

@property (weak, nonatomic) IBOutlet NSTextField *noteTitle;
@property (weak, nonatomic) IBOutlet NSTextField *noteText;
@property (weak, nonatomic) IBOutlet NSTextField *noteAttachments;
@property (weak, nonatomic) IBOutlet NSTextField *noteDate;

@end
