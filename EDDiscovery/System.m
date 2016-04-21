//
//  System.m
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "System.h"
#import "Image.h"
#import "Jump.h"
#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "EventLogger.h"

@implementation System

+ (NSArray *)allSystemsInContext:(NSManagedObjectContext *)context {
  NSString            *className = NSStringFromClass([System class]);
  NSFetchRequest      *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSError             *error     = nil;
  NSArray             *array     = nil;
  
  request.entity                 = entity;
  request.returnsObjectsAsFaults = NO;
  request.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
  request.includesPendingChanges = YES;
  
  array = [context executeFetchRequest:request error:&error];
  
  return array;
}

+ (System *)systemWithName:(NSString *)name inContext:(NSManagedObjectContext *)context {
  NSString            *className = NSStringFromClass([System class]);
  NSFetchRequest      *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSPredicate         *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
  NSError             *error     = nil;
  NSArray             *array     = nil;
  
  request.entity                 = entity;
  request.predicate              = predicate;
  request.returnsObjectsAsFaults = NO;
  request.includesPendingChanges = YES;
  
  array = [context executeFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  NSAssert2(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead (name %@)", (unsigned long)array.count, name);
  
  return array.lastObject;
}

+ (void)updateSystemsFromEDSM:(void(^)(void))resultBlock {
  NSLog(@"%s", __FUNCTION__);
  
  [EDSMConnection getSystemsInfoWithResponse:^(NSArray *response, NSError *error) {
    if (response != nil) {
      [EventLogger addLog:[NSString stringWithFormat:@"Received %ld new systems from EDSM", (long)response.count]];
      
      NSManagedObjectContext *context    = CoreDataManager.instance.managedObjectContext;
      NSMutableArray         *systems    = [[self allSystemsInContext:context] mutableCopy];
      NSMutableArray         *names      = [NSMutableArray arrayWithCapacity:systems.count];
      NSUInteger              numAdded   = 0;
      NSUInteger              numUpdated = 0;
      NSTimeInterval          ti         = [NSDate timeIntervalSinceReferenceDate];
      
      for (System *aSystem in systems) {
        [names addObject:aSystem.name];
      }
      
      response = [response sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
      
      for (NSDictionary *systemData in response) {
        NSString *name = systemData[@"name"];
        
        if (name.length > 0) {
          System *system = nil;
          
          NSUInteger idx = [names indexOfObject:name];
          
          if (idx != NSNotFound) {
            system = systems[idx];
            
            [systems removeObjectAtIndex:idx];
            [names removeObjectAtIndex:idx];
          }
          
          if (system == nil) {
            NSString *className = NSStringFromClass(System.class);
            
            system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
            
            system.name = name;
            
            numAdded++;
          }
          else {
            numUpdated++;
          }
          
          [system parseEDSMData:systemData save:NO];
          
          if (((numAdded % 1000) == 0 && numAdded != 0) || ((numUpdated % 1000) == 0 && numUpdated != 0)) {
            NSLog(@"Added %ld, updated %ld systems (%ld left to update)", (long)numAdded, (long)numUpdated, (long)systems.count);
          }
        }
      }
      
      NSError *error = nil;
      
      [context save:&error];
      
      if (error != nil) {
        NSLog(@"ERROR saving context: %@", error);
        
        exit(-1);
      }
      
      ti = [NSDate timeIntervalSinceReferenceDate] - ti;
      
      NSLog(@"Added %ld, updated %ld systems in %.1f seconds", (long)numAdded, (long)numUpdated, ti);
    }
    else if (error != nil) {
      NSLog(@"%s: ERROR: %@", __FUNCTION__, error.localizedDescription);
    }
    
    resultBlock();
  }];
}

- (BOOL)haveCoordinates {
  return (self.x != 0 || self.y != 0 || self.z != 0 || [self.name compare:@"Sol" options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (void)parseEDSMData:(NSDictionary *)data {
  [self parseEDSMData:data save:YES];
}

- (void)parseEDSMData:(NSDictionary *)data save:(BOOL)saveContext {
//  NSLog(@"%s: %@", __FUNCTION__, data);
  
  NSDictionary *coords    = data[@"coords"];
//  NSArray      *distances = data[@"distances"];
  
  if ([coords isKindOfClass:NSDictionary.class]) {
    self.x = [coords[@"x"] doubleValue];
    self.y = [coords[@"y"] doubleValue];
    self.z = [coords[@"z"] doubleValue];
    
    if (saveContext) {
      NSLog(@"%@ has known coords: x=%f, y=%f, z=%f", self.name, self.x, self.y, self.z);
    }
  }
  
//  if ([distances isKindOfClass:NSArray.class]) {
//    for (NSDictionary *distanceData in distances) {
//      NSString *name = distanceData[@"name"];
//      double    dist = [distanceData[@"distance"] doubleValue];
//      
//      if (name.length > 0 && dist > 0) {
//        Distance *distance = nil;
//        
//        for (Distance *aDistance in self.distances) {
//          NSArray *systems = aDistance.systems.allObjects;
//          System  *system1 = systems.firstObject;
//          System  *system2 = systems.lastObject;
//          
//          if ([system1.name compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame ||
//              [system2.name compare:name options:NSCaseInsensitiveSearch] == NSOrderedSame) {
//            distance = aDistance;
//            
//            break;
//          }
//        }
//        
//        if (distance == nil) {
//          NSString *className = NSStringFromClass(Distance.class);
//          System   *system    = [System systemWithName:name inContext:self.managedObjectContext];
//          
//          if (system == nil) {
//            NSString *className = NSStringFromClass(System.class);
//            
//            system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:self.managedObjectContext];
//            
//            system.name = name;
//          }
//          
//          distance = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:self.managedObjectContext];
//
//          [distance addSystemsObject:self];
//          [distance addSystemsObject:system];
//        }
//        
//        distance.distance = dist;
//
//        if (saveContext) {
//          NSLog(@"%@ <== %f ==> %@", self.name, dist, name);
//        }
//      }
//    }
//  }
  
  if (saveContext) {
    NSError *error = nil;
    
    [self.managedObjectContext save:&error];
  
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
    
      exit(-1);
    }
  }
}

@end
