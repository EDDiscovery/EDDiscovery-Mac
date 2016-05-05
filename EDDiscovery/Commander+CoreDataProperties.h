//
//  Commander+CoreDataProperties.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 30/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Commander.h"

NS_ASSUME_NONNULL_BEGIN

@interface Commander (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) NSString *netLogFilesDir;
@property (nullable, nonatomic, retain) EDSM *edsmAccount;
@property (nullable, nonatomic, retain) NSOrderedSet<NetLogFile *> *netLogFiles;

@end

@interface Commander (CoreDataGeneratedAccessors)

- (void)insertObject:(NetLogFile *)value inNetLogFilesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromNetLogFilesAtIndex:(NSUInteger)idx;
- (void)insertNetLogFiles:(NSArray<NetLogFile *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeNetLogFilesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInNetLogFilesAtIndex:(NSUInteger)idx withObject:(NetLogFile *)value;
- (void)replaceNetLogFilesAtIndexes:(NSIndexSet *)indexes withNetLogFiles:(NSArray<NetLogFile *> *)values;
- (void)addNetLogFilesObject:(NetLogFile *)value;
- (void)removeNetLogFilesObject:(NetLogFile *)value;
- (void)addNetLogFiles:(NSOrderedSet<NetLogFile *> *)values;
- (void)removeNetLogFiles:(NSOrderedSet<NetLogFile *> *)values;

@end

NS_ASSUME_NONNULL_END
