//
//  GTAdViewFactory.m
//  radioz
//
//  Created by Giacomo Tufano on 25/09/12.
//
//

#import "GTAdViewFactory.h"

#import "GTPiwikAddOn.h"

@interface GTAdViewFactory () <ADBannerViewDelegate, GADBannerViewDelegate>

@property (nonatomic) BOOL delegateIsNotifiedOfSuccess;

@property (nonatomic) BOOL bannerClickInProcess;

// The banner view instances
@property (nonatomic, strong) ADBannerView *iAdBannerView;
@property (nonatomic) BOOL isIAdVisible;

@property (nonatomic, strong) GADBannerView *googleAdBannerView;
@property (nonatomic) BOOL isGoogleAdVisible;
@property (nonatomic, copy) NSString *googleAdPublisherId;

// Testing ads
@property (nonatomic) BOOL testingAds;

// The container view from caller
@property (nonatomic, weak) UIView *theContainerView;
@property (nonatomic, weak) UIViewController *theContainerViewController;

// Custom "house" ad management
@property (strong) UIImageView *houseAdImage;
@property (strong) UIButton *adClickButton;
@property (strong) NSTimer *houseAdTimer;

@end

@implementation GTAdViewFactory 

#pragma mark -
#pragma mark Object lifetime

-(id)initWithContainerView:(UIView *)theContainer andRootViewController:(UIViewController *)viewController andGoogleID:(NSString *)googleID testing:(BOOL)testing
{
    self = [super init];
    if (self) {
        self.theContainerView = theContainer;
        self.theContainerViewController = viewController;
        self.googleAdPublisherId = googleID;
        self.testingAds = testing;
        self.googleAdBannerView = nil;
        self.isGoogleAdVisible = NO;
        self.isIAdVisible = NO;
        self.iAdBannerView = nil;
        self.delegateIsNotifiedOfSuccess = NO;
        self.bannerClickInProcess = NO;
        self.houseAdTimer = nil;
        [self restart];
    }
    return self;
}

-(void)dealloc
{
    if(self.delegate)
        [self.delegate giAdViewFactoryIsVoid:self];
    if(self.houseAdTimer)
    {
        [self.houseAdTimer invalidate];
        self.houseAdTimer = nil;
    }
    if(self.houseAdImage)
    {
        [self.houseAdImage removeFromSuperview];
        self.houseAdImage = nil;
    }
    if(self.adClickButton)
    {
        [self.adClickButton removeFromSuperview];
        self.adClickButton = nil;
    }
    if(self.iAdBannerView)
    {
        self.iAdBannerView.delegate = nil;
        self.iAdBannerView = nil;
    }
    if(self.googleAdBannerView)
    {
        self.googleAdBannerView.delegate = nil;
        self.googleAdBannerView = nil;
    }
}

-(BOOL)pause
{
    if(self.bannerClickInProcess)
    {
        DLog(@"Cannot pause, because a click is in process");
        return NO;
    }
    if(self.houseAdTimer)
    {
        DLog(@"Killing timer");
        [self.houseAdTimer invalidate];
        self.houseAdTimer = nil;
    }
    [self hideHouseAd:nil];
    [self killGoogleAdView];
    [self killiAdView];
    return YES;
}

-(void)restart
{
    [self setupiAdView];
    [self setupGoogleAdView];
}

#pragma mark -
#pragma mark House Ad

-(void)showHouseAd
{
    DLog(@"setupHouseAd");
    if(self.houseAdTimer)
    {
        DLog(@"Killing house ad dismiss timer.");
        [self.houseAdTimer invalidate];
        self.houseAdTimer = nil;
    }
    self.houseAdImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"HouseAd"]];
    [self.theContainerView addSubview:self.houseAdImage];
    self.adClickButton = [UIButton buttonWithType:UIButtonTypeCustom];
    self.adClickButton.frame = self.theContainerView.frame;
    self.adClickButton.showsTouchWhenHighlighted = YES;
    self.adClickButton.tintColor = [UIColor clearColor];
    [self.adClickButton addTarget:self action:@selector(houseAdClicked:) forControlEvents:UIControlEventTouchUpInside];
    [self.theContainerView addSubview:self.adClickButton];
    // setup dismissing...
    DLog(@"setup timer for killHouseAd:");
    self.houseAdTimer = [NSTimer scheduledTimerWithTimeInterval:30 target:self selector:@selector(hideHouseAd:) userInfo:nil repeats:NO];
}

-(void)hideHouseAd:(NSTimer *)timer
{
    if(self.adClickButton)
    {
        DLog(@"this is deleteHouseAd really deleting");
        [self.adClickButton removeFromSuperview];
        self.adClickButton = nil;
    }
    if(self.houseAdImage)
    {
        [self.houseAdImage removeFromSuperview];
        self.houseAdImage = nil;
    }
}

- (IBAction)houseAdClicked:(id)sender
{
    DLog(@"*** House Ad clicked! ***");
    [GTPiwikAddOn trackEvent:@"houseAdClicked"];
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"http://itunes.apple.com/app/id305922458"]];
}

#pragma mark -
#pragma mark ADViews lifetime

-(void)setupiAdView
{
    DLog(@"setupiAdView");
    self.iAdBannerView = [[ADBannerView alloc] initWithFrame:CGRectZero];
//    if(UIDeviceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]))
//        self.iAdBannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifierPortrait;
//    else
//        self.iAdBannerView.currentContentSizeIdentifier = ADBannerContentSizeIdentifierLandscape;
    self.iAdBannerView.delegate = self;
}

