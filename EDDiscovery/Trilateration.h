//
//  Trilateration.h
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

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

- (id)initWithCoordinate:(Coordinate *)coordinate distance:(double)distance;
- (id)initWithX:(double)x y:(double)y z:(double)z distance:(double)distance;

@property(nonatomic, strong, readonly) Coordinate *coordinate;
@property(nonatomic,         readonly) double     distance;

@end

@interface Result : NSObject

- (id)initWithState:(ResultState)state;
- (id)initWithState:(ResultState)state coordinate:(Coordinate *)coordinate;
- (id)initWithState:(ResultState)state coordinate:(Coordinate *)coordinate entriesDistances:(NSDictionary <Entry *, NSNumber *> *)entriesDistances;

@property(nonatomic,         readonly) ResultState  state;
@property(nonatomic, strong, readonly) Coordinate  *coordinate;
@property(nonatomic, strong, readonly) NSDictionary <Entry *, NSNumber *> *entriesDistances;

@end

@interface Trilateration : NSObject

- (id)init;
- (Result *)run:(Algorithm)algorithm;

@property(nonatomic, readonly) NSMutableArray <Entry *> *entries;

@end
