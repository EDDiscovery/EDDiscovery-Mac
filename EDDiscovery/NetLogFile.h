//
//  NetLogFile.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Jump;
@class Commander;

NS_ASSUME_NONNULL_BEGIN

@interface NetLogFile : NSManagedObject

+ (NetLogFile *)netLogFileWithPath:(NSString *)path inContext:(NSManagedObjectContext *)context;

@end

NS_ASSUME_NONNULL_END

#import "NetLogFile+CoreDataProperties.h"
