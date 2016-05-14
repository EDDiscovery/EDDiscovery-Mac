//
//  NSManagedObjectContext+DeepSave.h
//  EDDiscovery
//
//  Created by thorin on 09/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@interface NSManagedObjectContext (Parenthood)

#define MAIN_CONTEXT NSManagedObjectContext.mainContext
#define WORK_CONTEXT NSManagedObjectContext.workContext

+ (NSManagedObjectContext *)mainContext;
+ (NSManagedObjectContext *)workContext;

- (void)save;

@end
