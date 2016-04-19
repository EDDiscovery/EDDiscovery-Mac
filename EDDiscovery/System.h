//
//  System.h
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Distance, Image, Jump;

NS_ASSUME_NONNULL_BEGIN

@interface System : NSManagedObject

+ (System *)systemWithName:(NSString *)name inContext:(NSManagedObjectContext *)context;
+ (void)updateSystemsFromEDSM;

- (BOOL)haveCoordinates;
- (void)parseEDSMData:(NSDictionary *)data;

@end

NS_ASSUME_NONNULL_END

#import "System+CoreDataProperties.h"
