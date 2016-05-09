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
  NSManagedObjectContext              *bgContext;
}

+ (void)printStats {
  NSManagedObjectContext *context     = CoreDataManager.instance.mainContext;
  NSString               *className   = NSStringFromClass([System class]);
  NSFetchRequest         *request     = [[NSFetchRequest alloc] init];
  NSEntityDescription    *entity      = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSError                *error       = nil;
  NSUInteger              countTot    = 0;
  NSUInteger              countCoords = 0;
  
  request.entity                 = entity;
  request.returnsObjectsAsFaults = YES;
  request.includesPendingChanges = YES;
  
  countTot = [context countForFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  
  request.predicate = [NSPredicate predicateWithFormat:@"name == %@ || x != 0 || y != 0 || z != 0", @"Sol"];
  
  countCoords = [context countForFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  
  NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
  
  numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
  numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;
  
  NSString *msg = [NSString stringWithFormat:@"DB contains %@ systems (%@ with known coords)", [numberFormatter stringFromNumber:@(countTot)], [numberFormatter stringFromNumber:@(countCoords)]];
  
  [EventLogger addLog:msg];
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
  NSString               *className = NSStringFromClass([System class]);
  NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSPredicate            *predicate = [NSPredicate predicateWithFormat:@"name == %@", name];
  NSError                *error     = nil;
  NSArray                *array     = nil;
  
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
  
  LoadingViewController.loadingViewController.textField.stringValue = NSLocalizedString(@"Syncing systems with EDSM", @"");
  
  [EDSMConnection getSystemsInfoWithResponse:^(NSArray *response, NSError *error) {
    if (response != nil) {
      NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
      
      numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
      numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;

      [EventLogger addLog:[NSString stringWithFormat:@"Received %@ new systems from EDSM", [numberFormatter stringFromNumber:@(response.count)]]];
      
      [CoreDataManager.instance.mainContext performBlock:^{
        NSMutableArray         *systems    = [[self allSystemsInContext:CoreDataManager.instance.mainContext] mutableCopy];
        NSMutableArray         *names      = [NSMutableArray arrayWithCapacity:systems.count];
        NSUInteger              numAdded   = 0;
        NSUInteger              numUpdated = 0;
        NSTimeInterval          ti         = [NSDate timeIntervalSinceReferenceDate];
        NSString               *prevName   = 0;
        
        NSLog(@"Have %ld systems in local DB", (long)systems.count);
        
        for (System *aSystem in systems) {
          [names addObject:aSystem.name];
        }
        
        NSArray *responseSystems = [response sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
        
        for (NSDictionary *systemData in responseSystems) {
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
              
              system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:CoreDataManager.instance.mainContext];
              
              system.name = name;
              
              numAdded++;
            }
            else {
              numUpdated++;
            }
            
            [system parseEDSMData:systemData parseDistances:NO save:NO];
            
            if (((numAdded % 1000) == 0 && numAdded != 0) || ((numUpdated % 1000) == 0 && numUpdated != 0)) {
              NSLog(@"Added %ld, updated %ld systems", (long)numAdded, (long)numUpdated);
            }
            
            prevName = name;
          }
        }
        
        NSError *error = nil;
        
        [CoreDataManager.instance.mainContext save:&error];
        
        if (error != nil) {
          NSLog(@"ERROR saving context: %@", error);
          
          exit(-1);
        }
        
        NSLog(@"Added %ld, updated %ld systems in %.1f seconds", (long)numAdded, (long)numUpdated, ([NSDate timeIntervalSinceReferenceDate] - ti));
        
        [self printStats];
        
        resultBlock();
      }];
    }
    else if (error != nil) {
      NSLog(@"%s: ERROR: %@", __FUNCTION__, error.localizedDescription);
      
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
  
  [self.managedObjectContext performBlockAndWait:^{
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
          Distance *prevDistance = nil;
          
          NSLog(@"Got %ld distances from EDSM", (long)distances.count);
          
          distances = [distances sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
          
          for (NSDictionary *distanceData in distances) {
            NSString *name = distanceData[@"name"];
            NSNumber *dist = distanceData[@"distance"];
            
            if (name.length > 0 && dist > 0 && (prevDistance == nil || ![prevDistance.name isEqualToString:name] || prevDistance.distance != dist)) {
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
                  [self.managedObjectContext deleteObject:prevDistance];
                }
                else if (prevDistance.distance == prevDistance.calculatedDistance && distance.distance != distance.calculatedDistance) {
                  [self.managedObjectContext deleteObject:distance];
                  
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
      NSError *error = nil;
      
      [self.managedObjectContext save:&error];
      
      if (error != nil) {
        NSLog(@"ERROR saving context: %@", error);
        
        exit(-1);
      }
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
  @synchronized (self) {
    if (suggestedReferences == nil) {
      suggestedReferences = [NSMutableArray <System *> array];
      
      [self addSuggestedReferences];
    }
    
    return suggestedReferences;
  }
}

- (void)addSuggestedReferences {
  Commander         *commander   = Commander.activeCommander;
  Jump              *jump        = [Jump lastXYZJumpOfCommander:commander];
  System            *system      = jump.system;
  NSManagedObjectID *systemID    = system.objectID;
  NSManagedObjectID *commanderID = commander.objectID;
  
  NSLog(@"Latest visited system with known coordinates: %@", jump.system.name);
  
  if (bgContext == nil) {
    bgContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
  
    [bgContext setParentContext:self.managedObjectContext];
  }
  
  [bgContext performBlock:^{
    static char referenceCalculatorKey;

    SuggestedReferences *referencesCalculator = objc_getAssociatedObject(bgContext, &referenceCalculatorKey);
    
    if (referencesCalculator == nil) {
      System    *system    = [bgContext existingObjectWithID:systemID    error:nil];
      Commander *commander = [bgContext existingObjectWithID:commanderID error:nil];
      
      if (system != nil) {
        referencesCalculator = [[SuggestedReferences alloc] initWithLastKnownPosition:system];
        
        //feed already-known distances to calculator
        
        for (Distance *distance in system.distances) {
          System *system = [System systemWithName:distance.name inContext:bgContext];
          
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
              
              [suggestedReferences addObject:prevSystem];
            }
          }
        }
        
        objc_setAssociatedObject(bgContext, &referenceCalculatorKey, referencesCalculator, OBJC_ASSOCIATION_RETAIN);
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
        
        NSLog(@"\tFound suggested reference system: %@ Dist:%.2f x:%f y:%f z:%f", system.name, referenceSystem.distance, system.x, system.y, system.z);
        
        [bgContext.parentContext performBlock:^{
          System *system = [bgContext.parentContext existingObjectWithID:systemID error:nil];
        
          [self willChangeValueForKey:@"suggestedReferences"];
          [suggestedReferences addObject:system];
          [self didChangeValueForKey:@"suggestedReferences"];
        }];
        
        [referencesCalculator addReferenceStar:system];
      }
      
      [Answers logCustomEventWithName:@"Suggested reference systems" customAttributes:nil];
    }
  }];
}

- (NSString *)note {
  NSAssert(Commander.activeCommander != nil, @"must have an active commander");

  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"edsm.commander == %@", Commander.activeCommander];
  NSSet       *notes     = [self.notes filteredSetUsingPredicate:predicate];
  Note        *note      = notes.anyObject;
  
  if (notes.count > 1) {
    NSArray *array = [notes allObjects];
    
    for (NSUInteger i=0; i<(array.count - 1); i++) {
      Note *note = array[i];
      
      [note.managedObjectContext deleteObject:note];
    }
    
    note = array.lastObject;
  }
  
  return note.note;
}

- (void)setNote:(NSString *)newNote {
  NSAssert(Commander.activeCommander != nil, @"must have an active commander");

  [self willChangeValueForKey:@"note"];
  
  NSManagedObjectContext *context   = Commander.activeCommander.managedObjectContext;
  NSPredicate            *predicate = [NSPredicate predicateWithFormat:@"edsm.commander == %@", Commander.activeCommander];
  NSSet                  *notes     = [self.notes filteredSetUsingPredicate:predicate];
  Note                   *note      = notes.anyObject;
  NSError                *error     = nil;
  BOOL                    save      = NO;
  
  NSAssert(notes.count < 2, @"Cannot have more than 1 note");

  if (note == nil) {
    NSString *className = NSStringFromClass(Note.class);
    
    note = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    
    note.edsm   = Commander.activeCommander.edsmAccount;
    note.system = self;
  }
  
  if ([note.note isEqualToString:newNote] == NO) {
    note.note = newNote;
    
    save = YES;
  }
  
  if (save == YES) {
    [context save:&error];
    
    if (error != nil) {
      NSLog(@"%s: ERROR: cannot save context: %@", __FUNCTION__, error);
      exit(-1);
    }
    
    [Commander.activeCommander.edsmAccount sendNoteToEDSM:newNote forSystem:self.name];
  }
  
  [self didChangeValueForKey:@"note"];
}

@end
