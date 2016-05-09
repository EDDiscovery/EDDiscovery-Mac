//
//  LoadingViewController.h
//  EDDiscovery
//
//  Created by thorin on 08/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LoadingViewController : NSViewController

+ (LoadingViewController *)loadingViewController;
+ (LoadingViewController *)loadingViewControllerInWindow:(NSWindow *)window;
- (void)dismiss;

@property(nonatomic, readonly) IBOutlet NSTextField         *textField;
@property(nonatomic, readonly) IBOutlet NSProgressIndicator *progressIndicator;

@end
