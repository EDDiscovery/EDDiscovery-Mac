//
//  LoadingViewController.m
//  EDDiscovery
//
//  Created by thorin on 08/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "LoadingViewController.h"
#import "AppDelegate.h"

@interface LoadingViewController ()

@property(nonatomic, strong) IBOutlet NSTextField         *textField;
@property(nonatomic, strong) IBOutlet NSProgressIndicator *progressIndicator;

@end

@implementation LoadingViewController

#pragma mark -
#pragma mark instance management

static LoadingViewController *loadingViewController = nil;

+ (LoadingViewController *)loadingViewController {
  return loadingViewController;
}

+ (void)presentLoadingViewControllerInWindow:(NSWindow *)window {
  if (loadingViewController == nil) {
    NSStoryboard       *storyboard       = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
    NSWindowController *windowController = [storyboard instantiateControllerWithIdentifier:@"LoadingWindow"];
    
    [window beginSheet:windowController.window completionHandler:nil];

    loadingViewController = (LoadingViewController *)windowController.contentViewController;
  }
}

+ (void)dismiss {
  [self.loadingViewController.view.window.sheetParent endSheet:self.loadingViewController.view.window];
  
  loadingViewController = nil;
}

+ (NSTextField *)textField {
  return self.loadingViewController.textField;
}

+ (NSProgressIndicator *)progressIndicator {
  return self.loadingViewController.progressIndicator;
}

@end
