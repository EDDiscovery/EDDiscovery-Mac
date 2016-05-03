//
//  ReferenceSystem.m
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "ReferenceSystem.h"

#import "System.h"
#import "SystemData.h"

@implementation ReferenceSystem {
  double distance;
  double azimuth;
  double altitude;
  
  System *refSys;
}

- (double)distance {
  return distance;
}

- (double)azimuth {
  return azimuth;
}

- (double)altitude {
  return altitude;
}

- (System *)system {
  return refSys;
}


- (double)weight {
  int modifier = 0;
  
  //search bug seems to be fixed now, don't avoid these any more.
  //if (refSys.name.EndsWith("0"))  // Elite has a bug with selecting systems ending with 0.  Prefere others first.
  //    modifier += 50;
  
  NSString    *someRegexp = @"\\s[A-Z][A-Z].[A-Z]\\s";
  NSPredicate *myTest     = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", someRegexp];
  
  if ([myTest evaluateWithObject:refSys.name]){
    modifier += 20;
  }
  
  if (distance > 20000)
    modifier += 10;
  
  if (distance > 30000)
    modifier += 20;
  
  return refSys.name.length * 2 + sqrt(distance) / 3.5 + modifier;
  //return refSys.name.Length + Distance/100 + modifier;
}

- (id)initWithReferenceSystem:(System *)refsys estimatedPosition:(System *)estimatedPosition {
  self = [super init];
  
  if (self != nil) {
    refSys = refsys;
    azimuth = atan2(refSys.y - estimatedPosition.y, refSys.x - estimatedPosition.x);
    
    distance = [SystemData distance:refSys :estimatedPosition];
    
    altitude = acos((refSys.z-estimatedPosition.z)/distance);
  }
  
  return self;
}

@end
