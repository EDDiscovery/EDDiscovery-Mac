//
//  Jump.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class System, EDSM, NetLogFile, Commander, Image;

NS_ASSUME_NONNULL_BEGIN

#define VOID_PREDICATE [NSPredicate predicateWithFormat:@"edsm == nil && edsm != nil"]
#define CMDR_PREDICATE [NSPredicate predicateWithFormat:@"edsm.commander.name == %@ OR netLogFile.commander.name == %@", commander.name, commander.name]

@interface Jump : NSManagedObject

+ (void)printJumpStatsOfCommander:(Commander *)commander;
+ (NSArray *)allJumpsOfCommander:(Commander *)commander;
+ (NSArray *)last:(NSUInteger)count jumpsOfCommander:(Commander *)commander;
+ (Jump *)lastXYZJumpOfCommander:(Commander *)commander;
+ (Jump *)lastNetlogJumpOfCommander:(Commander *)commander beforeDate:(NSDate *)date;

@property(nonatomic, readonly) NSNumber *distanceFromPreviousJump;

@end

NS_ASSUME_NONNULL_END

#import "Jump+CoreDataProperties.h"
