//
//  NetLogFile.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "NetLogFile.h"
#import "Jump.h"
#import "CoreDataManager.h"
#import "Commander.h"

@implementation NetLogFile

+ (NSArray *)netLogFilesForCommander:(Commander *)commander {
  NSManagedObjectContext *context = commander.managedObjectContext;
  __block NSArray        *array   = nil;
  
  [context performBlockAndWait:^{
    NSString            *className = NSStringFromClass(NetLogFile.class);
    NSFetchRequest      *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSPredicate         *predicate = [NSPredicate predicateWithFormat:@"commander == %@", commander];
    NSError             *error     = nil;
    
    request.entity                 = entity;
    request.predicate              = predicate;
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  }];
  
  return array;
}

+ (NetLogFile *)netLogFileWithPath:(NSString *)path inContext:(NSManagedObjectContext *)context {
  __block NSArray *array = nil;
  
  [context performBlockAndWait:^{
    NSString               *className = NSStringFromClass(NetLogFile.class);
    NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSPredicate            *predicate = [NSPredicate predicateWithFormat:@"path == %@", path];
    NSError                *error     = nil;
    
    request.entity                 = entity;
    request.predicate              = predicate;
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
    NSAssert2(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead (path %@)", (unsigned long)array.count, path);
  }];
  
  return array.lastObject;
}

@end
