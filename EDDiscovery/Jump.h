//
//  Jump.h
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class System, Trip, NetLogFile;

NS_ASSUME_NONNULL_BEGIN

@interface Jump : NSManagedObject

+ (Jump *)getLastJumpInContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "Jump+CoreDataProperties.h"
