//
//  LoadingViewController.h
//  EDDiscovery
//
//  Created by thorin on 08/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LoadingViewController : NSViewController

+ (void)presentLoadingViewControllerInWindow:(NSWindow *)window;
+ (void)dismiss;

+ (NSTextField *)textField;
+ (NSProgressIndicator *)progressIndicator;

@end
