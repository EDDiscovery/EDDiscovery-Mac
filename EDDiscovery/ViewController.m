//
//  ViewController.m
//  EDDiscovery
//
//  Created by thorin on 15/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "ViewController.h"

#import "EventLogger.h"

@implementation ViewController {
  IBOutlet NSTextView *textView;
}

#pragma mark -
#pragma mark UIViewController delegate

- (void)viewDidLoad {
  [super viewDidLoad];

  EventLogger.instance.textView = textView;
  
  [EventLogger.instance addLog:@"HELLO!!!"];
}

@end
