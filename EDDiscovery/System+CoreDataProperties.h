//
//  System+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 30/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "System.h"

NS_ASSUME_NONNULL_BEGIN

@interface System (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *name;
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double z;
@property (nullable, nonatomic, retain) NSSet<Note *> *notes;
@property (nullable, nonatomic, retain) NSSet<Distance *> *distances;
@property (nullable, nonatomic, retain) NSOrderedSet<Image *> *images;
@property (nullable, nonatomic, retain) NSSet<Jump *> *jumps;

@end

@interface System (CoreDataGeneratedAccessors)

- (void)addNotesObject:(Note *)value;
- (void)removeNotesObject:(Note *)value;
- (void)addNotes:(NSSet<Note *> *)values;
- (void)removeNotes:(NSSet<Note *> *)values;

- (void)addDistancesObject:(Distance *)value;
- (void)removeDistancesObject:(Distance *)value;
- (void)addDistances:(NSSet<Distance *> *)values;
- (void)removeDistances:(NSSet<Distance *> *)values;

- (void)insertObject:(Image *)value inImagesAtIndex:(NSUInteger)idx;
- (void)removeObjectFromImagesAtIndex:(NSUInteger)idx;
- (void)insertImages:(NSArray<Image *> *)value atIndexes:(NSIndexSet *)indexes;
- (void)removeImagesAtIndexes:(NSIndexSet *)indexes;
- (void)replaceObjectInImagesAtIndex:(NSUInteger)idx withObject:(Image *)value;
- (void)replaceImagesAtIndexes:(NSIndexSet *)indexes withImages:(NSArray<Image *> *)values;
- (void)addImagesObject:(Image *)value;
- (void)removeImagesObject:(Image *)value;
- (void)addImages:(NSOrderedSet<Image *> *)values;
- (void)removeImages:(NSOrderedSet<Image *> *)values;

- (void)addJumpsObject:(Jump *)value;
- (void)removeJumpsObject:(Jump *)value;
- (void)addJumps:(NSSet<Jump *> *)values;
- (void)removeJumps:(NSSet<Jump *> *)values;

@end

NS_ASSUME_NONNULL_END
