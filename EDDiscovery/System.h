//
//  System.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

NS_ASSUME_NONNULL_BEGIN

@class Note;
@class Distance;
@class Image;
@class Jump;

@interface System : NSManagedObject

+ (NSArray *)systemsWithNames:(NSOrderedSet *)names inContext:(NSManagedObjectContext *)context;
+ (NSArray *)allSystemsInContext:(NSManagedObjectContext *)context;
+ (System *)systemWithName:(NSString *)name inContext:(NSManagedObjectContext *)context;
+ (void)updateSystemsFromEDSM:(void(^)(void))response;

- (NSUInteger)numVisits;
- (BOOL)hasCoordinates;
- (NSNumber *)distanceToSol;

- (NSMutableArray <System *> *)suggestedReferences;
- (void)addSuggestedReferences;

- (void)updateFromEDSM:(void(^__nullable)(void))response;

@property(nonatomic, strong  ) NSArray                     *distanceSortDescriptors;
@property(nonatomic, readonly) NSMutableArray <Distance *> *sortedDistances;
@property(nonatomic, readonly) NSMutableArray <System   *> *suggestedReferences;
@property(nonatomic, strong  ) NSString                     *note;

@end

NS_ASSUME_NONNULL_END

#import "System+CoreDataProperties.h"
