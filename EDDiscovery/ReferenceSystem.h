//
//  ReferenceSystem.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

@class System;

@interface ReferenceSystem : NSObject

- (id)initWithReferenceSystem:(System *)refsys estimatedPosition:(System *)estimatedPosition;

@property(nonatomic, readonly) double distance;
@property(nonatomic, readonly) double azimuth;
@property(nonatomic, readonly) double altitude;
@property(nonatomic, readonly) System *system;
@property(nonatomic, readonly) double weight;

@end
