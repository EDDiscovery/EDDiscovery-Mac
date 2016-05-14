//
//  NetLogFile+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 13/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "NetLogFile.h"

NS_ASSUME_NONNULL_BEGIN

@interface NetLogFile (CoreDataProperties)

@property (nonatomic) BOOL complete;
@property (nonatomic) BOOL cqc;
@property (nonatomic) int64_t fileOffset;
@property (nullable, nonatomic, retain) NSString *path;
@property (nullable, nonatomic, retain) NSString *fileDate;
@property (nullable, nonatomic, retain) Commander *commander;
@property (nullable, nonatomic, retain) NSOrderedSet<Jump *> *jumps;

@end

@interface NetLogFile (CoreDataGeneratedAccessors)

- (void)insertObject:(Jump *)value inJumpsAtIndex:(NSUInteger)idx;
- (void)removeObjectFromJumpsAtIndex:(NSUInteger)idx;
- (void)insertJumps:(NSArray<Jump *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeJumpsAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInJumpsAtIndex:(NSUInteger)idx withObject:(Jump *)value;
- (void)replaceJumpsAtIndexes:(NSIndexSet *)indexes withJumps:(NSArray<Jump *> *)values;
- (void)addJumpsObject:(Jump *)value;
- (void)removeJumpsObject:(Jump *)value;
- (void)addJumps:(NSOrderedSet<Jump *> *)values;
- (void)removeJumps:(NSOrderedSet<Jump *> *)values;

@end

NS_ASSUME_NONNULL_END
