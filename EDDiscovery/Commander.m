//
//  Commander.m
//  EDDiscovery
//
//  Created by thorin on 29/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Commander.h"
#import "EDSM.h"
#import "NetLogFile.h"
#import "CoreDataManager.h"

#define ACTIVE_COMMANDER_KEY @"activeCommanderKey"

@implementation Commander

#pragma mark -
#pragma mark active commander management

- (NSString *)pippo {
  return [NSString stringWithFormat:@"%@ - pippo", self.name];
}

static Commander *activeCommander = nil;

+ (Commander *)activeCommander {
  if (activeCommander == nil) {
    NSString *name = [NSUserDefaults.standardUserDefaults objectForKey:ACTIVE_COMMANDER_KEY];
    
    if (name.length > 0) {
      activeCommander = [self commanderWithName:name];
    }
  }
  
  return activeCommander;
}

+ (void)setActiveCommander:(Commander *)commander {
  activeCommander = commander;
  
  [NSUserDefaults.standardUserDefaults setObject:commander.name forKey:ACTIVE_COMMANDER_KEY];
}

+ (Commander *)createCommanderWithName:(NSString *)name {
  Commander *commander = [self commanderWithName:name];
  
  if (commander != nil) {
    NSAlert *alert = [[NSAlert alloc] init];
    
    alert.messageText = NSLocalizedString(@"A commander with the same name already exists", @"");
    alert.informativeText = NSLocalizedString(@"Plase select a different name", @"");
    
    [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
    
    [alert runModal];
    
    commander = nil;
  }
  else {
    NSManagedObjectContext *context     = CoreDataManager.instance.managedObjectContext;;
    NSString               *className   = NSStringFromClass(EDSM.class);
    EDSM                   *edsmAccount = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    NSError                *error       = nil;
    
    className = NSStringFromClass(Commander.class);
    commander = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    
    commander.name        = name;
    commander.edsmAccount = edsmAccount;
    
    [context save:&error];
    
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
      
      exit(-1);
    }
    
    self.activeCommander = commander;
  }
  
  return commander;
}

#pragma mark -
#pragma mark active fetch commanders

+ (Commander *)commanderWithName:(NSString *)name {
  NSManagedObjectContext *context   = CoreDataManager.instance.managedObjectContext;;
  NSString               *className = NSStringFromClass([Commander class]);
  NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSError                *error     = nil;
  NSArray                *array     = nil;
  
  request.entity                 = entity;
  request.predicate              = [NSPredicate predicateWithFormat:@"name == %@", name];
  request.returnsObjectsAsFaults = NO;
  request.includesPendingChanges = YES;
  
  array = [context executeFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  NSAssert1(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead", (unsigned long)array.count);
  
  return array.lastObject;
}

+ (NSArray *)commanders {
  NSManagedObjectContext *context   = CoreDataManager.instance.managedObjectContext;;
  NSString               *className = NSStringFromClass([Commander class]);
  NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
  NSError                *error     = nil;
  NSArray                *array     = nil;
  
  request.entity                 = entity;
  request.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
  request.returnsObjectsAsFaults = NO;
  request.includesPendingChanges = YES;
  
  array = [context executeFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  NSAssert1(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead", (unsigned long)array.count);
  
  return array.lastObject;
}

@end
