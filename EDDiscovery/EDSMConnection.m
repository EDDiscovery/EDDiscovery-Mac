//
//  EDSMConnection.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 17/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "EDSMConnection.h"
#import "Jump.h"
#import "System.h"
#import "Note.h"
#import "Commander.h"
#import "EDSM.h"

#define BASE_URL @"http://www.edsm.net"
#define KEYCHAIN_PREFIX nil

@implementation EDSMConnection

+ (void)setup {
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    [self setBaseUrl:BASE_URL andKeychainPrefix:KEYCHAIN_PREFIX];
  });
}

+ (void)getSystemInfo:(NSString *)systemName response:(void(^)(NSDictionary *response, NSError *error))response {
  [self setup];
  
  [self callApi:@"api-v1/system"
     withMethod:@"POST"
responseCallback:^(id data, NSError *error) {
  
  if (error == nil) {
    NSError      *error  = nil;
    NSDictionary *result = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
    
    if (![result isKindOfClass:NSDictionary.class]) {
      result = nil;
    }
    
    response(result, error);
  }
  else {
    response(nil, error);
  }
  
}
     parameters:4,
        @"sysname",       systemName,
        @"coords",        @"1",
        @"distances",     @"1",
        @"problems",      @"1"
      //@"includeHidden", @"1"
   ];
}

+ (void)submitDistances:(NSData *)data response:(void(^)(BOOL distancesSubmitted, BOOL systemTrilaterated, NSError *error))response {
  [self callApi:@"api-v1/submit-distances"
       withBody:data
responseCallback:^(id output, NSError *error) {
  if (error == nil) {
    NSError      *error        = nil;
    NSDictionary *data         = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
    BOOL          submitted    = YES;
    BOOL          trilaterated = NO;
    
    if ([data isKindOfClass:NSDictionary.class]) {
      NSDictionary *baseSystem = data[@"basesystem"];
      NSArray      *distances  = data[@"distances"];
      
      if ([distances isKindOfClass:NSArray.class]) {
        for (NSDictionary *distance in distances) {
          NSInteger result = [distance[@"msgnum"] integerValue];
        
          if (result == 201) {
            submitted = NO;
            
            error = [NSError errorWithDomain:@"EDDiscovery"
                                        code:result
                                    userInfo:@{NSLocalizedDescriptionKey:distance[@"msg"]}];
          }
        }
      }
      
      if ([baseSystem isKindOfClass:NSDictionary.class]) {
        NSInteger result = [baseSystem[@"msgnum"] integerValue];
        
        if (result == 101) {
          submitted = NO;
          
          error = [NSError errorWithDomain:@"EDDiscovery"
                                      code:result
                                  userInfo:@{NSLocalizedDescriptionKey:baseSystem[@"msg"]}];
        }
        else if (result == 102 || result == 104) {
          trilaterated = YES;
        }
      }
      
      response(submitted, trilaterated, error);
    }
    else {
      error = [NSError errorWithDomain:@"EDDiscovery"
                                  code:999
                              userInfo:@{NSLocalizedDescriptionKey:NSLocalizedString(@"Error in server response", @"")}];
      
      response(NO, NO, error);
    }
  }
  else {
    response(NO, NO, error);
  }

}];
}

+ (void)getNightlyDumpWithResponse:(void(^)(NSArray *response, NSError *error))response {
  [self setup];
  
  [self callApi:@"dump/systemsWithCoordinates.json"
     withMethod:@"GET"
responseCallback:^(id output, NSError *error) {

  if (error == nil) {
    NSError *error   = nil;
    NSArray *systems = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
    
    if (![systems isKindOfClass:NSArray.class]) {
      systems = nil;
    }
    
    response(systems, error);
  }
  else {
    response(nil, error);
  }
  
}
     parameters:0];
}

