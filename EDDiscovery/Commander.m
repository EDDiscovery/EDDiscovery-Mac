//
//  Commander.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 29/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "Commander.h"
#import "EDSM.h"
#import "NetLogFile.h"
#import "NetLogParser.h"
#import "Jump.h"
#import "EventLogger.h"
#import "ScreenshotMonitor.h"
#import "Image.h"

#define ACTIVE_COMMANDER_KEY @"activeCommanderKey"

@implementation Commander

#pragma mark -
#pragma mark active commander management

static Commander *activeCommander = nil;

+ (Commander *)activeCommander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if (activeCommander == nil) {
    NSString *name = [NSUserDefaults.standardUserDefaults objectForKey:ACTIVE_COMMANDER_KEY];
    
    if (name.length > 0) {
      activeCommander = [self commanderWithName:name];
    }
  }
  
  return activeCommander;
}

+ (void)setActiveCommander:(nullable Commander *)commander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if (activeCommander != nil) {
    [[NetLogParser instanceOrNil:activeCommander] stopInstance];
  }
  
  activeCommander = commander;
  
  if (commander.name.length > 0) {
    [NSUserDefaults.standardUserDefaults setObject:commander.name forKey:ACTIVE_COMMANDER_KEY];
  }
  else {
    [NSUserDefaults.standardUserDefaults removeObjectForKey:ACTIVE_COMMANDER_KEY];
  }
}

+ (Commander *)createCommanderWithName:(NSString *)name {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
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
    NSString *className   = NSStringFromClass(EDSM.class);
    EDSM     *edsmAccount = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:MAIN_CONTEXT];
    
    className = NSStringFromClass(Commander.class);
    commander = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:MAIN_CONTEXT];
    
    commander.name        = name;
    commander.edsmAccount = edsmAccount;
    
    [MAIN_CONTEXT save];
    
    self.activeCommander  = commander;
  }
  
  return commander;
}

#pragma mark -
#pragma mark active fetch commanders

+ (Commander *)commanderWithName:(NSString *)name {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  NSString               *className = NSStringFromClass([Commander class]);
  NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:MAIN_CONTEXT];
  NSError                *error     = nil;
  NSArray                *array     = nil;
  
  request.entity                 = entity;
  request.predicate              = [NSPredicate predicateWithFormat:@"name == %@", name];
  request.returnsObjectsAsFaults = NO;
  request.includesPendingChanges = YES;
  
  array = [MAIN_CONTEXT executeFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  NSAssert1(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead", (unsigned long)array.count);
  
  return array.lastObject;
}

+ (NSArray *)allCommanders {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  NSString               *className = NSStringFromClass([Commander class]);
  NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
  NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:MAIN_CONTEXT];
  NSError                *error     = nil;
  NSArray                *array     = nil;
  
  request.entity                 = entity;
  request.sortDescriptors        = @[[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]];
  request.returnsObjectsAsFaults = NO;
  request.includesPendingChanges = YES;
  
  array = [MAIN_CONTEXT executeFetchRequest:request error:&error];
  
  NSAssert1(error == nil, @"could not execute fetch request: %@", error);
  
  return array;
}

#pragma mark -
#pragma mark netlog dir changing

- (void)setNetLogFilesDir:(NSString *)newNetLogFilesDir completion:(void(^__nonnull)(void))completionBlock {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if (ARE_EQUAL(newNetLogFilesDir, self.netLogFilesDir)) {
    completionBlock();
    
    return;
  }
  else if (self.netLogFilesDir.length > 0) {
    [[NetLogParser instanceOrNil:self] stopInstance];

    //wipe all NetLogFile entities for this commander
    
    NSArray    *netLogFiles = [NetLogFile netLogFilesForCommander:self];
    NSUInteger  numJumps    = 0;
    
    for (NetLogFile *netLogFile in netLogFiles) {
      for (Jump *jump in netLogFile.jumps) {
        if (jump.edsm == nil) {
          [MAIN_CONTEXT deleteObject:jump];
          
          numJumps++;
        }
      }
      
      [MAIN_CONTEXT deleteObject:netLogFile];
    }
    
    [MAIN_CONTEXT save];
    
    [EventLogger addLog:[NSString stringWithFormat:@"Deleted %@ jumps from travel history", FORMAT(numJumps)]];
    
    NSLog(@"Deleted %ld netlog file records", (long)netLogFiles.count);
  }
    
  [self willChangeValueForKey:@"netLogFilesDir"];
  [self setPrimitiveValue:newNetLogFilesDir forKey:@"netLogFilesDir"];
  [self didChangeValueForKey:@"netLogFilesDir"];
  
  NetLogParser *netLogParser = [NetLogParser createInstanceForCommander:self];
  
  [netLogParser startInstance:^{
    [self.edsmAccount syncJumpsWithEDSM:^{
      completionBlock();
    }];
  }];
}

#pragma mark -
#pragma mark screenshot dir changing

- (void)setScreenshotsDir:(NSString *)newScreenshotsDir completion:(void(^__nonnull)(void))completionBlock {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if (ARE_EQUAL(newScreenshotsDir, self.screenshotsDir)) {
    completionBlock();
    
    return;
  }
  else if (self.screenshotsDir.length > 0) {
    [[ScreenshotMonitor instanceOrNil:self] stopInstance];
    
    //wipe all NetLogFile entities for this commander
    
    NSArray *screenshots = [Image screenshotsForCommander:self];
    
    for (Image *screenshot in screenshots) {
      [MAIN_CONTEXT deleteObject:screenshot];
    }
    
    [MAIN_CONTEXT save];
  }
  
  [self willChangeValueForKey:@"screenshotsDir"];
  [self setPrimitiveValue:newScreenshotsDir forKey:@"screenshotsDir"];
  [self didChangeValueForKey:@"screenshotsDir"];
  
  ScreenshotMonitor *screenshotMonitor = [ScreenshotMonitor createInstanceForCommander:self];
  
  [screenshotMonitor startInstance:^{
    completionBlock();
  }];
}

#pragma mark -
#pragma mark deletion

- (void)deleteCommander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  [[NetLogParser instanceOrNil:self] stopInstance];

  NSArray *jumps = [Jump allJumpsOfCommander:self];
  
  for (Jump *jump in jumps) {
    [jump.managedObjectContext deleteObject:jump];
  }

  NSLog(@"Deleted %@ jumps from travel history", FORMAT(jumps.count));
  
  self.edsmAccount.apiKey = nil;
  
  [self.managedObjectContext deleteObject:self];
  
  [self.managedObjectContext save];
}

@end
