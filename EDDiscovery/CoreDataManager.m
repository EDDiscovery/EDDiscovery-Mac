//
//  CoreDataManager.m
//  MLearning
//
//  Created by thorin on 06/10/09.
//  Copyright 2009 __MyCompanyName__. All rights reserved.
//

#import "CoreDataManager.h"
#import "DBVersion.h"

#define kDefaultDBVersion 0
#define kCurrentDBVersion 1

@interface CoreDataManager (Private)

- (id)initInstance;

@property (nonatomic, retain, readonly) NSPersistentStoreCoordinator *persistentStoreCoordinator;
@property (nonatomic, retain, readonly) NSManagedObjectModel         *managedObjectModel;
@property (nonatomic, assign)           NSUInteger                    dbVersion;

@end

@implementation CoreDataManager

#pragma mark -
#pragma mark Public static methods

+(CoreDataManager *)instance {
	@synchronized([self class]) {
    static CoreDataManager *instance = nil;
    
		if (!instance)
			instance = [[CoreDataManager alloc] initInstance];
    
    return instance;
	}
}

#pragma mark -
#pragma mark memory management

-(id)init {
	NSAssert(0, @"Error: this class should never be instantiated directly!");
	return nil;
}

- (id)initInstance {
	if ((self = [super init])) {
	}
	return self;	
}

-(void)dealloc {
	[persistentStoreCoordinator release];
	persistentStoreCoordinator = nil;
	
	[managedObjectModel release];
	managedObjectModel = nil;
	
	[super dealloc];
}

#pragma mark -
#pragma mark core data management

- (BOOL)needDataMigration {
  NSString                     *path        = [CoreDataManager dbPathName];
  NSURL                        *storeUrl    = [NSURL fileURLWithPath:path];
  NSError                      *error       = nil;
  NSDictionary                 *options     = [NSDictionary dictionaryWithObjectsAndKeys:
																							 [NSNumber numberWithBool:NO],  NSMigratePersistentStoresAutomaticallyOption,
                                               [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
                                               nil];
  NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
  BOOL                          result      = NO;
  
  if (![coordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error]) {
    result = YES;
  }
  
  [coordinator release];
  
  return result;
}

-(void)initializeDatabaseContents {
  NSUInteger dbVersion = kCurrentDBVersion;
  
  @try {
    dbVersion = self.dbVersion;
  }
  @catch (NSException *e) {
    NSString *msg = [NSString stringWithFormat:@"%@\n\n%@", NSLocalizedString(@"Could not access application data base. This is a critical failure, please contact customer care. EasyTrails will now quit to prevent data loss.", @""), e.reason];

    NSLog(@"ERROR: %@", msg);
    
//    [self showAlertControllerWithTitle:NSLocalizedString(@"Error", @"")
//                               message:msg
//                                 style:UIAlertControllerStyleAlert
//                               actions:@[MakeAction(NSLocalizedString(@"OK", @""), UIAlertActionStyleDestructive, nil, ^{
//                                        exit(-1);
//                                      })]];
    
    return;
  }
	
//  //force re-execution of a particular upgrade step (and subsequent ones)
//#ifdef DEBUG
//  #warning !!!REMOVE ME!!!
//#else
//  #error !!!REMOVE ME!!!
//#endif
//#if TARGET_IPHONE_SIMULATOR
//  dbVersion = (dbVersion == kCurrentDBVersion) ? (kCurrentDBVersion - 1) : dbVersion;
//#endif
  
	if (dbVersion < kCurrentDBVersion) {
		NSLog(@"CoreDataManager: updating database from version %lu to version to %d", (unsigned long)dbVersion, kCurrentDBVersion);
		
    switch (dbVersion) {
      case kDefaultDBVersion: {
        //fall through
      }
    }

		self.dbVersion = kCurrentDBVersion;
    
		NSLog(@"database update complete");
	}
	else {
		NSLog(@"database version is up to date");
	}
}

// Returns a new instance of the managed object context for the application.
- (NSManagedObjectContext *) managedObjectContext {
	NSManagedObjectContext       *managedObjectContext = nil;
	NSPersistentStoreCoordinator *coordinator          = self.persistentStoreCoordinator;
		
	if (coordinator != nil) {
		managedObjectContext = [[NSManagedObjectContext alloc] init];
		[managedObjectContext setPersistentStoreCoordinator:coordinator];
	}
	
	return [managedObjectContext autorelease];
}

// Returns the managed object model for the application.
// If the model doesn't already exist, it is created by merging all of the models found in the application bundle.
- (NSManagedObjectModel *)managedObjectModel {
	if (managedObjectModel == nil)
		managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles:nil] retain];
	
	return managedObjectModel;
}

