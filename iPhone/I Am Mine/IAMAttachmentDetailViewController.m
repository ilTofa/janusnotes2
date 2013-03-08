//
//  IAMAttachmentDetailViewController.m
//  I Am Mine
//
//  Created by Giacomo Tufano on 07/03/13.
//  Copyright (c) 2013 Giacomo Tufano. All rights reserved.
//

#import "IAMAttachmentDetailViewController.h"

#import "GTThemer.h"

#define kReadabilityBookmarkletCode @"(function(){window.baseUrl='https://www.readability.com';window.readabilityToken='';var s=document.createElement('script');s.setAttribute('type','text/javascript');s.setAttribute('charset','UTF-8');s.setAttribute('src',baseUrl+'/bookmarklet/read.js');document.documentElement.appendChild(s);})()"

@interface IAMAttachmentDetailViewController () <UIActionSheetDelegate>

@property (weak, nonatomic) IBOutlet UIWebView *theWebView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *theSpinnerForWebView;
@property (weak, nonatomic) IBOutlet UIToolbar *theToolbar;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *shareButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *deleteButton;

- (IBAction)goBackClicked:(id)sender;
- (IBAction)goForwardClicked:(id)sender;
- (IBAction)readability:(id)sender;

- (IBAction)openInSafari:(id)sender;
- (IBAction)done:(id)sender;
- (IBAction)deleteAttachment:(id)sender;

@end

@implementation IAMAttachmentDetailViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSAssert(self.theAttachment, @"No valid Attachment object sent to IAMAttachmentDetailViewController.");
    [[GTThemer sharedInstance] applyColorsToView:self.theToolbar];
    [[GTThemer sharedInstance] applyColorsToView:self.theSpinnerForWebView];
    if([self.theAttachment.type isEqualToString:@"Link"]) {
        [self.theWebView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:[[NSString alloc] initWithData:self.theAttachment.data encoding:NSUTF8StringEncoding]]]];
    } else if([self.theAttachment.type isEqualToString:@"Image"]) {
        [self.shareButton setEnabled:NO];
        [self.theWebView loadData:self.theAttachment.data MIMEType:@"image/png" textEncodingName:nil baseURL:nil];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:NSLocalizedString(@"Unknown attachment type, cannot show it.", nil) delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", nil) otherButtonTitles:nil];
        [alert show];
    }
    if(!self.deleterObject)
        [self.deleteButton setEnabled:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - UIWebViewDelegate and actions

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType
{
    return YES;
}

- (void)webViewDidFinishLoad:(UIWebView *)webView
{
    [self.theSpinnerForWebView stopAnimating];
//    self.goForwardButton.enabled = [self.theWebView canGoForward];
//    self.goBackButton.enabled = [self.theWebView canGoBack];
}

- (void)webViewDidStartLoad:(UIWebView *)webView
{
    [self.theSpinnerForWebView startAnimating];
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error
{
    NSLog(@"Error: %@", [error description]);
    [self webViewDidFinishLoad:webView];
}

#pragma mark - IBAction(s)

- (IBAction)goBackClicked:(id)sender
{
    [self.theWebView goBack];
}

- (IBAction)goForwardClicked:(id)sender
{
    [self.theWebView goForward];
}

- (IBAction)readability:(id)sender
{
    [self.theWebView stringByEvaluatingJavaScriptFromString:kReadabilityBookmarkletCode];
}

- (IBAction)openInSafari:(id)sender
{
    [[UIApplication sharedApplication] openURL:self.theWebView.request.URL];
}

- (IBAction)done:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)deleteAttachment:(id)sender
{
    UIActionSheet *chooseIt = [[UIActionSheet alloc] initWithTitle:NSLocalizedString(@"Delete Attachment from Note?", nil)
                                                          delegate:self
                                                 cancelButtonTitle:NSLocalizedString(@"No", nil)
                                            destructiveButtonTitle:NSLocalizedString(@"Yes, Delete It!", nil)
                                                 otherButtonTitles:nil];
    [chooseIt showInView:self.view];
}

#pragma mark UIActionSheetDelegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    DLog(@"Clicked button at index %d", buttonIndex);
    if(buttonIndex == 0)
    {
        [self.deleterObject deleteAttachment:self.theAttachment];
        [self done:nil];
    }
}


@end
