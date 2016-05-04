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

@synthesize edited;

- (NSString *)status {
  NSString *status = NSLocalizedString(@"OK", @"");
  
  if (self.distance == 0) {
    status = @"";
  }
  if (self.distance != self.calculatedDistance) {
    status = NSLocalizedString(@"Wrong distance?", @"");
  }
  
  return status;
}

- (void)setName:(NSString *)name {
  if (self.name == nil && name.length > 0) {
    [self willChangeValueForKey:@"name"];
    [self setPrimitiveValue:name forKey:@"name"];
    [self didChangeValueForKey:@"name"];
  }
}

@end
