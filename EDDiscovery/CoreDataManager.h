//
//  CoreDataManager.h
//  MLearning
//
//  Created by Michele Noberasco on 06/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface CoreDataManager : NSObject {
@private
	NSPersistentStoreCoordinator *persistentStoreCoordinator;
	NSManagedObjectModel         *managedObjectModel;
}

+(CoreDataManager *)instance;

- (BOOL)needDataMigration;
- (void)initializeDatabaseContents;
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;

@end
