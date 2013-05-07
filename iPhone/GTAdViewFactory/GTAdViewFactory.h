//
//  GTAdViewFactory.h
//  radioz
//
//  Created by Giacomo Tufano on 25/09/12.
//
//

#import <UIKit/UIKit.h>

#import <iAd/iAd.h>
#import "GADBannerView.h"

@class GTAdViewFactory;

// After initing the Factory, delegate should only listen to notifications and
// and show and hide the container view on notification of success of failure.
// to kill the factory, simple set it to nil (remember to nil the delegate before!)
// AdMob views are to be considered auto-refreshed

@protocol GTAdViewDelegate <NSObject>

-(void)gtAdViewFactoryDidLoadAd:(GTAdViewFactory *)theFactory;
-(void)giAdViewFactoryIsVoid:(GTAdViewFactory *)theFactory;

@end

@interface GTAdViewFactory : NSObject

// The delegate to be notified
@property (nonatomic, weak) id<GTAdViewDelegate> delegate;

// Pause and restart operations (useful when container window is covered.
-(BOOL)pause;
-(void)restart;

// The designated initializer (call this one passing the view in which the ad view should be embedded)
-(id)initWithContainerView:(UIView *)theContainer andRootViewController:(UIViewController *)viewController andGoogleID:(NSString *)googleID testing:(BOOL)testing;

@end
