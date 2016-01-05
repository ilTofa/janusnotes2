//
//  IAMAttachmentDetailViewController.h
//  I Am Mine
//
//  Created by Giacomo Tufano on 07/03/13.
//
//  Copyright (c)2013, Giacomo Tufano (gt@ilTofa.com)
//  Licensed under MIT license. See LICENSE file or http://www.opensource.org/licenses/mit-license.php
//

#import <UIKit/UIKit.h>

#import "Attachment.h"

@protocol AttachmentDeleter <NSObject>

-(void)deleteAttachment:(Attachment *)toBeDeleted;

@end

@interface IAMAttachmentDetailViewController : UIViewController

@property Attachment *theAttachment;
@property id<AttachmentDeleter> deleterObject;

@end