// Returns the persistent store coordinator for the application.
// If the coordinator doesn't already exist, it is created and the application's store added to it.
- (NSPersistentStoreCoordinator *)persistentStoreCoordinator {
	if (persistentStoreCoordinator == nil) {
		NSString                   *path        = [CoreDataManager dbPathName];
		NSURL                      *storeUrl    = [NSURL fileURLWithPath:path];
		NSError                    *error       = nil;
		NSDictionary               *options     = [NSDictionary dictionaryWithObjectsAndKeys:
																							 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
																							 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption,
																							 nil];
		
		persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
		
		if (![persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeUrl options:options error:&error]) {
			NSLog(@"error initializing persistent store coordinator: %@", error);
			NSLog(@"error userinfo: %@", [error userInfo]);
      
      @throw [NSException exceptionWithName:@"EasyTrailsException"
                                     reason:error.localizedDescription
                                   userInfo:nil];
		}
	}
	
	return persistentStoreCoordinator;
}

+(NSString *)dbPathName {
  NSArray  *paths   = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
  NSString *dataDir = ([paths count] > 0) ? [paths objectAtIndex:0] : nil;
  NSString *path    = [dataDir stringByAppendingPathComponent:@"EDDiscoveryData.sqlite"];
  
  return path;
}

#pragma mark -
#pragma mark DB version management

- (NSUInteger)dbVersion {
	NSUInteger  output    = kDefaultDBVersion;
	DBVersion  *dbVersion = [self dbVersionInstance];
	
	if (dbVersion != nil)
		output = dbVersion.dbVersion;
	
	return output;
}

- (void)setDbVersion:(NSUInteger)version {
	DBVersion *dbVersion = [self dbVersionInstance];
  NSError   *error     = nil;
	
	if (dbVersion == nil) {
    NSManagedObjectContext *context = self.managedObjectContext;
    
		dbVersion = [NSEntityDescription insertNewObjectForEntityForName:@"DBVersion" inManagedObjectContext:context];
  }
	
	dbVersion.dbVersion = version;
	
	[dbVersion.managedObjectContext save:&error];
  
  if (error != nil) {
    NSLog(@"%s: ERROR: cannot save context: %@", __FUNCTION__, error);
    exit(-1);
  }
}

- (DBVersion *)dbVersionInstance {
  NSManagedObjectContext *context   = self.managedObjectContext;
	NSFetchRequest         *request   = [[[NSFetchRequest alloc] init] autorelease];
	NSEntityDescription    *entity    = [NSEntityDescription entityForName:@"DBVersion" inManagedObjectContext:context];
	NSError                *error     = nil;
	NSArray                *array     = nil;
  DBVersion              *dbVersion = nil;
  
	[request setEntity:entity];
	
	array = [[context executeFetchRequest:request error:&error] retain];
	
	if (error != nil) {
		NSLog(@"%s: ERROR: could not execute fetch request: %@", __FUNCTION__, error);
    exit(-1);
	}
  
  NSAssert1(array.count <= 1, @"Expected at most 1 element, got %lu instead!", (unsigned long)array.count);
	
  if (array.count > 0)
    dbVersion = [array objectAtIndex:0];
  
	return dbVersion;
}

@end
