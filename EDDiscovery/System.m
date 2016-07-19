//
//  System.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <objc/runtime.h>

#import "System.h"
#import "Image.h"
#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "EventLogger.h"
#import "Commander.h"
#import "Distance.h"
#import "Note.h"
#import "EDSM.h"
#import "CoreDataManager.h"

#import "SuggestedReferences.h"
#import "Jump.h"
#import "ReferenceSystem.h"

@implementation System {
  NSArray        <NSSortDescriptor *> *distanceSortDescriptors;
  NSMutableArray <Distance         *> *sortedDistances;
  NSMutableArray <System           *> *suggestedReferences;
}

+ (void)printSystemStatsInContext:(NSManagedObjectContext *)context {
  [context performBlock:^{
    NSString            *className   = NSStringFromClass([System class]);
    NSFetchRequest      *request     = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity      = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSError             *error       = nil;
    NSUInteger           countTot    = 0;
    NSUInteger           countCoords = 0;
    
    request.entity                 = entity;
    request.returnsObjectsAsFaults = YES;
    request.includesPendingChanges = YES;
    
    countTot = [context countForFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
    
    request.predicate = [NSPredicate predicateWithFormat:@"name == %@ || x != 0 || y != 0 || z != 0", @"Sol"];
    
    countCoords = [context countForFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
    
    NSString *msg = [NSString stringWithFormat:@"DB contains %@ systems (%@ with known coords)", FORMAT(countTot), FORMAT(countCoords)];
    
    [EventLogger addLog:msg];
  }];
}

+ (NSArray *)allSystemsInContext:(NSManagedObjectContext *)context {
  __block NSArray *array = nil;
  
  [context performBlockAndWait:^{
    NSString            *className = NSStringFromClass([System class]);
    NSFetchRequest      *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSError             *error     = nil;
    
    request.entity                 = entity;
    request.returnsObjectsAsFaults = NO;
    request.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
  }];
  
  return array;
}

+ (NSArray *)systemsWithNames:(NSOrderedSet *)names inContext:(NSManagedObjectContext *)context {
  __block NSArray *array = nil;
  
  [context performBlockAndWait:^{
    NSString            *className = NSStringFromClass([System class]);
    NSFetchRequest      *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSError             *error     = nil;
    
    request.entity                 = entity;
    request.returnsObjectsAsFaults = NO;
    request.predicate              = [NSPredicate predicateWithFormat:@"name IN %@", names];
    request.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
  }];
  
  return array;
}

+ (System *)systemWithName:(NSString *)name inContext:(NSManagedObjectContext *)context {
  __block NSArray *array = nil;
  
  [context performBlockAndWait:^{
    NSString               *className = NSStringFromClass([System class]);
    NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSPredicate            *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
    NSError                *error     = nil;
    
    request.entity                 = entity;
    request.predicate              = predicate;
    request.returnsObjectsAsFaults = NO;
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
    NSAssert2(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead (name %@)", (unsigned long)array.count, name);
  }];
  
  return array.lastObject;
}

+ (void)updateSystemsFromEDSM:(void(^)(void))resultBlock {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  NSLog(@"%s", __FUNCTION__);
  
  LoadingViewController.textField.stringValue = NSLocalizedString(@"Receiving systems from EDSM", @"");
  
  LoadingViewController.progressIndicator.indeterminate = NO;
  LoadingViewController.progressIndicator.maxValue      = 1.0;
  LoadingViewController.progressIndicator.doubleValue   = 0.0;

  [EDSMConnection getSystemsInfoWithProgress:^(long long downloaded, long long total) {
    LoadingViewController.progressIndicator.doubleValue = (double)downloaded / (double)total;
  }
                                    response:^(NSArray *response, NSError *error) {
    if (response != nil) {
      [EventLogger addLog:[NSString stringWithFormat:@"Received %@ new systems from EDSM", FORMAT(response.count)]];
      
      [WORK_CONTEXT performBlock:^{
        NSUInteger           numAdded        = 0;
        NSUInteger           numUpdated      = 0;
        NSTimeInterval       ti              = [NSDate timeIntervalSinceReferenceDate];
        NSArray             *responseSystems = [response sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        NSMutableOrderedSet *responseNames   = [NSMutableOrderedSet orderedSetWithCapacity:responseSystems.count];
        NSArray             *localSystems    = nil;
        NSUInteger           idx             = 0;
        NSUInteger           progress        = 0;
        NSUInteger           step            = (responseSystems.count < 100) ? 1 : (responseSystems.count < 1000) ? 10 : 100;
        NSString            *name            = nil;
        NSString            *prevName        = nil;
        NSString            *className       = NSStringFromClass(System.class);
        
        for (NSDictionary *systemData in responseSystems) {
          name = systemData[@"name"];
          
          if (name.length > 0) {
            [responseNames addObject:name];
          }
        }
        
        localSystems = [System systemsWithNames:responseNames inContext:WORK_CONTEXT];
        
        [MAIN_CONTEXT performBlock:^{
          LoadingViewController.progressIndicator.indeterminate = NO;
          LoadingViewController.progressIndicator.maxValue      = responseSystems.count;
          LoadingViewController.progressIndicator.doubleValue   = 0;
        }];

        for (NSDictionary *systemData in responseSystems) {
          name = systemData[@"name"];
          
          if (name.length > 0 && ![prevName isEqualToString:name]) {
            System *system = (idx >= localSystems.count) ? nil : localSystems[idx];
            
            if ([system.name isEqualToString:name]) {
              idx++;
              numUpdated++;
            }
            else {
              system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
              
              system.name = name;
              
              numAdded++;
            }
            
            [system parseEDSMData:systemData parseDistances:NO save:NO];
            
            if (((numAdded % 1000) == 0 && numAdded != 0) || ((numUpdated % 1000) == 0 && numUpdated != 0)) {
              [EventLogger addLog:[NSString stringWithFormat:@"Added %@, updated %@ systems", FORMAT(numAdded), FORMAT(numUpdated)]];
            }
            
            if ((progress++ % step) == 0) {
              [MAIN_CONTEXT performBlock:^{
                LoadingViewController.progressIndicator.doubleValue = progress;
              }];
            }
            
            prevName = name;
          }
        }
        
        [WORK_CONTEXT save];
        
        [EventLogger addLog:[NSString stringWithFormat:@"Added %@, updated %@ systems in %.1f seconds", FORMAT(numAdded), FORMAT(numUpdated), ([NSDate timeIntervalSinceReferenceDate] - ti)]];
        
        [System printSystemStatsInContext:WORK_CONTEXT];
        
        [MAIN_CONTEXT performBlock:^{
          resultBlock();
        }];
      }];
    }
    else if (error != nil) {
      [EventLogger addError:[NSString stringWithFormat:@"%@: %ld - %@", ([error.domain isEqualToString:@"EDDiscovery"]) ? @"ERROR from EDSM" : @"NETWORK ERROR", (long)error.code, error.localizedDescription]];
      
      resultBlock();
    }
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
    [self.managedObjectContext performBlock:^{
      if (response != nil) {
        [self parseEDSMData:response parseDistances:YES save:YES];
      }
      
      if (resultBlock != nil) {
        resultBlock();
      }
    }];
  }];
}

- (void)parseEDSMData:(NSDictionary *)data parseDistances:(BOOL)parseDistances save:(BOOL)saveContext {
  NSManagedObjectContext *context = self.managedObjectContext;
  
  [context performBlockAndWait:^{
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
        [context deleteObject:distance];
      }
      
      if ([distances isKindOfClass:NSArray.class]) {
        if (distances.count > 0) {
          Distance *prevDistance = nil;
          
          NSLog(@"Got %ld distances from EDSM", (long)distances.count);
          
          distances = [distances sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
          
          for (NSDictionary *distanceData in distances) {
            NSString *name = distanceData[@"name"];
            NSNumber *dist = distanceData[@"distance"];
            
            if (name.length > 0 && dist > 0 && (prevDistance == nil || ![prevDistance.name isEqualToString:name] || prevDistance.distance != dist)) {
              NSString *className = NSStringFromClass(Distance.class);
              Distance *distance  = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
              
              distance.distance           = dist;
              distance.calculatedDistance = dist;
              distance.name               = name;
              distance.system             = self;
              
              for (NSDictionary *problem in problems) {
                if ([problem isKindOfClass:NSDictionary.class]) {
                  NSString *probName = problem[@"refsys"];
                  
                  if ([probName isEqualToString:name]) {
                    NSNumber *calculated = problem[@"calculated"];
                    
                    if (dist > 0) {
                      distance.calculatedDistance = calculated;
                    }
                  }
                }
              }
              
              //filter out known bad distances if a good alternative is available
              
              if ([prevDistance.name isEqualToString:name]) {
                if (prevDistance.distance != prevDistance.calculatedDistance && distance.distance == distance.calculatedDistance) {
                  [context deleteObject:prevDistance];
                }
                else if (prevDistance.distance == prevDistance.calculatedDistance && distance.distance != distance.calculatedDistance) {
                  [context deleteObject:distance];
                  
                  continue;
                }
              }
              
              prevDistance = distance;
            }
          }
        }
      }
      
      [self updateSortedDistances];
    }
    
    if (saveContext) {
      [context save];
    }
  }];
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

- (NSMutableArray <Distance *> *)sortedDistances {
  if (sortedDistances == nil && self.distances.count > 0) {
    [self updateSortedDistances];
  }
  
  return sortedDistances;
}

- (void)updateSortedDistances {
  [self willChangeValueForKey:@"sortedDistances"];
  
  sortedDistances = [[self.distances sortedArrayUsingDescriptors:self.distanceSortDescriptors] mutableCopy];
  
  [self didChangeValueForKey:@"sortedDistances"];
}

- (NSMutableArray <System *> *)suggestedReferences {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  @synchronized (self) {
    if (suggestedReferences == nil) {
      suggestedReferences = [NSMutableArray <System *> array];
      
      [self addSuggestedReferences];
    }
    
    return suggestedReferences;
  }
}

- (void)addSuggestedReferences {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  Commander         *commander   = Commander.activeCommander;
  Jump              *jump        = [Jump lastXYZJumpOfCommander:commander];
  System            *system      = jump.system;
  NSManagedObjectID *systemID    = system.objectID;
  NSManagedObjectID *commanderID = commander.objectID;
  
  NSLog(@"Latest visited system with known coordinates: %@", jump.system.name);
  
  [WORK_CONTEXT performBlock:^{
    static char referenceCalculatorKey;

    SuggestedReferences *referencesCalculator = objc_getAssociatedObject(self, &referenceCalculatorKey);
    
    if (referencesCalculator == nil) {
      System    *system    = [WORK_CONTEXT existingObjectWithID:systemID    error:nil];
      Commander *commander = [WORK_CONTEXT existingObjectWithID:commanderID error:nil];
      
      if (system != nil) {
        referencesCalculator = [[SuggestedReferences alloc] initWithLastKnownPosition:system];
        
        //feed already-known distances to calculator
        
        for (Distance *distance in system.distances) {
          System *system = [System systemWithName:distance.name inContext:WORK_CONTEXT];
          
          if (system.hasCoordinates == YES) {
            [referencesCalculator addReferenceStar:system];
          }
        }
        
        //add previous jump to results, if system has known coords and it has not been added already
        
        NSArray *jumps    = [Jump last:2 jumpsOfCommander:commander];
        Jump    *prevJump = (jumps.count > 1) ? jumps[1] : nil;
        
        if (prevJump != nil) {
          System *prevSystem = prevJump.system;
          
          if (prevSystem.hasCoordinates) {
            NSSet <Distance *> *filteredDistances = [system.distances filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"name == %@", prevSystem.name]];
            
            if (filteredDistances.count == 0) {
              [referencesCalculator addReferenceStar:prevSystem];
              
              NSManagedObjectID *prevSystemID = prevSystem.objectID;
              
              [MAIN_CONTEXT performBlock:^{
                System *prevSystem = [MAIN_CONTEXT existingObjectWithID:prevSystemID error:nil];
                
                if (prevSystem != nil) {
                  [suggestedReferences addObject:prevSystem];
                }
              }];
            }
          }
        }
        
        objc_setAssociatedObject(self, &referenceCalculatorKey, referencesCalculator, OBJC_ASSOCIATION_RETAIN);
      }
    }
    
    if (referencesCalculator != nil) {
      int count = 16;
      
      for (int ii = 0; ii < count; ii++) {
        ReferenceSystem *referenceSystem = [referencesCalculator getCandidate];
        
        if (referenceSystem == nil) {
          break;
        }
        
        System            *system   = referenceSystem.system;
        NSManagedObjectID *systemID = system.objectID;
        
        if (systemID != nil) {
          NSLog(@"\tFound suggested reference system: %@ Dist:%.2f x:%f y:%f z:%f", system.name, referenceSystem.distance, system.x, system.y, system.z);
          
          [MAIN_CONTEXT performBlock:^{
            System *system = [MAIN_CONTEXT existingObjectWithID:systemID error:nil];
          
            if (system != nil && self.isFault == NO) {
              [self willChangeValueForKey:@"suggestedReferences"];
              [suggestedReferences addObject:system];
              [self didChangeValueForKey:@"suggestedReferences"];
            }
          }];
          
          [referencesCalculator addReferenceStar:system];
        }
      }
      
      [Answers logCustomEventWithName:@"Suggested reference systems" customAttributes:nil];
    }
  }];
}

- (NSString *)note {
  NSAssert(NSThread.isMainThread, @"Must be on main thread");
  NSAssert([self.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  NSAssert(Commander.activeCommander != nil, @"must have an active commander");

  Commander *commander = Commander.activeCommander;
  Note      *note      = [Note noteForSystem:self commander:commander];
  
  return note.note;
}

- (void)setNote:(NSString *)newNote {
  NSAssert(NSThread.isMainThread, @"Must be on main thread");
  NSAssert([self.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  NSAssert(Commander.activeCommander != nil, @"must have an active commander");

  [self willChangeValueForKey:@"note"];
  
  Commander *commander = Commander.activeCommander;
  Note      *note      = [Note noteForSystem:self commander:commander];
  BOOL       save      = NO;
  
  if (note == nil) {
    NSString *className = NSStringFromClass(Note.class);
    
    note = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:MAIN_CONTEXT];
    
    note.edsm   = commander.edsmAccount;
    note.system = self;
  }
  
  if ([note.note isEqualToString:newNote] == NO) {
    note.note = newNote;
    
    save = YES;
  }
  
  if (save == YES) {
    [MAIN_CONTEXT save];
    
    [commander.edsmAccount sendNoteToEDSM:newNote forSystem:self.name];
  }
  
  [self didChangeValueForKey:@"note"];
}

@end
