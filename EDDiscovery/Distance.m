//
//  Distance.m
//  EDDiscovery
//
//  Created by thorin on 26/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <objc/runtime.h>

#import "Distance.h"
#import "System.h"
#import "AppDelegate.h"
#import "Jump.h"

@implementation Distance

- (NSString *)status {
  NSString *status = NSLocalizedString(@"OK", @"");
  
  if (self.distance != self.calculatedDistance) {
    status = NSLocalizedString(@"Wrong distance?", @"");
  }
  
  return status;
}

@end
