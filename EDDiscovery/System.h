//
//  System.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Distance, Image, Jump;

NS_ASSUME_NONNULL_BEGIN

@interface System : NSManagedObject

+ (NSArray *)allSystemsInContext:(NSManagedObjectContext *)context;
+ (System *)systemWithName:(NSString *)name inContext:(NSManagedObjectContext *)context;
+ (void)updateSystemsFromEDSM:(void(^)(void))response;

- (NSUInteger)numVisits;
- (BOOL)hasCoordinates;
- (NSNumber *)distanceToSol;
- (void)parseEDSMData:(NSDictionary *)data;

@end

NS_ASSUME_NONNULL_END

#import "System+CoreDataProperties.h"
