//
//  Commander.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 29/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class EDSM, NetLogFile;

NS_ASSUME_NONNULL_BEGIN

@interface Commander : NSManagedObject

+ (Commander *)activeCommander;
+ (void)setActiveCommander:(nullable Commander *)commander;

+ (NSArray *)allCommanders;
+ (Commander *)commanderWithName:(NSString *)name;
+ (Commander *)createCommanderWithName:(NSString *)name;

- (void)setNetLogFilesDir:(NSString *)newNetLogFilesDir completion:(void(^__nonnull)(void))completionBlock;
- (void)deleteCommander;

@end

NS_ASSUME_NONNULL_END

#import "Commander+CoreDataProperties.h"
