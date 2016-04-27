//
//  System+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 27/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "System.h"

NS_ASSUME_NONNULL_BEGIN

@interface System (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *comment;
@property (nullable, nonatomic, retain) NSString *name;
@property (nonatomic) double x;
@property (nonatomic) double y;
@property (nonatomic) double z;
@property (nullable, nonatomic, retain) NSSet<Distance *> *distances;
@property (nullable, nonatomic, retain) NSSet<Image *> *images;
@property (nullable, nonatomic, retain) NSSet<Jump *> *jumps;

@end

@interface System (CoreDataGeneratedAccessors)

- (void)addDistancesObject:(Distance *)value;
- (void)removeDistancesObject:(Distance *)value;
- (void)addDistances:(NSSet<Distance *> *)values;
- (void)removeDistances:(NSSet<Distance *> *)values;

- (void)addImagesObject:(Image *)value;
- (void)removeImagesObject:(Image *)value;
- (void)addImages:(NSSet<Image *> *)values;
- (void)removeImages:(NSSet<Image *> *)values;

- (void)addJumpsObject:(Jump *)value;
- (void)removeJumpsObject:(Jump *)value;
- (void)addJumps:(NSSet<Jump *> *)values;
- (void)removeJumps:(NSSet<Jump *> *)values;

@end

NS_ASSUME_NONNULL_END
