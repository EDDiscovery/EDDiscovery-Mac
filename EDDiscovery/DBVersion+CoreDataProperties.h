//
//  DBVersion+CoreDataProperties.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 19/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

#import "DBVersion.h"

NS_ASSUME_NONNULL_BEGIN

@interface DBVersion (CoreDataProperties)

@property (nonatomic) int16_t dbVersion;

@end

NS_ASSUME_NONNULL_END
