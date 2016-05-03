//
//  Distance.h
//  EDDiscovery
//
//  Created by thorin on 26/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class System;

NS_ASSUME_NONNULL_BEGIN

@interface Distance : NSManagedObject

- (NSString *)status;

@end

NS_ASSUME_NONNULL_END

#import "Distance+CoreDataProperties.h"
