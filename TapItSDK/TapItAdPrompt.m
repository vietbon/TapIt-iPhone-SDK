//
//  TapItPopupAd.m
//  TapIt-iOS-Sample
//
//  Created by Nick Penteado on 7/20/12.
//  Copyright (c) 2012 TapIt!. All rights reserved.
//

#import "TapItPrivateConstants.h"
#import "TapItAdPrompt.h"
#import "TapItAdManager.h"
#import "TapItBrowserController.h"
#import "TapItRequest.h"

typedef enum {
    TapItAdPromptStateNew,
    TapItAdPromptStateLoading,
    TapItAdPromptStateLoaded,
    TapItAdPromptStateShown,
    TapItAdPromptStateError,
} TapItAdPromptState;


@interface TapItAdPrompt () <TapItAdManagerDelegate, TapItBrowserControllerDelegate> {
    BOOL isAlertType;
    TapItAdPromptState state;
    BOOL displayImmediately;
    NSDictionary *_data;
}
@property (retain, nonatomic) TapItRequest *adRequest;
@property (retain, nonatomic) TapItAdManager *adManager;
@property (retain, nonatomic) NSString *clickUrl;
@property (retain, nonatomic) TapItBrowserController *browserController;

- (void)performRequest;
- (void)performAdAction;
@end

@implementation TapItAdPrompt

@synthesize delegate, adRequest, adManager, clickUrl, browserController, showLoadingOverlay;

- (BOOL)loaded {
    return (state > TapItAdPromptStateLoaded && state != TapItAdPromptStateError);
}

- (id)initWithRequest:(TapItRequest *)request {
    self = [super init];
    if (self) {
        self.adManager = [[[TapItAdManager alloc] init] autorelease];
        self.adManager.delegate = self;
        self.adRequest = request;
        state = TapItAdPromptStateNew;
        displayImmediately = NO;
        _data = nil;
    }
    return self;
}

#pragma mark -
#pragma mark AlertAd Methods

- (void)load {
    if (state >= TapItAdPromptStateLoading) {
        if (state >= TapItAdPromptStateShown) {
            NSLog(@"Re-use of AdPrompt object is dissalowed.  Please instantiate a new AdPrompt.");
        }
        else if (state == TapItAdPromptStateLoading) {
            NSLog(@"AdPrompt is currently loading, ignoring");
        }
        else {
            NSLog(@"AdPrompt was already loaded, ignoring");
        }
        return;
    }
    state = TapItAdPromptStateLoading;
    [self performRequest];
}

- (void)showAsAlert {
    if (state >= TapItAdPromptStateShown) {
        NSLog(@"Re-use of AdPrompt object is dissalowed.  Please instantiate a new AdPrompt.");
        return;
    }
    else if (state == TapItAdPromptStateLoading) {
        NSLog(@"AdPrompt is currently loading. Please check adPrompt.loaded before showing");
        return;
    }
    else if (state == TapItAdPromptStateNew) {
        isAlertType = YES;
        displayImmediately = YES;
        [self load];
        return;
        // [self load] will bring us back here once data is available...
    }
    
    NSString *title = [_data objectForKey:@"adtitle"];
    NSString *callToAction = [_data objectForKey:@"calltoaction"];
    NSString *declineString = [_data objectForKey:@"declinestring"];

    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:nil 
                                                    message:title 
                                                   delegate:self 
                                          cancelButtonTitle:declineString
                                          otherButtonTitles:callToAction, nil];
    [alert show];
    [alert release];
    state = TapItAdPromptStateShown;
    
    if ([self.delegate respondsToSelector:@selector(tapitAdPromptWasDisplayed:)]) {
        [self.delegate tapitAdPromptWasDisplayed:self];
    }
}

- (void)showAsActionSheet {
    if (state >= TapItAdPromptStateShown) {
        NSLog(@"Re-use of AdPrompt object is dissalowed.  Please instantiate a new AdPrompt.");
        return;
    }
    else if (state == TapItAdPromptStateLoading) {
        NSLog(@"AdPrompt is currently loading. Please check adPrompt.loaded before showing");
        return;
    }
    else if (state == TapItAdPromptStateNew) {
        isAlertType = NO;
        displayImmediately = YES;
        [self load];
        return;
        // [self load] will bring us back here once data is available...
    }
    
    NSString *title = [_data objectForKey:@"adtitle"];
    NSString *callToAction = [_data objectForKey:@"calltoaction"];
    NSString *declineString = [_data objectForKey:@"declinestring"];
    UIActionSheet *actionSheet = [[UIActionSheet alloc] initWithTitle:title
                                                    delegate:self 
                                           cancelButtonTitle:nil 
                                      destructiveButtonTitle:nil 
                                           otherButtonTitles:callToAction, declineString, nil];
    actionSheet.actionSheetStyle = UIActionSheetStyleAutomatic;
    
    [actionSheet showInView:[UIApplication sharedApplication].keyWindow];
    [actionSheet release];
    state = TapItAdPromptStateShown;
    
    if ([self.delegate respondsToSelector:@selector(tapitAdPromptWasDisplayed:)]) {
        [self.delegate tapitAdPromptWasDisplayed:self];
    }
}

