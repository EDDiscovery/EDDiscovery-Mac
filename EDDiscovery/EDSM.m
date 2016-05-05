//
//  EDSM.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 19/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "EDSM.h"

#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "EventLogger.h"
#import "SSKeychain.h"
#import "Jump.h"
#import "System.h"
#import "Commander.h"
#import "Note.h"


@implementation EDSM {
  NSString *apiKey;
}

#pragma mark -
#pragma mark properties

- (NSString *)apiKey {
  NSAssert(self.commander.name.length > 0, @"Must have commander name!");
  
  if (apiKey.length == 0 && self.commander.name.length > 0) {
    apiKey = [SSKeychain passwordForService:NSStringFromClass(self.class) account:self.commander.name];
  }
  
  return apiKey;
}

- (void)setApiKey:(nullable NSString *)newApiKey {
  NSAssert(self.commander.name.length > 0, @"Must have commander name!");
  
  if (self.commander.name.length > 0) {
    if (newApiKey.length > 0) {
      [SSKeychain setPassword:newApiKey forService:NSStringFromClass(self.class) account:self.commander.name];
      apiKey = newApiKey;
    }
    else {
      [SSKeychain deletePasswordForService:NSStringFromClass(self.class) account:self.commander.name];
      apiKey = nil;
    }
  }
}

- (void)changeCommanderName:(NSString *)oldName to:(NSString *)newName {
  NSString *service = NSStringFromClass(self.class);
  
  apiKey = [SSKeychain passwordForService:NSStringFromClass(self.class) account:oldName];
  
  [SSKeychain deletePasswordForService:service account:oldName];
  
  [SSKeychain setPassword:apiKey forService:service account:newName];
}

#pragma mark -
#pragma mark jumps management

- (void)syncJumpsWithEDSM {
  [EDSMConnection getJumpsForCommander:self.commander
                              response:^(NSArray *travelLogs, NSError *connectionError) {
                                
                                if (![travelLogs isKindOfClass:NSArray.class]) {
                                  [EventLogger addError:[NSString stringWithFormat:@"ERROR from EDSM: %ld - %@", (long)connectionError.code, connectionError.localizedDescription]];
                                        
                                  [Jump printStatsOfCommander:self.commander];
                                        
                                  return;
                                }
    
                                NSArray         *allJumps         = [Jump allJumpsOfCommander:self.commander];
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
                                
                                [Jump printStatsOfCommander:self.commander];
                                
                                [self getNotesFromEDSM];
                                
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
      System     *system    = [System systemWithName:name];
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
    
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    
    numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;
    
    [EventLogger addLog:[NSString stringWithFormat:@"Received %@ new jumps from EDSM", [numberFormatter stringFromNumber:@(jumps.count)]]];
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
             forCommander:self.commander.name
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
                     
                     if ([EventLogger.instance.currLine containsString:jump.system.name]) {
                       [EventLogger addLog:@" - sent to EDSM!" timestamp:NO newline:NO];
                     }
                     else {
                       [EventLogger addLog:[NSString stringWithFormat:@"Sent new jump to EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp], jump.system.name]];
                     }
                   }
                   else {
                     [EventLogger addError:[NSString stringWithFormat:@"ERROR from EDSM: %ld - %@", (long)error.code, error.localizedDescription]];
                   }
                   
                 }];
}

//FIXME workaround for a known SDK bug (http://stackoverflow.com/questions/7385439/exception-thrown-in-nsorderedset-generated-accessors)
- (void)insertObject:(Jump *)value inJumpsAtIndex:(NSUInteger)idx {
  NSMutableOrderedSet *tempSet = [NSMutableOrderedSet orderedSetWithOrderedSet:self.jumps];
  
  [tempSet insertObject:value atIndex:idx];
  
  self.jumps = tempSet;
}

#pragma mark -
#pragma mark notes management

- (void)getNotesFromEDSM {
  [EDSMConnection getNotesForCommander:self.commander
                              response:^(NSArray *comments, NSError *connectionError) {
                                   
                                 if (![comments isKindOfClass:NSArray.class]) {
                                   [EventLogger addError:[NSString stringWithFormat:@"ERROR from EDSM: %ld - %@", (long)connectionError.code, connectionError.localizedDescription]];
                                   
                                   return;
                                 }
                                 
                                 NSLog(@"Received %ld new comments from EDSM", (long)comments.count);
                                 
                                 if (comments.count > 0) {
                                   NSManagedObjectContext *context = self.managedObjectContext;
                                   NSError                *error   = nil;
                                   
                                   for (NSDictionary *comment in comments) {
                                     NSString    *name      = comment[@"system"];
                                     NSString    *txt       = comment[@"comment"];
                                     NSPredicate *predicate = [NSPredicate predicateWithFormat:@"system.name == %@", name];
                                     NSSet       *notes     = [self.notes filteredSetUsingPredicate:predicate];
                                     Note        *note      = notes.anyObject;
                                     
                                     NSAssert(notes.count < 2, @"Cannot have more than 1 note");
                                     
                                     if (note == nil) {
                                       NSString *className = NSStringFromClass(Note.class);
                                       System   *system    = [System systemWithName:name];
                                       
                                       if (system == nil) {
                                         NSString *className = NSStringFromClass(System.class);
                                         
                                         system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
                                         
                                         system.name = name;
                                       }
                                       
                                       note = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
                                       
                                       note.edsm   = self;
                                       note.system = system;
                                     }
                                     
                                     
                                     note.note = txt;
                                   }
                                   
                                   [context save:&error];
                                   
                                   if (error != nil) {
                                     NSLog(@"ERROR saving context: %@", error);
                                     
                                     exit(-1);
                                   }
                                   
                                   if (comments.count > 0) {
                                     [EventLogger addLog:[NSString stringWithFormat:@"Received %ld new comments from EDSM", (long)comments.count]];
                                   }
                                 }
                                   
                              }];
}

- (void)sendNoteToEDSM:(NSString *)note forSystem:(NSString *)system {
  [EDSMConnection setNote:note
                   system:system
                commander:self.commander.name
                   apiKey:self.apiKey
                 response:^(BOOL success, NSError *error) {
                   
                   if (success) {
                     if (note.length > 0) {
                       [EventLogger addLog:[NSString stringWithFormat:@"Comment for system %@ saved to EDSM", system]];
                     }
                     else {
                       [EventLogger addLog:[NSString stringWithFormat:@"Comment for system %@ removed from EDSM", system]];
                     }
                   }
                   else {
                     [EventLogger addLog:[NSString stringWithFormat:@"ERROR: could not save comment for system: %ld - %@", (long)error.code, error.localizedDescription]];
                   }
                   
                 }];
}

@end
