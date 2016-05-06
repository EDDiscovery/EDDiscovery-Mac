//
//  Distance.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 26/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <objc/runtime.h>

#import "Distance.h"
#import "System.h"
#import "AppDelegate.h"
#import "Jump.h"

@implementation Distance {
  BOOL   firstSetDone;
  double origDistance;
}

@synthesize edited;

- (void)setDistance:(NSNumber *)distance {
//  [self willAccessValueForKey:@"distance"];
//  NSLog(@"%s: %@ ==> %@", __FUNCTION__, [self primitiveValueForKey:@"distance"], distance);
//  [self didAccessValueForKey:@"distance"];
  
  [self willChangeValueForKey:@"distance"];
  [self willChangeValueForKey:@"status"];
  [self setPrimitiveValue:distance forKey:@"distance"];
  [self didChangeValueForKey:@"distance"];
  [self didChangeValueForKey:@"status"];
  
  if (distance == nil) {
    self.calculatedDistance = nil;
  }
  
  if (self.objectID.isTemporaryID == YES) {
    self.edited = YES;
  }
  else if (firstSetDone == NO) {
    origDistance = distance.doubleValue;
    firstSetDone = YES;
  }
  else if (distance.doubleValue != origDistance) {
    self.edited = YES;
  }
  else {
    self.edited = NO;
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
    if (ABS(self.distance.doubleValue - self.calculatedDistance.doubleValue) <= 0.01) {
      status = NSLocalizedString(@"Rounding error?", @"");
    }
    else {
      status = NSLocalizedString(@"Wrong distance?", @"");
    }
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

- (void)reset {
  [self willChangeValueForKey:@"status"];
  [self.managedObjectContext refreshObject:self mergeChanges:NO];
  [self didChangeValueForKey:@"status"];
  
  if (self.objectID.isTemporaryID == NO) {
    self.edited = NO;
  }
}

@end
