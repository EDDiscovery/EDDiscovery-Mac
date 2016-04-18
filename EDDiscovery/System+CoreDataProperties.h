//
//  System+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
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
@property (nonatomic) BOOL permit;
@property (nonatomic) NSTimeInterval timestamp;
@property (nullable, nonatomic, retain) NSSet<Jump *> *jumps;
@property (nullable, nonatomic, retain) NSSet<Distance *> *distances;
@property (nullable, nonatomic, retain) NSSet<Image *> *images;

@end

@interface System (CoreDataGeneratedAccessors)

- (void)addJumpsObject:(Jump *)value;
- (void)removeJumpsObject:(Jump *)value;
- (void)addJumps:(NSSet<Jump *> *)values;
- (void)removeJumps:(NSSet<Jump *> *)values;

- (void)addDistancesObject:(Distance *)value;
- (void)removeDistancesObject:(Distance *)value;
- (void)addDistances:(NSSet<Distance *> *)values;
- (void)removeDistances:(NSSet<Distance *> *)values;

- (void)addImagesObject:(Image *)value;
- (void)removeImagesObject:(Image *)value;
- (void)addImages:(NSSet<Image *> *)values;
- (void)removeImages:(NSSet<Image *> *)values;

@end

NS_ASSUME_NONNULL_END
