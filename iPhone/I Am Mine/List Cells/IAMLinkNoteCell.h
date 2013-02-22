//
//  IAMLinkNoteCell.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 22/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IAMLinkNoteCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *linkLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;

@end
