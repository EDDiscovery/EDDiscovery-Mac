//
//  NetLogFile.m
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "NetLogFile.h"
#import "Jump.h"

@implementation NetLogFile

+ (NetLogFile *)netLogFileWithPath:(NSString *)path inContext:(NSManagedObjectContext *)context {
  NSString            *className = NSStringFromClass([NetLogFile class]);
  NSFetchRequest      *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSPredicate         *predicate = [NSPredicate predicateWithFormat:@"path == %@", path];
  NSError             *error     = nil;
  NSArray             *array     = nil;
  
  request.entity    = entity;
  request.predicate = predicate;
  
  array = [context executeFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  NSAssert2(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead (path %@)", (unsigned long)array.count, path);
  
  return array.lastObject;
}

@end
