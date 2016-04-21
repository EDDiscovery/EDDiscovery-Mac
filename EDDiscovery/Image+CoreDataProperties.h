//
//  Image+CoreDataProperties.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 19/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "Image.h"

NS_ASSUME_NONNULL_BEGIN

@interface Image (CoreDataProperties)

@property (nullable, nonatomic, retain) NSString *path;
@property (nullable, nonatomic, retain) System *system;

@end

NS_ASSUME_NONNULL_END
