//
//  EDSM.m
//  EDDiscovery
//
//  Created by thorin on 19/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "EDSM.h"
#import "Jump.h"
#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "EventLogger.h"

#ifdef DEBUG
#warning TODO: replace with non-hardcoded data!
#else
#error TODO: replace with non-hardcoded data!
#endif
#define CMDR_NAME    @"<your-cmdr-name>"
#define CMDR_API_KEY @"<your-api-key>"
#error insert your commander data

@implementation EDSM

+ (EDSM *)instance {
  static EDSM *instance = nil;
  
  if (instance == nil) {
    NSManagedObjectContext *context   = CoreDataManager.instance.managedObjectContext;;
    NSString               *className = NSStringFromClass([EDSM class]);
    NSFetchRequest         *request   = [[NSFetchRequest alloc] init];
    NSEntityDescription    *entity    = [NSEntityDescription entityForName:className inManagedObjectContext:context];
    NSError                *error     = nil;
    NSArray                *array     = nil;
    
    request.entity                 = entity;
    request.returnsObjectsAsFaults = NO;
    request.includesPendingChanges = YES;
    
    array = [context executeFetchRequest:request error:&error];
    
    NSAssert1(error == nil, @"could not execute fetch request: %@", error);
    NSAssert1(array.count <= 1, @"this query should return at maximum 1 element: got %lu instead", (unsigned long)array.count);
    
    instance = array.lastObject;
  }
  
  if (instance == nil) {
    NSManagedObjectContext *context   = CoreDataManager.instance.managedObjectContext;;
    NSString               *className = NSStringFromClass([EDSM class]);
    NSError                *error     = nil;
    
    instance = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    
    instance.commander = CMDR_NAME;
    
    [context save:&error];
    
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
      
      exit(-1);
    }
  }
  
  return instance;
}

- (NSString *)apiKey {
  return CMDR_API_KEY;
}

- (void)setApiKey:(NSString *)apiKey {
  NSLog(@"!!!TODO!!!");
}

- (void)syncJumpsWithEDSM {
  [EDSMConnection getJumpsForCommander:self.commander
                                apiKey:self.apiKey
                              response:^(NSArray *travelLogs, NSError *connectionError) {
                                
                                if (![travelLogs isKindOfClass:NSArray.class]) {
                                  NSLog(@"ERROR from EDSM: %ld - %@", (long)connectionError.code, connectionError.localizedDescription);
                                        
                                  [Jump printStats];
                                        
                                  return;
                                }
    
                                NSArray         *allJumps         = [Jump getAllJumpsInContext:self.managedObjectContext];
                                NSMutableArray  *jumps            = [allJumps mutableCopy];
                                NSString        *prevSystem       = nil;
                                NSTimeInterval   prevTimestamp    = 0;
                                NSMutableArray  *newJumpsFromEDSM = [NSMutableArray array];
                                NSDateFormatter *formatter        = [[NSDateFormatter alloc] init];
                                
                                formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
                                formatter.timeZone   = [NSTimeZone timeZoneWithName:@"UTC"];
                                
                                //try to match netLog entries with EDSM entries
                                
                                for (NSDictionary *log in [travelLogs reverseObjectEnumerator]) {
                                  NSString       *system    = log[@"system"];
                                  NSTimeInterval  timestamp = [[formatter dateFromString:log[@"date"]] timeIntervalSinceReferenceDate];
                                  BOOL            found     = NO;
                                  
                                  //NSLog(@"EDSM jump: %@ - %@", system, [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp]);
                                  
                                  if ([system isEqualToString:prevSystem] && timestamp == prevTimestamp) {
                                    //duplicate records on EDSM are a thing, apparently
                                    
                                    [EventLogger addLog:[NSString stringWithFormat:@"Duplicate system found on EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp], system]];
                                    
                                    continue;
                                  }
                                  
                                  //find a match in netLogs for current EDSM record
                                  
                                  for (NSUInteger i=0; i<jumps.count; i++) {
                                    Jump *jump = jumps[i];
                                    
                                    if (jump.timestamp < timestamp) {
                                      [jumps removeObjectAtIndex:i];
                                      
                                      i--;
                                    }
                                    else if (jump.timestamp == timestamp) {
                                      found = YES;
                                      
                                      jump.edsm = self;
                                      
                                      [jumps removeObjectAtIndex:i];
                                      
                                      i--;
                                      
                                      break;
                                    }
                                    else {
                                      break;
                                    }
                                  }
                                  
                                  if (found == NO) {
                                    [newJumpsFromEDSM addObject:log];
                                  }
                                  
                                  prevSystem    = system;
                                  prevTimestamp = timestamp;
                                }
                                
                                NSError *error = nil;
                                
                                [self.managedObjectContext save:&error];
                                
                                if (error != nil) {
                                  NSLog(@"ERROR saving context: %@", error);
                                  
                                  exit(-1);
                                }

                                NSLog(@"Received %ld jumps from EDSM", (long)travelLogs.count);
                                
                                //save new jumps from EDSM
                                
                                [self receiveJumpsFromEDSM:newJumpsFromEDSM];
                                
                                //Send new jumps TO EDSM

                                NSPredicate  *predicate   = [NSPredicate predicateWithFormat:@"edsm == nil"];
                                NSOrderedSet *jumpsToSend = [[NSOrderedSet orderedSetWithArray:allJumps] filteredOrderedSetUsingPredicate:predicate];
                                
                                [self sendJumpsToEDSM:jumpsToSend];
                                
                                [Jump printStats];
                              }];
}

- (void)receiveJumpsFromEDSM:(NSArray *)jumps {
  NSLog(@"Received %ld new jumps from EDSM", (long)jumps.count);
  
  if (jumps.count > 0) {
    NSManagedObjectContext *context   = self.managedObjectContext;
    NSError                *error     = nil;
    NSDateFormatter        *formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    formatter.timeZone   = [NSTimeZone timeZoneWithName:@"UTC"];
    
    for (NSDictionary *jump in jumps) {
      NSString   *name      = jump[@"system"];
      NSDate     *timestamp = [formatter dateFromString:jump[@"date"]];
      NSString   *className = NSStringFromClass(Jump.class);
      Jump       *jump      = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
      System     *system    = [System systemWithName:name inContext:context];
      NSUInteger  idx       = NSNotFound;
      
      NSLog(@"%@ - %@", timestamp, name);
      
      if (system == nil) {
        className = NSStringFromClass(System.class);
        system    = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
        
        system.name = name;
      }
      
      jump.system    = system;
      jump.timestamp = [timestamp timeIntervalSinceReferenceDate];
      
      idx = [self.jumps indexOfObject:jump
                        inSortedRange:(NSRange){0, self.jumps.count}
                              options:NSBinarySearchingInsertionIndex
                      usingComparator:^NSComparisonResult(Jump *jump1, Jump *jump2) {
                        NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:jump1.timestamp];
                        NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:jump2.timestamp];
                        
                        return [date1 compare:date2];
                      }];
      
      [self insertObject:jump inJumpsAtIndex:idx];
    }
    
    [context save:&error];
    
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
      
      exit(-1);
    }
    
    [EventLogger addLog:[NSString stringWithFormat:@"Received %ld new jumps from EDSM", (long)jumps.count]];
  }
}

