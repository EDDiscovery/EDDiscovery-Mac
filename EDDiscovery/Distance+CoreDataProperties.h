//
//  Distance+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 27/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Distance.h"

NS_ASSUME_NONNULL_BEGIN

@interface Distance (CoreDataProperties)

@property (nonatomic) double distance;
@property (nullable, nonatomic, retain) NSString *name;
@property (nonatomic) double calculatedDistance;
@property (nullable, nonatomic, retain) System *system;

@end

NS_ASSUME_NONNULL_END
