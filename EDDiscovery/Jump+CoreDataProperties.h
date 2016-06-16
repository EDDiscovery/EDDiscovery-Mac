//
//  Jump+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 15/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Jump.h"

NS_ASSUME_NONNULL_BEGIN

@interface Jump (CoreDataProperties)

@property (nonatomic) NSTimeInterval timestamp;
@property (nonatomic) BOOL hidden;
@property (nullable, nonatomic, retain) EDSM *edsm;
@property (nullable, nonatomic, retain) NSOrderedSet<Image *> *images;
@property (nullable, nonatomic, retain) NetLogFile *netLogFile;
@property (nullable, nonatomic, retain) System *system;

@end

@interface Jump (CoreDataGeneratedAccessors)

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

@end

NS_ASSUME_NONNULL_END
