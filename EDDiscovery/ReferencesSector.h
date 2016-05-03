//
//  ReferencesSector.h
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

@class ReferenceSystem;

@interface ReferencesSector : NSObject

- (id)initWithAzimuth:(double)azimuth altitude:(double)altitude width:(double)width;

- (void)addCandidate:(ReferenceSystem *)refSys;
- (ReferenceSystem *)getBestCandidate;
- (void)addReference:(ReferenceSystem *)refSys;

@property (nonatomic, readonly) double azimuth;
@property (nonatomic, readonly) double latitude;
@property (nonatomic, readonly) double azimuthCenter;
@property (nonatomic, readonly) double latitudeCenter;
@property (nonatomic, readonly) double azimuthCenterRad;
@property (nonatomic, readonly) double latitudeCenterRad;
@property (nonatomic, readonly) NSUInteger referencesCount;
@property (nonatomic, readonly) NSUInteger candidatesCount;
@property (nonatomic, readonly) double width;
@property (nonatomic, readonly) NSString *name;

@end
