//
//  Jump+CoreDataProperties.h
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Jump.h"

NS_ASSUME_NONNULL_BEGIN

@interface Jump (CoreDataProperties)

@property (nonatomic) NSTimeInterval timestamp;
@property (nullable, nonatomic, retain) Trip *trip;
@property (nullable, nonatomic, retain) System *system;

@end

NS_ASSUME_NONNULL_END
