//
//  EDSMConnection.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 17/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "EDSMConnection.h"
#import "Jump.h"

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
 sendCredential:NO
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
     parameters:3,
        @"sysname", systemName,
        @"coords", @"1",
        @"distances", @"1"
   ];
}

+ (void)getNightlyDumpWithResponse:(void(^)(NSArray *response, NSError *error))response {
  [self setup];
  
  [self callApi:@"dump/systemsWithCoordinates.json"
     withMethod:@"GET"
 sendCredential:NO
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
  NSDate           *lastSyncDate = [NSUserDefaults.standardUserDefaults objectForKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
  NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
  
  dayComponent.day = -6;
  
  NSCalendar *calendar = [NSCalendar currentCalendar];
  NSDate     *minDate  = [calendar dateByAddingComponents:dayComponent toDate:NSDate.date options:0];
  
  if ([lastSyncDate earlierDate:minDate] == lastSyncDate) {
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
    [self setup];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
    formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
    
    NSString *from = [formatter stringFromDate:lastSyncDate];
    
    lastSyncDate = NSDate.date;
    
    [self callApi:@"api-v1/systems"
       withMethod:@"GET"
   sendCredential:NO
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
     parameters:3,
   @"startdatetime", from, // <-- return only systems updated after this date
   @"known", @"1",         // <-- return only systems with known coordinates
   @"coords", @"1"         // <-- include system coordinates
   //@"distances", @"1"    // <-- include distances from other susyems
   //@"submitted", @"1",   // <-- who submitted the distances
   ];
  }
}

+ (void)getJumpsForCommander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(NSArray *jumps, NSError *error))response {
  NSAssert(commanderName.length > 0, @"missing commanderName");
  NSAssert(apiKey.length > 0, @"missing apiKey");
  
  NSDate *lastSyncDate = [NSUserDefaults.standardUserDefaults objectForKey:EDSM_JUMPS_UPDATE_TIMESTAMP];

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString *from = [formatter stringFromDate:lastSyncDate];
  
  [self callApi:@"api-logs-v1/get-logs"
     withMethod:@"POST"
 sendCredential:NO
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
          
          [NSUserDefaults.standardUserDefaults setObject:lastSyncDate forKey:EDSM_JUMPS_UPDATE_TIMESTAMP];
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
   @"commanderName", commanderName,
   @"apiKey", apiKey,
   @"startdatetime", from
   ];
}

+ (void)addJump:(Jump *)jump forCommander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response {
  NSAssert(jump != nil, @"missing jump");
  NSAssert(jump.edsm == nil, @"jump already sent to EDSM");
  NSAssert(commanderName.length > 0, @"missing commanderName");
  NSAssert(apiKey.length > 0, @"missing apiKey");

  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString *name      = jump.system.name;
  NSString *timestamp = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp]];
  
  [self callApi:@"api-logs-v1/set-log"
     withMethod:@"POST"
 sendCredential:NO
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

+ (void)getCommentsForCommander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(NSArray *comments, NSError *error))response {
  NSAssert(commanderName.length > 0, @"missing commanderName");
  NSAssert(apiKey.length > 0, @"missing apiKey");
  
  [self callApi:@"api-logs-v1/get-comments"
     withMethod:@"POST"
 sendCredential:NO
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
     parameters:2,
   @"commanderName", commanderName,
   @"apiKey", apiKey
   ];
}

+ (void)setCommentForSystem:(System *)system commander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response {
  NSAssert(system != nil, @"missing system");
  NSAssert(commanderName.length > 0, @"missing commanderName");
  NSAssert(apiKey.length > 0, @"missing apiKey");
  
  [self callApi:@"api-logs-v1/set-comment"
     withMethod:@"POST"
 sendCredential:NO
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
   @"systemName", system.name,
   @"comment", (system.comment.length > 0) ? system.comment : @"",
   @"commanderName", commanderName,
   @"apiKey", apiKey
   ];
}

@end
