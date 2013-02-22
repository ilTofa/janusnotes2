//
//  IAMNoteCell.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 20/02/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface IAMNoteCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *textLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;

@end
