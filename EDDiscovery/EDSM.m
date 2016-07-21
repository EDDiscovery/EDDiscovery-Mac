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
#import "Distance.h"


@implementation EDSM {
  NSString *apiKey;
}

#pragma mark -
#pragma mark properties

- (NSString *)apiKey {
  if (apiKey.length == 0 && self.commander.name.length > 0) {
    apiKey = [SSKeychain passwordForService:NSStringFromClass(self.class) account:self.commander.name];
  }
  
  return apiKey;
}

- (void)setApiKey:(nullable NSString *)newApiKey {
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

#pragma mark -
#pragma mark jumps management

- (void)syncJumpsWithEDSM:(void(^)(void))response {
  NSAssert([self.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  
  LoadingViewController.textField.stringValue = NSLocalizedString(@"Syncing jumps with EDSM", @"");
  
  [EDSMConnection getJumpsForCommander:self.commander
                              response:^(NSArray *travelLogs, NSError *connectionError) {
                                
                                if (![travelLogs isKindOfClass:NSArray.class]) {
                                  [EventLogger addError:[NSString stringWithFormat:@"%@: %ld - %@", ([connectionError.domain isEqualToString:@"EDDiscovery"]) ? @"ERROR from EDSM" : @"NETWORK ERROR", (long)connectionError.code, connectionError.localizedDescription]];
                                        
                                  [Jump printJumpStatsOfCommander:self.commander];
                                  
                                  response();
                                        
                                  return;
                                }
    
                                [EventLogger addLog:[NSString stringWithFormat:@"Received %@ jumps from EDSM", FORMAT(travelLogs.count)]];
                                
                                NSManagedObjectID *edsmID = self.objectID;
                                
                                [WORK_CONTEXT performBlock:^{
                                  EDSM            *edsm             = [WORK_CONTEXT existingObjectWithID:edsmID error:nil];
                                  NSArray         *allJumps         = [Jump allJumpsOfCommander:edsm.commander];
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
                                        
                                        jump.edsm = edsm;
                                        
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
                                  
                                  [WORK_CONTEXT save];
                                  
                                  //save new jumps from EDSM
                                  
                                  [edsm parseJumpsFromEDSM:newJumpsFromEDSM];
                                    
                                  //Send new jumps TO EDSM
                                  
                                  NSPredicate  *predicate   = [NSPredicate predicateWithFormat:@"edsm == nil"];
                                  NSOrderedSet *jumpsToSend = [[NSOrderedSet orderedSetWithArray:allJumps] filteredOrderedSetUsingPredicate:predicate];
                                  
                                  [edsm sendJumpsToEDSM:jumpsToSend response:^{
                                    //print some stats to log window
                                    
                                    [Jump printJumpStatsOfCommander:edsm.commander];
                                    
                                    [MAIN_CONTEXT performBlock:^{
                                      EDSM *edsm = [MAIN_CONTEXT existingObjectWithID:edsmID error:nil];
                                      
                                      //get new notes from EDSM
                                      
                                      [edsm getNotesFromEDSM];
                                      
                                      response();
                                    }];
                                  }];
                                }];
                              }];
}

- (void)parseJumpsFromEDSM:(NSArray *)jumps {
  NSAssert([self.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  
  NSLog(@"Received %@ new jumps from EDSM", FORMAT(jumps.count));
  
  if (jumps.count > 0) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    formatter.timeZone   = [NSTimeZone timeZoneWithName:@"UTC"];
    
    [MAIN_CONTEXT performBlock:^{
      LoadingViewController.progressIndicator.indeterminate = NO;
      LoadingViewController.progressIndicator.maxValue      = jumps.count;
      LoadingViewController.progressIndicator.doubleValue   = 0;
    }];
    
    for (NSDictionary *jump in jumps) {
      NSString   *name      = jump[@"system"];
      NSDate     *timestamp = [formatter dateFromString:jump[@"date"]];
      NSString   *className = NSStringFromClass(Jump.class);
      Jump       *jump      = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
      System     *system    = [System systemWithName:name inContext:WORK_CONTEXT];
      NSUInteger  idx       = NSNotFound;
      
      if (system == nil) {
        className = NSStringFromClass(System.class);
        system    = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
        
        system.name = name;
      }
      
      [MAIN_CONTEXT performBlock:^{
        LoadingViewController.progressIndicator.doubleValue++;
        
        if (((long)LoadingViewController.progressIndicator.doubleValue % 1000) == 0 && LoadingViewController.progressIndicator.doubleValue != 0) {
          [EventLogger addLog:[NSString stringWithFormat:@"%@ jumps parsed...", FORMAT(LoadingViewController.progressIndicator.doubleValue)]];
        }
      }];
      
      jump.system    = system;
      jump.timestamp = [timestamp timeIntervalSinceReferenceDate];
      
      idx = [self.jumps indexOfObject:jump
                        inSortedRange:(NSRange){0, self.jumps.count}
                              options:NSBinarySearchingInsertionIndex
                      usingComparator:^NSComparisonResult(Jump *jump1, Jump *jump2) {
                        if (jump1.timestamp < jump2.timestamp) {
                          return NSOrderedAscending;
                        }
                        else if (jump1.timestamp < jump2.timestamp) {
                          return NSOrderedDescending;
                        }
                        
                        return NSOrderedSame;
                      }];
      
      [self insertObject:jump inJumpsAtIndex:idx];
    }
    
    [WORK_CONTEXT save];
    
    [EventLogger addLog:[NSString stringWithFormat:@"Parsed %@ new jumps from EDSM", FORMAT(jumps.count)]];
  }
}

- (void)sendJumpsToEDSM:(NSOrderedSet *)jumps response:(void(^)(void))response {
  NSAssert([self.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  
  NSLog(@"Sending %ld jumps to EDSM", (long)jumps.count);
  
  if (jumps.count == 0) {
    response();
    return;
  }
  
  __block NSUInteger count    = jumps.count;
  __block NSUInteger progress = 0;
  
  [MAIN_CONTEXT performBlock:^{
    LoadingViewController.progressIndicator.indeterminate = NO;
    LoadingViewController.progressIndicator.maxValue      = count;
    LoadingViewController.progressIndicator.doubleValue   = 0;
  }];
  
  for (Jump *jump in jumps) {
    [self sendJumpToEDSM:jump log:NO response:^{
      progress++;

      if ((progress % 100) == 0 && progress != 0) {
        [EventLogger addLog:[NSString stringWithFormat:@"%ld / %ld jumps sent...", progress, count]];
      }
      
      [MAIN_CONTEXT performBlock:^{
        NSLog(@"progress: %.0f%%", (double)progress / (double)count * (double)100);
        
        LoadingViewController.progressIndicator.doubleValue = progress;
      }];
      
      if (progress == count && response != nil) {
        response();
      }
    }];
  }
}

- (void)sendJumpToEDSM:(Jump *)jump log:(BOOL)log response:(void(^__nullable)(void))response {
  NSAssert([self.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  NSAssert([jump.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  
  NSLog(@"Sending jump to EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp], jump.system.name);
  
  NSManagedObjectID *edsmID = self.objectID;
  NSManagedObjectID *jumpID = jump.objectID;

  [EDSMConnection addJump:jump
             forCommander:self.commander.name
                   apiKey:self.apiKey
                 response:^(BOOL success, NSError *error) {
                   
                   if (success == NO) {
                     if ([error.domain isEqualToString:@"EDDiscovery"]) {
                       [EventLogger addError:[NSString stringWithFormat:@"ERROR from EDSM: %ld - %@", (long)error.code, error.localizedDescription]];
                       
                       //EDSM did not like this jump, delete it from travel history
                       
                       [WORK_CONTEXT performBlock:^{
                         Jump *jump = [WORK_CONTEXT existingObjectWithID:jumpID error:nil];

                         [WORK_CONTEXT deleteObject:jump];
                       }];
                     }
                     else {
                       [EventLogger addError:[NSString stringWithFormat:@"NETWORK ERROR: %ld - %@", (long)error.code, error.localizedDescription]];
                     }
                     
                     if (response != nil) {
                       [WORK_CONTEXT performBlock:^{
                         response();
                       }];
                     }
                   }
                   else {
                     [WORK_CONTEXT performBlock:^{
                       EDSM *edsm = [WORK_CONTEXT existingObjectWithID:edsmID error:nil];
                       Jump *jump = [WORK_CONTEXT existingObjectWithID:jumpID error:nil];
                       
                       if (edsm.jumps == nil) {
                         jump.edsm = edsm;
                       }
                       else {
                         NSUInteger idx = [edsm.jumps indexOfObject:jump
                                                      inSortedRange:(NSRange){0, edsm.jumps.count}
                                                            options:NSBinarySearchingInsertionIndex
                                                    usingComparator:^NSComparisonResult(Jump *jump1, Jump *jump2) {
                                                      NSDate *date1 = [NSDate dateWithTimeIntervalSinceReferenceDate:jump1.timestamp];
                                                      NSDate *date2 = [NSDate dateWithTimeIntervalSinceReferenceDate:jump2.timestamp];
                                                      
                                                      return [date1 compare:date2];
                                                    }];
                         
                         [edsm insertObject:jump inJumpsAtIndex:idx];
                       }
                       
                       [WORK_CONTEXT save];
                       
                       if (log == YES) {
                         if ([EventLogger.instance.currLine containsString:jump.system.name]) {
                           [EventLogger addLog:@" - sent to EDSM!" timestamp:NO newline:NO];
                         }
                         else {
                           [EventLogger addLog:[NSString stringWithFormat:@"Sent new jump to EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp], jump.system.name]];
                         }
                       }
                       
                       if (response != nil) {
                         response();
                       }
                     }];
                   }
                 }];
}

- (void)deleteJumpFromEDSM:(Jump *)jump {
  NSAssert([self.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  
  [EDSMConnection deleteJump:jump
                forCommander:self.commander.name
                      apiKey:self.apiKey
                    response:^(BOOL success, NSError *error) {
                      if (success == NO) {
                        [EventLogger addError:[NSString stringWithFormat:@"%@: %ld - %@", ([error.domain isEqualToString:@"EDDiscovery"]) ? @"ERROR from EDSM" : @"NETWORK ERROR", (long)error.code, error.localizedDescription]];
                      }
                      else {
                        NSTimeInterval  timestamp  = jump.timestamp;
                        NSString       *systemName = jump.system.name;
                        
                        [MAIN_CONTEXT deleteObject:jump];
                        [MAIN_CONTEXT save];
                        
                        [EventLogger addLog:[NSString stringWithFormat:@"Deleted jump from travel history and EDSM: %@ - %@", [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp], systemName]];
                      }
                    }];
}

#pragma mark -
#pragma mark notes management

- (void)getNotesFromEDSM {
  NSAssert([self.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  
  NSManagedObjectID *edsmID = self.objectID;

  [EDSMConnection getNotesForCommander:self.commander
                              response:^(NSArray *comments, NSError *connectionError) {
                                   
                                 if (![comments isKindOfClass:NSArray.class]) {
                                   [EventLogger addError:[NSString stringWithFormat:@"%@: %ld - %@", ([connectionError.domain isEqualToString:@"EDDiscovery"]) ? @"ERROR from EDSM" : @"NETWORK ERROR", (long)connectionError.code, connectionError.localizedDescription]];
                                   
                                   return;
                                 }
                                 
                                 NSLog(@"Got %ld comments from EDSM", (long)comments.count);
                                
                                 if (comments.count > 0) {
                                   [WORK_CONTEXT performBlock:^{
                                     EDSM *edsm = [WORK_CONTEXT existingObjectWithID:edsmID error:nil];
                                     
                                     for (NSDictionary *comment in comments) {
                                       NSString    *name      = comment[@"system"];
                                       NSString    *txt       = comment[@"comment"];
                                       NSPredicate *predicate = [NSPredicate predicateWithFormat:@"system.name == %@", name];
                                       NSSet       *notes     = [edsm.notes filteredSetUsingPredicate:predicate];
                                       Note        *note      = notes.anyObject;
                                       
#warning FIXME: it should not be possible to create 2 different notes for the same system
                                       if (notes.count > 1) {
                                         note = nil;
                                         
                                         for (Note *aNote in notes) {
                                           if (aNote.note.length == 0 || note != nil) {
                                             [WORK_CONTEXT deleteObject:aNote];
                                           }
                                           else {
                                             note = aNote;
                                           }
                                         }
                                       }
                                       
                                       if (note == nil) {
                                         NSString *className = NSStringFromClass(Note.class);
                                         System   *system    = [System systemWithName:name inContext:WORK_CONTEXT];
                                         
                                         if (system == nil) {
                                           NSString *className = NSStringFromClass(System.class);
                                           
                                           system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
                                           
                                           system.name = name;
                                         }
                                         
                                         note = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
                                         
                                         note.edsm   = edsm;
                                         note.system = system;
                                       }
                                       
                                       note.note = txt;
                                     }
                                     
                                     [WORK_CONTEXT save];
                                     
                                     [EventLogger addLog:[NSString stringWithFormat:@"Received %ld new comments from EDSM", (long)comments.count]];
                                   }];
                                 }
                              }];
}

- (void)sendNoteToEDSM:(NSString *)note forSystem:(NSString *)system {
  NSAssert([self.managedObjectContext isEqual:MAIN_CONTEXT], @"Wrong context!");
  
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

#pragma mark -
#pragma mark distances management

+ (void)sendDistancesToEDSM:(System *)system response:(void(^)(BOOL distancesSubmitted, BOOL systemTrilaterated))response {
  NSMutableArray <Distance *> *distances = [NSMutableArray array];
  
  for (Distance *distance in system.sortedDistances) {
    if (distance.distance != 0 && distance.edited == YES) {
      [distances addObject:distance];
    }
  }
  
  if (distances.count == 0) {
    return;
  }
  
  [EventLogger addLog:[NSString stringWithFormat:@"Submitting %ld distances to EDSM", (long)distances.count]];
  
  [EDSMConnection submitDistances:distances
                        forSystem:system.name
                         response:^(BOOL distancesSubmitted, BOOL systemTrilaterated, NSError *error) {
                           
                           if (distancesSubmitted && systemTrilaterated) {
                             [EventLogger addLog:@"EDSM submission succeeded, trilateration successful"];
                           }
                           else if (distancesSubmitted) {
                             [EventLogger addWarning:@"EDSM submission succeeded, but trilateration failed: try adding more distances"];
                           }
                           else {
                             [EventLogger addError:[NSString stringWithFormat:@"EDSM submission failed: %@", error.localizedDescription]];
                           }
                           
                           response(distancesSubmitted, systemTrilaterated);
                         }];
}

@end
