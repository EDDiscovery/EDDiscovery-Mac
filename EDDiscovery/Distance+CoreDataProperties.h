//
//  Distance+CoreDataProperties.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 05/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Distance.h"

NS_ASSUME_NONNULL_BEGIN

@interface Distance (CoreDataProperties)

@property (nullable, nonatomic, retain) NSNumber *calculatedDistance;
@property (nullable, nonatomic, retain) NSNumber *distance;
@property (nullable, nonatomic, retain) NSString *name;
@property (nullable, nonatomic, retain) System *system;

@end

NS_ASSUME_NONNULL_END
