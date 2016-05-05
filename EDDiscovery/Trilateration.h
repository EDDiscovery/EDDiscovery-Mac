//
//  Trilateration.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

@class System;

typedef NS_ENUM(NSInteger, Algorithm) {
  RedWizzard_Emulated,
  RedWizzard_Native
};

typedef NS_ENUM(NSInteger, ResultState) {
  Exact,
  NotExact,
  NeedMoreDistances,
  MultipleSolutions,
};

@interface Coordinate : NSObject

- (id)initWithX:(double)x y:(double)y z:(double)z;
- (double)distanceToCoordinate:(Coordinate *)coordinate;

@property(nonatomic, readonly) double x;
@property(nonatomic, readonly) double y;
@property(nonatomic, readonly) double z;

@end

@interface Entry : NSObject

- (id)initWithSystem:(System *)system distance:(double)distance;
- (id)initWithCoordinate:(Coordinate *)coordinate distance:(double)distance;
- (id)initWithX:(double)x y:(double)y z:(double)z distance:(double)distance;

@property(nonatomic, strong, readonly) System     *system;
@property(nonatomic, strong, readonly) Coordinate *coordinate;
@property(nonatomic,         readonly) double      distance;
@property(nonatomic,         readonly) double      correctedDistance;

@end

@interface Result : NSObject

- (id)initWithState:(ResultState)state;
- (id)initWithState:(ResultState)state coordinate:(Coordinate *)coordinate;
- (id)initWithState:(ResultState)state coordinate:(Coordinate *)coordinate entries:(NSArray <Entry *> *)entries;

@property(nonatomic,         readonly) ResultState        state;
@property(nonatomic, strong, readonly) Coordinate        *coordinate;
@property(nonatomic, strong, readonly) NSArray <Entry *> *entries;

@end

@interface Trilateration : NSObject

- (id)init;
- (Result *)run:(Algorithm)algorithm;

@property(nonatomic, readonly) NSMutableArray <Entry *> *entries;

@end
