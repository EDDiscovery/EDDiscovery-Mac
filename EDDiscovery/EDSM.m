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

#ifdef DEBUG
#warning TODO: replace with non-hardcoded data!
#else
#error TODO: replace with non-hardcoded data!
#endif
#define CMDR_NAME    @"<your-cmdr-name>"
#define CMDR_API_KEY @"<your-api-key>"
#error insert youe commander data

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

- (void)syncJumps {
  [EDSMConnection getTravelLogsForCommander:self.commander apiKey:self.apiKey response:^(NSDictionary *response, NSError *error) {
    
    NSInteger result = [response[@"msgnum"] integerValue];
    
    //100 --> success
    
    if (result == 100) {
      NSArray         *travelLogs    = response[@"logs"];
      NSMutableArray  *jumps         = [[Jump getAllJumpsInContext:self.managedObjectContext] mutableCopy];
      NSString        *prevSystem    = nil;
      NSTimeInterval   prevTimestamp = 0;
      NSUInteger       numDiffEDSM   = 0;
      NSUInteger       numDiffNETLOG = 0;
      NSUInteger       numDuplicates = 0;
      NSDateFormatter *formatter     = [[NSDateFormatter alloc] init];
      
      formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
      formatter.timeZone   = [NSTimeZone timeZoneWithName:@"UTC"];
      
      NSLog(@"Got %ld travel logs from EDSM", (long)travelLogs.count);
      
      //try to match netLog entries with EDSM entries
      
      for (NSDictionary *log in [travelLogs reverseObjectEnumerator]) {
        NSString       *system    = log[@"system"];
        NSTimeInterval  timestamp = [[formatter dateFromString:log[@"date"]] timeIntervalSinceReferenceDate];
        BOOL            found     = NO;
        
        //NSLog(@"EDSM jump: %@ - %@", system, [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp]);
        
        if ([system isEqualToString:prevSystem] && timestamp == prevTimestamp) {
          //duplicate records on EDSM are a thing, apparently
          numDuplicates++;
          continue;
        }
        
        //find a match in netLogs for current EDSM record
        
        for (NSUInteger i=0; i<jumps.count; i++) {
          Jump *jump = jumps[i];
          
          if (jump.timestamp < timestamp) {
            NSLog(@"Found local jump not saved to EDSM: %@ - %@", jump.system.name, [NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp]);
            
            numDiffEDSM++;
            
            [jumps removeObjectAtIndex:i];
            
            i--;
          }
          else if (jump.timestamp == timestamp) {
            found = YES;
            
            //NSLog(@"SELF: (%ld), %@", (long)self.objectID.isTemporaryID, self);
            //NSLog(@"JUMP: (%ld), %@", (long)jump.objectID.isTemporaryID, jump);
            
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
          NSLog(@"Found jump on ESDM not saved locally: %@ - %@", system, [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp]);
          
          numDiffNETLOG++;
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
      
      NSLog(@"Got %ld travel logs from EDSM", (long)travelLogs.count);
      NSLog(@"We have %ld duplicate jumps on EDSM", (long)numDuplicates);
      NSLog(@"We have %ld local jumps not saved to EDSM", (long)numDiffEDSM);
      NSLog(@"We have %ld jumps on EDSM not saved locally", (long)numDiffNETLOG);
      NSLog(@"Total differences: %ld", (long)(numDiffNETLOG + numDiffEDSM));
      
      NSLog(@"We have %ld local jumps with matches on EDSM", (long)self.jumps.count);
    }
    else {
      
      NSLog(@"ERROR from EDSM: %ld - %@", (long)result, response[@"msg"]);
      
    }
    
  }];
}

- (void)addJump:(Jump *)jump {
  NSLog(@"%s: TODO!!!", __FUNCTION__);
}

@end
