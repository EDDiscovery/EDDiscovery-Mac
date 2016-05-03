//
//  ReferencesSector.m
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "ReferencesSector.h"

#import "ReferenceSystem.h"

@implementation ReferencesSector {
  double widthAngle;
  double azimuthStartRad;
  double latitudeStartRad;

  NSMutableArray <ReferenceSystem *> *usedReferences;
  NSMutableArray <ReferenceSystem *> *candidateReferences;
  NSMutableArray <ReferenceSystem *> *optcandidateReferences;

  double minWeight;
}

- (double)azimuth {
  return azimuthStartRad * 180 / M_PI;
}

- (double)latitude {
  return latitudeStartRad * 180 / M_PI;
}

- (double)azimuthCenter {
  return azimuthStartRad * 180 / M_PI + widthAngle / 2;
}

- (double)latitudeCenter {
  return latitudeStartRad * 180 / M_PI + widthAngle / 2;
}

- (double)azimuthCenterRad {
  return self.azimuthCenter * M_PI / 180;
}

- (double)latitudeCenterRad {
  return self.latitudeCenter * M_PI / 180;
}

- (NSUInteger)referencesCount {
  return usedReferences.count;
}

- (NSUInteger)candidatesCount {
  return candidateReferences.count - usedReferences.count;
}

- (double)width {
  return widthAngle * M_PI / 180;
}

- (id)initWithAzimuth:(double)azimuth altitude:(double)altitude width:(double)width {
  self = [super init];
  
  if (self != nil) {
    azimuthStartRad = azimuth * M_PI / 180;
    latitudeStartRad = altitude * M_PI / 180;
    widthAngle = width;
    
    usedReferences = [NSMutableArray array];
    candidateReferences = [NSMutableArray array];
    optcandidateReferences = [NSMutableArray array];
    minWeight = DBL_MAX;
  }
  
  return self;
}

- (ReferenceSystem *)getBestCandidate {
  NSArray <ReferenceSystem *> *candidate = [optcandidateReferences sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"weight" ascending:YES selector:@selector(compare:)]]];

  return candidate.firstObject;
}

- (void)addCandidate:(ReferenceSystem *)refSys {
  [candidateReferences addObject:refSys];
  
  double weight = refSys.weight;
  
  if (weight < minWeight)
  {
    minWeight = weight;
    [optcandidateReferences addObject:refSys];
  }
  else if (optcandidateReferences.count < 10)
    [optcandidateReferences addObject:refSys];
  else if (optcandidateReferences.count < 100 && refSys.distance < 1000 && refSys.distance > 100)
    [optcandidateReferences addObject:refSys];
}

- (void)addReference:(ReferenceSystem *)refSys {
  [usedReferences addObject:refSys];
}

@end