- (void)sendJumpsToEDSM:(NSOrderedSet *)jumps {
  NSLog(@"Sending %ld jumps to EDSM", (long)jumps.count);
  
  for (Jump *jump in jumps) {
    [self sendJumpToEDSM:jump];
  }
}

- (void)sendJumpToEDSM:(Jump *)jump {
  //NSLog(@"%s: TODO!!!", __FUNCTION__);
  
  NSLog(@"Sending jump to EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp], jump.system.name);
  
  [EDSMConnection addJump:jump
             forCommander:self.commander
                   apiKey:self.apiKey
                 response:^(BOOL success, NSError *error) {
                   
                   if (success == YES) {
                     NSError *error = nil;
                     
                     if (self.jumps == nil) {
                       jump.edsm = self;
                     }
                     else {
                       NSUInteger idx = [self.jumps indexOfObject:jump
                                                    inSortedRange:(NSRange){0, self.jumps.count}
                                                          options:NSBinarySearchingInsertionIndex
                                                  usingComparator:^NSComparisonResult(Jump *jump1, Jump *jump2) {
                                                    NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:jump1.timestamp];
                                                    NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:jump2.timestamp];
                                                       
                                                    return [date1 compare:date2];
                                                  }];
                       
                       [self insertObject:jump inJumpsAtIndex:idx];
                     }
                     
                     [self.managedObjectContext save:&error];
                     
                     if (error != nil) {
                       NSLog(@"ERROR saving context: %@", error);
                       
                       exit(-1);
                     }
                     
                     if (self.jumps.lastObject == jump) {
                       [EventLogger addLog:@" - sent to EDSM!" timestamp:NO newline:NO];
                     }
                     else {
                       [EventLogger addLog:[NSString stringWithFormat:@"Sent new jump to EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp], jump.system.name]];
                     }
                   }
                   else {
                     NSLog(@"ERROR from EDSM: %ld - %@", (long)error.code, error.localizedDescription);
                   }
                   
                 }];
}

#warning FIXME: workaround for a known SDK bug (http://stackoverflow.com/questions/7385439/exception-thrown-in-nsorderedset-generated-accessors)
- (void)insertObject:(Jump *)value inJumpsAtIndex:(NSUInteger)idx {
  NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.jumps];
  
  [tempSet insertObject:value atIndex:idx];
  
  self.jumps = tempSet;
}

#pragma mark -
#pragma mark private functions



@end
