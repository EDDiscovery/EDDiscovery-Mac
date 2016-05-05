//
//  Jump.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class System, EDSM, NetLogFile, Commander;

NS_ASSUME_NONNULL_BEGIN

#define CMDR_PREDICATE [NSPredicate predicateWithFormat:@"edsm.commander.name == %@ OR netLogFile.commander.name == %@", commander.name, commander.name]

@interface Jump : NSManagedObject

+ (void)printStatsOfCommander:(Commander *)commander;
+ (NSArray *)allJumpsOfCommander:(Commander *)commander;
+ (Jump *)lastJumpOfCommander:(Commander *)commander;
+ (Jump *)lastXYZJumpOfCommander:(Commander *)commander;

@property(nonatomic, readonly) NSNumber *distanceFromPreviousJump;

@end

NS_ASSUME_NONNULL_END

#import "Jump+CoreDataProperties.h"
