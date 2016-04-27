//
//  System.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "System.h"
#import "Image.h"
#import "Jump.h"
#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "EventLogger.h"
#import "Distance.h"

@implementation System {
  NSArray *distanceSortDescriptors;
  NSArray *sortedDistances;
}

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

+ (NSMutableArray *)systemsWithNames:(NSArray *)names inContext:(NSManagedObjectContext *)context {
  NSString                 *className = NSStringFromClass([System class]);
  NSFetchRequest           *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription      *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSPredicate              *predicate = [NSPredicate predicateWithFormat:@"name IN %@", names];
  NSError                  *error     = nil;
  NSArray<System *>        *array     = nil;
  NSMutableArray<System *> *output    = [NSMutableArray array];
  
  request.entity                 = entity;
  request.predicate              = predicate;
  request.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
  request.returnsObjectsAsFaults = NO;
  request.includesPendingChanges = YES;
  
  array = [[context executeFetchRequest:request error:&error] mutableCopy];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  
  //catch duplicate objects, if any
  
  for (System *system in array) {
    if ([output.lastObject.name isEqualToString:system.name]) {
      NSAssert1(NO, @"this query should return at maximum 1 element per system name: got more instead (name %@)", system.name);
    }
    else {
      [output addObject:system];
    }
  }
  
  return output;
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
      NSString               *prevName   = 0;
      
      for (System *aSystem in systems) {
        [names addObject:aSystem.name];
      }
      
      response = [response sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
      
      for (NSDictionary *systemData in response) {
        NSString *name = systemData[@"name"];
        
        if (name.length > 0 && ![prevName isEqualToString:name]) {
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
          
          [system parseEDSMData:systemData parseDistances:YES save:NO];
          
          if (((numAdded % 1000) == 0 && numAdded != 0) || ((numUpdated % 1000) == 0 && numUpdated != 0)) {
            NSLog(@"Added %ld, updated %ld systems (%ld left to update)", (long)numAdded, (long)numUpdated, (long)systems.count);
          }
          
          prevName = name;
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

- (NSUInteger)numVisits {
  return self.jumps.count;
}

- (BOOL)hasCoordinates {
  return (self.x != 0 || self.y != 0 || self.z != 0 || [self.name compare:@"Sol" options:NSCaseInsensitiveSearch] == NSOrderedSame);
}

- (NSNumber *)distanceToSol {
  NSNumber *result = nil;
  
  if (self.hasCoordinates) {
    result = @(sqrt(self.x*self.x + self.y*self.y + self.z*self.z));
  }
  
  return result;
}

- (void)updateFromEDSM:(void(^__nullable)(void))resultBlock {
  [EDSMConnection getSystemInfo:self.name response:^(NSDictionary *response, NSError *error) {
    if (response != nil) {
      [self parseEDSMData:response parseDistances:YES save:YES];
    }
    
    if (resultBlock != nil) {
      resultBlock();
    }
  }];
}

- (void)parseEDSMData:(NSDictionary *)data parseDistances:(BOOL)parseDistances save:(BOOL)saveContext {
//  NSLog(@"%s: %@", __FUNCTION__, data);
  
  NSDictionary *coords = data[@"coords"];
  
  if ([coords isKindOfClass:NSDictionary.class]) {
    self.x = [coords[@"x"] doubleValue];
    self.y = [coords[@"y"] doubleValue];
    self.z = [coords[@"z"] doubleValue];
    
    if (saveContext) {
      NSLog(@"%@ has known coords: x=%f, y=%f, z=%f", self.name, self.x, self.y, self.z);
    }
  }
  
  if (parseDistances == YES) {
    NSArray *distances     = data[@"distances"];
    NSArray *problems      = data[@"problems"];
    NSSet   *currDistances = self.distances;
    
    for (Distance *distance in currDistances) {
      [self.managedObjectContext deleteObject:distance];
    }
    
    if ([distances isKindOfClass:NSArray.class]) {
      if (distances.count > 0) {
        NSLog(@"Got %ld distances from EDSM", (long)distances.count);
        
        for (NSDictionary *distanceData in distances) {
          NSString *name = distanceData[@"name"];
          double    dist = [distanceData[@"distance"] doubleValue];
          
          if (name.length > 0 && dist > 0) {
            NSString *className = NSStringFromClass(Distance.class);
            Distance *distance  = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:self.managedObjectContext];
            
            distance.distance           = dist;
            distance.calculatedDistance = dist;
            distance.name               = name;
            distance.system             = self;
            
            for (NSDictionary *problem in problems) {
              if ([problem isKindOfClass:NSDictionary.class]) {
                NSString *probName = problem[@"refsys"];
                
                if ([probName isEqualToString:name]) {
                  double calculated = [problem[@"calculated"] doubleValue];
                  
                  if (dist > 0) {
                    distance.calculatedDistance = calculated;
                  }
                }
              }
            }
          }
        }
      }
    }
    
    [self updateSortedDistances];
  }
  
  if (saveContext) {
    NSError *error = nil;
    
    [self.managedObjectContext save:&error];
  
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
    
      exit(-1);
    }
  }
}

- (NSArray *)distanceSortDescriptors {
  return distanceSortDescriptors;
}

- (void)setDistanceSortDescriptors:(NSArray *)newDistanceSortDescriptors {
  [self willChangeValueForKey:@"distanceSortDescriptors"];
  distanceSortDescriptors = newDistanceSortDescriptors;
  [self didChangeValueForKey:@"distanceSortDescriptors"];
  
  [self updateSortedDistances];
}

- (NSArray *)sortedDistances {
  if (sortedDistances == nil && self.distances.count > 0) {
    [self updateSortedDistances];
  }
  
  return sortedDistances;
}

- (void)updateSortedDistances {
  [self willChangeValueForKey:@"sortedDistances"];
  sortedDistances = [self.distances sortedArrayUsingDescriptors:self.distanceSortDescriptors];
  [self didChangeValueForKey:@"sortedDistances"];
}

@end
