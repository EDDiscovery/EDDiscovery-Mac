//
//  ViewController.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
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
}

@end
