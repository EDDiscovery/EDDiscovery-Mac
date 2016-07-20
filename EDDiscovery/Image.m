//
//  Image.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <objc/runtime.h>

#import "Image.h"
#import "System.h"
#import "Commander.h"
#import "Jump.h"

@implementation Image

+ (NSArray *)screenshotsForCommander:(Commander *)commander {
  NSManagedObjectContext *context = commander.managedObjectContext;
  __block NSArray        *array   = nil;
  
  [context performBlockAndWait:^{
    NSString            *className       = NSStringFromClass(Image.class);
    NSFetchRequest      *request         = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity          = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSPredicate         *predicate       = IMG_CMDR_PREDICATE;
    NSSortDescriptor    *sortDescriptor1 = [NSSortDescriptor sortDescriptorWithKey:@"jump.timestamp" ascending:YES];
    NSSortDescriptor    *sortDescriptor2 = [NSSortDescriptor sortDescriptorWithKey:@"path"           ascending:YES];
    NSError             *error           = nil;
    
    request.entity                 = entity;
    request.predicate              = predicate;
    request.sortDescriptors        = @[sortDescriptor1, sortDescriptor2];
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  }];
  
  return array;
}

+ (Image *)imageWithPath:(NSString *)path inContext:(NSManagedObjectContext *)context {
  __block NSArray *array = nil;
  
  [context performBlockAndWait:^{
    NSString               *className = NSStringFromClass(Image.class);
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

- (NSURL *)previewItemURL {
  static char dataKey;
  
  NSURL *url = objc_getAssociatedObject(self, &dataKey);
  
  if (url == nil) {
    url = [NSURL fileURLWithPath:self.path];
    
    objc_setAssociatedObject(self, &dataKey, url, OBJC_ASSOCIATION_RETAIN);
  }
  
  return url;
}

- (NSString *)previewItemTitle {
  return self.path;
}

@end
