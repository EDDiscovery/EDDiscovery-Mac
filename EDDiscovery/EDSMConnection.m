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
#import "Distance.h"

#define BASE_URL @"http://www.edsm.net"

@implementation EDSMConnection

+ (void)setup {
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    [self setBaseUrl:BASE_URL];
  });
}

+ (void)getSystemInfo:(NSString *)systemName response:(void(^)(NSDictionary *response, NSError *error))response {
  [self setup];
  
  [self callApi:@"api-v1/system"
     concurrent:YES
     withMethod:@"POST"
progressCallBack:nil
responseCallback:^(id data, NSError *error) {
  
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/system"}];
  
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

+ (void)submitDistances:(NSArray <Distance *> *)distances forSystem:(NSString *)systemName response:(void(^)(BOOL distancesSubmitted, BOOL systemTrilaterated, NSError *error))response {
  Commander      *commander  = Commander.activeCommander;
  NSString       *cmdrName   = (commander == nil) ? @"" : commander.name;
  NSMutableArray *refs       = [NSMutableArray array];
  NSString       *appName    = [NSBundle.mainBundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
  NSString       *appVersion = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
  
  appName = [appName stringByAppendingString:@"-Mac"];
  
  for (Distance *distance in distances) {
    [refs addObject:@{
                      @"name":distance.name,
                      @"dist":distance.distance
                      }];
  }
  
  NSDictionary *dict = @{
                         @"data":@{
                             //@"test":@1, // <-- dry run... API will answer normally but won't store anything to the data base
                             @"ver":@2,
                             @"commander":cmdrName,
                             @"fromSoftware":appName,
                             @"fromSoftwareVersion":appVersion,
                             @"p0":@{
                                 @"name":systemName
                                 },
                             @"refs":refs
                             }
                         };
  
  NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
  
  [self callApi:@"api-v1/submit-distances"
     concurrent:YES
       withBody:data
progressCallBack:nil
responseCallback:^(id output, NSError *error) {
  
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/submit-distances"}];
  
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

+ (void)getNightlyDumpWithProgress:(ProgressBlock)progress response:(void(^)(NSArray *response, NSError *error))response {
  [self setup];
  
  [self callApi:@"dump/systemsWithCoordinates.json"
     concurrent:NO
     withMethod:@"GET"
progressCallBack:^(long long downloaded, long long total) {
  if (progress != nil) {
#warning FIXME: making assumptions on nightly dump file size!
    //EDSM does not return expected content size of nightly dumps
    //assume a size of 350 MB
    
    total = 1024 * 1024 * 350;
  
    progress(downloaded, MAX(downloaded,total));
  }
}
responseCallback:^(id output, NSError *error) {

  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"dump/systemsWithCoordinates.json"}];
  
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

+ (void)getSystemsInfoWithProgress:(ProgressBlock)progress response:(void(^)(NSArray *response, NSError *error))response {
  NSDate *lastSyncDate = [NSUserDefaults.standardUserDefaults objectForKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
  
  if (lastSyncDate == nil) {
    NSLog(@"Fetching nightly systems dump!");
    
    [self getNightlyDumpWithProgress:progress response:^(NSArray *output, NSError *error) {
      //save sync date 1 day in the past as the nighly dumps are generated once per day
      
      if (output != nil) {
        NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
        
        dayComponent.day = -1;
        
        NSCalendar *calendar     = [NSCalendar currentCalendar];
        NSDate     *lastSyncDate = [calendar dateByAddingComponents:dayComponent toDate:NSDate.date options:0];
        
        [NSUserDefaults.standardUserDefaults setObject:lastSyncDate forKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
        
        [self getSystemsInfoWithProgress:nil response:^(NSArray *output2, NSError *error2) {
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
    //perform delta queries in batches of 1 days
    
    NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
    
    dayComponent.day = 1;
    
    NSCalendar         *calendar    = [NSCalendar currentCalendar];
    NSDate             *fromDate    = lastSyncDate;
    NSDate             *toDate      = [calendar dateByAddingComponents:dayComponent toDate:fromDate options:0];
    NSDate             *currDate    = NSDate.date;
    NSMutableArray     *systems     = [NSMutableArray array];
    __block NSUInteger  numRequests = 1;
    __block NSUInteger  numDone     = 0;
    __block NSError    *error       = nil;
    
    ProgressBlock progressBlock = ^void(long long downloaded, long long total) {
      if (progress != nil) {
        @synchronized (self.class) {
          long long myTotal      = numRequests + numDone;
          long long currProgress = numDone;
          
          progress(currProgress, myTotal);
        }
      }
    };
    
    void (^responseBlock)(NSArray *, NSError *) = ^void(NSArray *output, NSError *err) {
      @synchronized (self.class) {
        if (err != nil) {
          error = err;
        }
        else if ([output isKindOfClass:NSArray.class]) {
          [systems addObjectsFromArray:output];
        }
        
        numRequests--;
        numDone++;
        
        if (progress != nil) {
          long long myTotal      = numRequests + numDone;
          long long currProgress = numDone;
          
          progress(currProgress, myTotal);
        }
        
        if (numRequests == 0) {
          if (error == nil) {
            response(systems, nil);
            
            [NSUserDefaults.standardUserDefaults setObject:currDate forKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
          }
          else {
            response(nil, error);
          }
        }
      }
    };
    
    while (toDate.timeIntervalSinceReferenceDate < currDate.timeIntervalSinceReferenceDate) {
      @synchronized (self.class) {
        numRequests++;
      }
      
      [self getSystemsInfoFrom:fromDate
                            to:toDate
                      progress:progressBlock
                      response:responseBlock];
      
      fromDate = toDate;
      toDate   = [calendar dateByAddingComponents:dayComponent toDate:fromDate options:0];
    }
    
    if (toDate.timeIntervalSinceReferenceDate > currDate.timeIntervalSinceReferenceDate) {
      toDate = currDate;
    }
    
    [self getSystemsInfoFrom:fromDate
                          to:toDate
                    progress:progressBlock
                    response:responseBlock];
  }
}

+ (void)getSystemsInfoFrom:(NSDate *)fromDate to:(NSDate *)toDate progress:(ProgressBlock)progress response:(void(^)(NSArray *response, NSError *error))response {
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString *from = [formatter stringFromDate:fromDate];
  NSString *to   = [formatter stringFromDate:toDate];
  
  NSLog(@"Fetching delta systems from %@ to %@!", from, to);
  
  [self setup];
  
  [self callApi:@"api-v1/systems"
     concurrent:NO
     withMethod:@"GET"
progressCallBack:progress
responseCallback:^(id output, NSError *error) {
  
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/systems"}];
  
  //  NSLog(@"ERR: %@", error);
  //  NSLog(@"RES: %@", response);
  
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
     parameters:5,
   @"startdatetime", from,   // <-- return only systems updated after this date
   @"endDateTime",   to,     // <-- return only systems updated before this date
   @"known",         @"1",   // <-- return only systems with known coordinates
   @"coords",        @"1",   // <-- include system coordinates
   //@"distances",     @"1", // <-- include distances from other susyems
   @"problems",      @"1"    // <-- include information about known errors
   //@"includeHidden", @"1"  // <-- include systems with wrong names or wrong distances
   ];
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
     concurrent:YES
     withMethod:@"POST"
progressCallBack:nil
responseCallback:^(id output, NSError *error) {
  
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/get-logs"}];
  
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
  
  NSString   *name       = jump.system.name;
  NSString   *timestamp  = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp]];
  NSString   *appName    = [NSBundle.mainBundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
  NSString   *appVersion = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
  BOOL        sendCoords = NO;
  
  if ([jump.system hasCoordinates] == YES) {
    sendCoords = YES;
  }
  
  void (^responseBlock)(id output, NSError *error) = ^void(id output, NSError *error) {
    [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/set-log"}];
    
    if (error == nil) {
      NSError      *error = nil;
      NSDictionary *data  = [NSJSONSerialization JSONObjectWithData:output options:0 error:&error];
      
      if ([data isKindOfClass:NSDictionary.class]) {
        NSInteger result = [data[@"msgnum"] integerValue];
        
        //100 --> success
        //401 --> An entry for the same system already exists at that date -> success
        
        if (result == 100 || result == 401) {
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
  };
  
  [self setup];
  
  if (sendCoords == YES) {
    [self callApi:@"api-logs-v1/set-log"
       concurrent:YES
       withMethod:@"POST"
 progressCallBack:nil
 responseCallback:responseBlock
       parameters:9,
     @"systemName", name,
     @"commanderName", commanderName,
     @"apiKey", apiKey,
     @"fromSoftware", appName,
     @"fromSoftwareVersion", appVersion,
     @"x", [NSString stringWithFormat:@"%f", jump.system.x],
     @"y", [NSString stringWithFormat:@"%f", jump.system.y],
     @"z", [NSString stringWithFormat:@"%f", jump.system.z],
     @"dateVisited", timestamp
     ];
  }
  else {
    [self callApi:@"api-logs-v1/set-log"
       concurrent:YES
       withMethod:@"POST"
 progressCallBack:nil
 responseCallback:responseBlock
       parameters:6,
     @"systemName", name,
     @"commanderName", commanderName,
     @"apiKey", apiKey,
     @"fromSoftware", appName,
     @"fromSoftwareVersion", appVersion,
     @"dateVisited", timestamp
     ];
  }
}

+ (void)deleteJump:(Jump *)jump forCommander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response {
  NSAssert(jump != nil, @"missing jump");
  NSAssert(jump.edsm != nil, @"jump not sent to EDSM");
  
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  
  formatter.timeZone   = [NSTimeZone timeZoneWithAbbreviation:@"UTC"];
  formatter.dateFormat = @"yyyy-MM-dd HH:mm:ss";
  
  NSString   *name       = jump.system.name;
  NSString   *timestamp  = [formatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:jump.timestamp]];
  NSString   *appName    = [NSBundle.mainBundle objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
  NSString   *appVersion = [NSString stringWithFormat:@"%@", [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
  
  [self setup];
  
  [self callApi:@"api-logs-v1/delete-log"
     concurrent:YES
     withMethod:@"POST"
progressCallBack:nil
responseCallback:^(id output, NSError *error) {
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/delete-log"}];
  
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
     parameters:6,
   @"systemName", name,
   @"commanderName", commanderName,
   @"apiKey", apiKey,
   @"fromSoftware", appName,
   @"fromSoftwareVersion", appVersion,
   @"dateVisited", timestamp
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
     concurrent:YES
     withMethod:@"POST"
progressCallBack:nil
responseCallback:^(id output, NSError *error) {
  
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/get-comments"}];
  
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
     concurrent:YES
     withMethod:@"POST"
progressCallBack:nil
responseCallback:^(id output, NSError *error) {
  
  [Answers logCustomEventWithName:@"EDSM API call" customAttributes:@{@"API":@"api-v1/set-comment"}];
  
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
