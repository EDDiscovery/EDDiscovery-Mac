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

@implementation Distance {
  System *otherSystem;
}

- (System *)otherSystem {
  if (otherSystem == nil) {
    [self refreshOtherSystem];
  }
  
  return otherSystem;
}

- (void)refreshOtherSystem {
  [self willChangeValueForKey:@"otherSystem"];
  
  AppDelegate *delegate = NSApplication.sharedApplication.delegate;
  Jump        *jump     = delegate.selectedJump;
  System      *system   = jump.system;
  
  for (System *aSystem in self.systems) {
    if (aSystem != system) {
      otherSystem = aSystem;
      
      break;
    }
  }
  
  [self didChangeValueForKey:@"otherSystem"];
}

@end
