//
//  IAMDragDroppingCollectionView.h
//  Janus
//
//  Created by Giacomo Tufano on 25/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol IAMDragDroppingCollectionViewDelegate <NSObject>

-(void)fileDropped:(NSString *)fileName;

@end

@interface IAMDragDroppingCollectionView : NSCollectionView

@property id<IAMDragDroppingCollectionViewDelegate> droppingDelegate;

-(void)registerForDragAndDrop;

@end
