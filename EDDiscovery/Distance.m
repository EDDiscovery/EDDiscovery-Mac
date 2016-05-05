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

- (void)setDistance:(NSNumber *)distance {
  [self willChangeValueForKey:@"distance"];
  [self willChangeValueForKey:@"status"];
  [self setPrimitiveValue:distance forKey:@"distance"];
  [self didChangeValueForKey:@"distance"];
  [self didChangeValueForKey:@"status"];
  
  if (distance == nil) {
    self.calculatedDistance = nil;
  }
}

- (void)setCalculatedDistance:(NSNumber *)calculatedDistance {
  [self willChangeValueForKey:@"calculatedDistance"];
  [self willChangeValueForKey:@"status"];
  [self setPrimitiveValue:calculatedDistance forKey:@"calculatedDistance"];
  [self didChangeValueForKey:@"calculatedDistance"];
  [self didChangeValueForKey:@"status"];
}

- (NSString *)status {
  NSString *status = NSLocalizedString(@"OK", @"");
  
  if (self.distance == nil || self.calculatedDistance == nil) {
    status = nil;
  }
  else if (self.distance.doubleValue != self.calculatedDistance.doubleValue) {
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