#pragma mark -
- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
//    NSLog(@"UIAlertView: dismissed with button: %d", buttonIndex);
    if (buttonIndex == 1) { // second button is the call to action...
        BOOL performAction = YES;
        if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPromptActionShouldBegin:willLeaveApplication:)]) {
            performAction = [self.delegate tapitAdPromptActionShouldBegin:self willLeaveApplication:NO];
        }
        if (performAction) {
            [self performAdAction];
        }
    }
    else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPromptWasDeclined:)]) {
            [self.delegate tapitAdPromptWasDeclined:self];
        }
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
//    NSLog(@"UIActionSheet: dismissed with button: %d", buttonIndex);
    if (buttonIndex == 0) { // top button is the call to action...
        BOOL performAction = YES;
        if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPromptActionShouldBegin:willLeaveApplication:)]) {
            performAction = [self.delegate tapitAdPromptActionShouldBegin:self willLeaveApplication:NO];
        }
        if (performAction) {
            [self performAdAction];
        }
    }
    else {
        if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPromptWasDeclined:)]) {
            [self.delegate tapitAdPromptWasDeclined:self];
        }
    }
}

- (void)performRequest {
    [self.adRequest setCustomParameter:TAPIT_AD_TYPE_ALERT forKey:@"adtype"];
    [self.adManager fireAdRequest:self.adRequest];
    // didReceiveData: or adView:didFailToReceiveAdWithError: get called next...
}

- (void)performAdAction {
    [self openURLInFullscreenBrowser:[NSURL URLWithString:self.clickUrl]];
}

#pragma mark -
#pragma mark TapItBrowserController Delegate methods

- (void)openURLInFullscreenBrowser:(NSURL *)url {
    self.browserController = [[[TapItBrowserController alloc] init] autorelease];
    self.browserController.delegate = self;
    self.browserController.showLoadingOverlay = self.showLoadingOverlay;
    [self.browserController loadUrl:url];
}

- (void)browserControllerFailedToLoad:(TapItBrowserController *)browserController withError:(NSError *)error {
    if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPrompt:didFailWithError:)]) {
        [self.delegate tapitAdPrompt:self didFailWithError:error];
    }
}

- (BOOL)browserControllerShouldLoad:(TapItBrowserController *)browserController willLeaveApp:(BOOL)willLeaveApp {
    BOOL shouldLoad = YES;
    if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPromptActionShouldBegin:willLeaveApplication:)]) {
        shouldLoad = [self.delegate tapitAdPromptActionShouldBegin:self willLeaveApplication:willLeaveApp];
    }
    return shouldLoad;
}

- (void)browserControllerLoaded:(TapItBrowserController *)browserController willLeaveApp:(BOOL)willLeaveApp {
    if (!willLeaveApp) {
        [self.browserController showFullscreenBrowserAnimated:YES];
    }
}

- (void)browserControllerWillDismiss:(TapItBrowserController *)browserController {
    // noop
}

- (void)browserControllerDismissed:(TapItBrowserController *)browserController {
    if (self.delegate && [self.delegate respondsToSelector:@selector(tapitAdPromptActionShouldBegin:willLeaveApplication:)]) {
        [self.delegate tapitAdPromptActionDidFinish:self];
    }
}




#pragma mark -
#pragma mark TapItAdManager Delegate methods

- (void)willLoadAdWithRequest:(TapItRequest *)request {
    
}

- (void)didLoadAdView:(TapItAdView *)adView {
    // noop
}

- (void)adView:(TapItAdView *)adView didFailToReceiveAdWithError:(NSError*)error {
    state = TapItAdPromptStateError;
    if ([self.delegate respondsToSelector:@selector(tapitAdPrompt:didFailWithError:)]) {
        [self.delegate tapitAdPrompt:self didFailWithError:error];
    }
}

- (BOOL)adActionShouldBegin:(NSURL *)actionUrl willLeaveApplication:(BOOL)willLeave {
    if ([self.delegate respondsToSelector:@selector(tapitAdPromptActionShouldBegin:willLeaveApplication:)]) {
        return [self.delegate tapitAdPromptActionShouldBegin:self willLeaveApplication:willLeave];
    }
    return YES;
}

- (void)adViewActionDidFinish:(TapItAdView *)adView {
    if ([self.delegate respondsToSelector:@selector(tapitAdPromptActionDidFinish:)]) {
        [self.delegate tapitAdPromptActionDidFinish:self];
    }    
}

- (void)didReceiveData:(NSDictionary *)data {
//    NSLog(@"Received data: %@", data);
    self.clickUrl = [data objectForKey:@"clickurl"];
//    self.clickUrl = @"http://itunes.apple.com/us/app/tiny-village/id453126021?mt=8#";
    
    if (_data) {
        // this shouldn't be possible, but just in case...
        [_data release]; _data = nil;
    }
    _data = [data retain];

    state = TapItAdPromptStateLoaded;

    if ([self.delegate respondsToSelector:@selector(tapitAdPromptDidLoad:)]) {
        [self.delegate tapitAdPromptDidLoad:self];
    }
    
    if (displayImmediately) {
        if (isAlertType) {
            [self showAsAlert];
        }
        else {
            [self showAsActionSheet];
        }
    }
}

#pragma mark -

- (void)dealloc {
    self.delegate = nil;
    self.adRequest = nil;
    self.adManager = nil;
    self.clickUrl = nil;
    self.browserController = nil;
    [_data release]; _data = nil;
    [super dealloc];
}
@end
