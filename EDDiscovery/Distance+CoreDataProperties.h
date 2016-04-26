//
//  Distance+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 26/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Distance.h"

NS_ASSUME_NONNULL_BEGIN

@interface Distance (CoreDataProperties)

@property (nonatomic) double distance;
@property (nullable, nonatomic, retain) NSSet<System *> *systems;

@end

@interface Distance (CoreDataGeneratedAccessors)

- (void)addSystemsObject:(System *)value;
- (void)removeSystemsObject:(System *)value;
- (void)addSystems:(NSSet<System *> *)values;
- (void)removeSystems:(NSSet<System *> *)values;

@end

NS_ASSUME_NONNULL_END
