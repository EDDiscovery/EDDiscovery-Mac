//
//  Jump.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class System, EDSM, NetLogFile;

NS_ASSUME_NONNULL_BEGIN

@interface Jump : NSManagedObject

+ (void)printStats;
+ (NSArray *)getAllJumpsInContext:(NSManagedObjectContext *)context;
+ (Jump *)getLastJumpInContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "Jump+CoreDataProperties.h"