-(void)killiAdView
{
    if(self.isIAdVisible)
    {
        DLog(@"removing iAD from superview");
        self.isIAdVisible = NO;
        [self.iAdBannerView removeFromSuperview];
    }
    if(self.iAdBannerView)
    {
        DLog(@"nil-ing the iAD view");
        self.iAdBannerView.delegate = nil;
        self.iAdBannerView = nil;
    }
}

-(void)setupGoogleAdView
{
    DLog(@"setupGoogleAdView");
    if(UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
        self.googleAdBannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeBanner];
    else
        self.googleAdBannerView = [[GADBannerView alloc] initWithAdSize:kGADAdSizeLeaderboard];
    self.googleAdBannerView.adUnitID = self.googleAdPublisherId;
    self.googleAdBannerView.rootViewController = self.theContainerViewController;
    self.googleAdBannerView.delegate = self;
    GADRequest *request = [GADRequest request];
    request.testing = self.testingAds;
    [self.googleAdBannerView loadRequest:request];
}

-(void)killGoogleAdView
{
    if(self.isGoogleAdVisible)
    {
        DLog(@"removing AdMob from superview");
        self.isGoogleAdVisible = NO;
        [self.googleAdBannerView removeFromSuperview];
    }
    if(self.googleAdBannerView)
    {
        DLog(@"nil-ing the Google View");
        self.googleAdBannerView.delegate = nil;
        self.googleAdBannerView = nil;
    }
}

#pragma mark -
#pragma mark ADBannerViewDelegate

- (void)bannerViewDidLoadAd:(ADBannerView *)banner
{
    DLog(@"iAD banner is loaded!");
    // If house ad showing, kill it
    [self hideHouseAd:nil];
    // Kill google ad in any case and show iAD!
    [self killGoogleAdView];
    // Add iAd to the view if needed and notify the delegate
    if(self.isIAdVisible == NO)
    {
        self.isIAdVisible = YES;
        [self.theContainerView addSubview:self.iAdBannerView];
    }
    if(self.delegateIsNotifiedOfSuccess == NO)
    {
        DLog(@"Notifying delegate");
        self.delegateIsNotifiedOfSuccess = YES;
        [self.delegate gtAdViewFactoryDidLoadAd:self];
    }
}

- (void)bannerView:(ADBannerView *)banner didFailToReceiveAdWithError:(NSError *)error
{
    DLog(@"iAD banner failed to load");
    if(self.isIAdVisible)
    {
        self.isIAdVisible = NO;
        [self.iAdBannerView removeFromSuperview];
    }
    if(self.isGoogleAdVisible == NO)
    {
        DLog(@"AdMob and iAd have no ad to show. Firing housead timer and notify delegate we don't have ads");
        self.delegateIsNotifiedOfSuccess = NO;
        if(self.houseAdTimer)
            [self.houseAdTimer fire];
        else    // Last resource, get back to the delegate with no ad (should never happen, anyway).
            [self.delegate giAdViewFactoryIsVoid:self];
    }
    // If we don't have any AdMob view, create it...
    if(self.googleAdBannerView == nil)
    {
        DLog(@"Creating AdMob view");
        [self setupGoogleAdView];
    }
}

- (BOOL)bannerViewActionShouldBegin:(ADBannerView *)banner willLeaveApplication:(BOOL)willLeave
{
    // disable AdMob and HouseAds banners just in case.
    [GTPiwikAddOn trackEvent:@"iADClicked"];
    [self hideHouseAd:nil];
    [self killGoogleAdView];
    return YES;
}

- (void)bannerViewActionDidFinish:(ADBannerView *)banner
{
    // Restart ads processing
    [self restart];
}

#pragma mark -
#pragma mark GADBannerViewDelegate

- (void)adViewDidReceiveAd:(GADBannerView *)bannerView
{
    DLog(@"AdMob banner received");
    // If house ad showing, kill it
    [self hideHouseAd:nil];
    // if an iAD is loaded, kill the AdMob view...
    if(self.isIAdVisible)
    {
        DLog(@"killing AdMob received ad because iAD is showed");
        [self killGoogleAdView];
    } // If this is an ad coming without any view visible, add the view and notify delegate to show.
    else if(!self.isGoogleAdVisible)
    {
        self.isGoogleAdVisible = YES;
        [self.theContainerView addSubview:self.googleAdBannerView];
        self.delegateIsNotifiedOfSuccess = YES;
        [self.delegate gtAdViewFactoryDidLoadAd:self];
    }
}

- (void)adView:(GADBannerView *)bannerView didFailToReceiveAdWithError:(GADRequestError *)error
{
    DLog(@"Google view failed to receive ad with error: %@", [error localizedDescription]);
    // if an iAD is loaded, kill AdMob and leave it as is...
    if(self.isIAdVisible)
    {
        DLog(@"AdMob failed while iAD was showing. Killing AdMob");
        [self killGoogleAdView];
        return;
    }
    else if(self.isGoogleAdVisible)
    {
        DLog(@"removed AdMob from views");
        self.isGoogleAdVisible = NO;
        [self.googleAdBannerView removeFromSuperview];
        DLog(@"AdMob and iAd have no ad to show. Showing house ad.");
        // Otherwise start house ad...
        [self showHouseAd];
    }
}

- (void)adViewWillPresentScreen:(GADBannerView *)bannerView
{
    // disable iAd and HouseAds banners just in case.
    [GTPiwikAddOn trackEvent:@"googleAdClicked"];
    [self hideHouseAd:nil];
    [self killiAdView];
}

- (void)adViewWillDismissScreen:(GADBannerView *)bannerView
{
    // Restart ads processing
    [self restart];
}

@end