+ (void)getSystemsInfoWithResponse:(void(^)(NSArray *response, NSError *error))response {
//#warning forcing update of ALL systems!
//  static dispatch_once_t onceToken;
//  dispatch_once(&onceToken, ^{
//    [NSUserDefaults.standardUserDefaults removeObjectForKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
//  });
  
  NSDate           *lastSyncDate = [NSUserDefaults.standardUserDefaults objectForKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
  NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
  
  dayComponent.day = -6;
  
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDate     *minDate  = [calendar dateByAddingComponents:dayComponent toDate:NSDate.date options:0];
  
  if ([lastSyncDate earlierDate:minDate] == lastSyncDate) {
    NSLog(@"Fetching nightly systems dump!");
    
    [self getNightlyDumpWithResponse:^(NSArray *output, NSError *error) {
      //save sync date 1 day in the past as the nighly dumps are generated once per day
      
      if (output != nil) {
        NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
        
        dayComponent.day = -1;
        
        NSCalendar *calendar     = [NSCalendar currentCalendar];
        NSDate     *lastSyncDate = [calendar dateByAddingComponents:dayComponent toDate:NSDate.date options:0];
        
        [NSUserDefaults.standardUserDefaults setObject:lastSyncDate forKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
        
        [self getSystemsInfoWithResponse:^(NSArray *output2, NSError *error2) {
          NSMutableArray *array = [NSMutableArray arrayWithArray:output];

          if ([output2 isKindOfClass:NSArray.class]) {
            [array addObjectsFromArray:output2];
          }
          
          response(array, error);
        }];
      }
    }];
  }
  else {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    NSString *from = [formatter stringFromDate:lastSyncDate];
    
    lastSyncDate = NSDate.date;
    
    [self setup];
    
    [self callApi:@"api-v1/systems"
       withMethod:@"GET"
  responseCallback:^(id output, NSError *error) {
    
    //  NSLog(@"ERR: %@", error);
    //  NSLog(@"RES: %@", response);
    
    if (error == nil) {
      NSError *error   = nil;
      NSArray *systems = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
      
      if (![systems isKindOfClass:NSArray.class]) {
        systems = nil;
      }
      
      response(systems, error);
      
      if ([systems isKindOfClass:NSArray.class]) {
        [NSUserDefaults.standardUserDefaults setObject:lastSyncDate forKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
      }
    }
    else {
      response(nil, error);
    }
  }
     parameters:4,
   @"startdatetime", from, // <-- return only systems updated after this date
   @"known",         @"1", // <-- return only systems with known coordinates
   @"coords",        @"1", // <-- include system coordinates
 //@"distances",     @"1", // <-- include distances from other susyems
   @"problems",      @"1"  // <-- include information about known errors
 //@"includeHidden", @"1"  // <-- include systems with wrong names or wrong distances
   ];
  }
}

+ (void)getJumpsForCommander:(Commander *)commander response:(void(^)(NSArray *jumps, NSError *error))response {
  NSDate *lastSyncDate = nil;
  
  if (commander.edsmAccount.jumpsUpdateTimestamp != 0) {
    lastSyncDate = [NSDate dateWithTimeIntervalSinceReferenceDate:commander.edsmAccount.jumpsUpdateTimestamp];
  }
  
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString *from = [formatter stringFromDate:lastSyncDate];
  
  [self setup];
  
  [self callApi:@"api-logs-v1/get-logs"
     withMethod:@"POST"
responseCallback:^(id output, NSError *error) {
  
  if (error == nil) {
    NSArray      *jumps = nil;
    NSError      *error = nil;
    NSDictionary *data  = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
    
    if ([data isKindOfClass:NSDictionary.class]) {
      NSInteger result = [data[@"msgnum"] integerValue];
      
      //100 --> success
      
      if (result == 100) {
        jumps = data[@"logs"];
        
        if (jumps.count > 0) {
          NSDictionary *latestJump   = jumps.firstObject;
          NSDate       *lastSyncDate = [formatter dateFromString:latestJump[@"date"]];
          
          //add 1 second to date of last recorded jump (otherwise EDSM will return this jump to me next time I sync)
          lastSyncDate = [lastSyncDate dateByAddingTimeInterval:1];
          
          commander.edsmAccount.jumpsUpdateTimestamp = [lastSyncDate timeIntervalSinceReferenceDate];
        }
      }
      else {
        error = [NSError errorWithDomain:@"EDDiscovery"
                                        code:result
                                userInfo:@{NSLocalizedDescriptionKey:data[@"msg"]}];
      }
    }
    
    response(jumps, error);
  }
  else {
    response(nil, error);
  }
  
}
     parameters:3,
   @"commanderName", commander.name,
   @"apiKey", commander.edsmAccount.apiKey,
   @"startdatetime", from
   ];
}

+ (void)addJump:(Jump *)jump forCommander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response {
  NSAssert(jump != nil, @"missing jump");
  NSAssert(jump.edsm == nil, @"jump already sent to EDSM");

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString *name      = jump.system.name;
  NSString *timestamp = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp]];
  
  [self setup];
  
  [self callApi:@"api-logs-v1/set-log"
     withMethod:@"POST"
responseCallback:^(id output, NSError *error) {
  
  if (error == nil) {
    NSError      *error = nil;
    NSDictionary *data  = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
    
    if ([data isKindOfClass:NSDictionary.class]) {
      NSInteger result = [data[@"msgnum"] integerValue];
      
      //100 --> success
      
      if (result == 100) {
        response(YES, nil);
      }
      else {
        error = [NSError errorWithDomain:@"EDDiscovery"
                                    code:result
                                userInfo:@{NSLocalizedDescriptionKey:data[@"msg"]}];
        
        response(NO, error);
      }
    }
  }
  else {
    response(NO, error);
  }
  
}
     parameters:4,
   @"systemName", name,
   @"dateVisited", timestamp,
   @"commanderName", commanderName,
   @"apiKey", apiKey
   ];
}

+ (void)getNotesForCommander:(Commander *)commander response:(void(^)(NSArray *comments, NSError *error))response {
  NSDate *lastSyncDate = nil;
  
  if (commander.edsmAccount.notesUpdateTimestamp != 0) {
    lastSyncDate = [NSDate dateWithTimeIntervalSinceReferenceDate:commander.edsmAccount.notesUpdateTimestamp];
  }
  
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString *from = [formatter stringFromDate:lastSyncDate];
  
  [self setup];
  
  [self callApi:@"api-logs-v1/get-comments"
     withMethod:@"POST"
responseCallback:^(id output, NSError *error) {
  
  if (error == nil) {
    NSArray      *comments = nil;
    NSError      *error    = nil;
    NSDictionary *data     = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
    
    if ([data isKindOfClass:NSDictionary.class]) {
      NSInteger result = [data[@"msgnum"] integerValue];
      
      //100 --> success
      
      if (result == 100) {
        comments = data[@"comments"];
        
        if (comments.count > 0) {
          NSDictionary *latestComment = comments.lastObject;
          NSDate       *lastSyncDate  = [formatter dateFromString:latestComment[@"lastUpdate"]];
          
          //add 1 second to date of last recorded comment (otherwise EDSM will return this comment to me next time I sync)
          lastSyncDate = [lastSyncDate dateByAddingTimeInterval:1];
          
          commander.edsmAccount.notesUpdateTimestamp = [lastSyncDate timeIntervalSinceReferenceDate];
        }
      }
      else {
        error = [NSError errorWithDomain:@"EDDiscovery"
                                    code:result
                                userInfo:@{NSLocalizedDescriptionKey:data[@"msg"]}];
      }
    }
    
    response(comments, error);
  }
  else {
    response(nil, error);
  }
  
}
     parameters:3,
   @"startdatetime", from, // <-- return only systems updated after this date
   @"commanderName", commander.name,
   @"apiKey", commander.edsmAccount.apiKey
   ];
}

+ (void)setNote:(NSString *)note system:(NSString *)system commander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response {
  NSAssert(system != nil, @"missing system");
  
  [self setup];
  
  [self callApi:@"api-logs-v1/set-comment"
     withMethod:@"POST"
responseCallback:^(id output, NSError *error) {
  
  if (error == nil) {
    NSError      *error   = nil;
    NSDictionary *data    = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
    BOOL          success = NO;
    
    if ([data isKindOfClass:NSDictionary.class]) {
      NSInteger result = [data[@"msgnum"] integerValue];
      
      //100 --> success
      
      if (result == 100) {
        success = YES;
      }
      else {
        error = [NSError errorWithDomain:@"EDDiscovery"
                                    code:result
                                userInfo:@{NSLocalizedDescriptionKey:data[@"msg"]}];
      }
    }
    
    response(success, error);
  }
  else {
    response(NO, error);
  }
  
}
     parameters:4,
   @"systemName", system,
   @"comment", (note.length > 0) ? note : @"",
   @"commanderName", commanderName,
   @"apiKey", apiKey
   ];
}

@end
