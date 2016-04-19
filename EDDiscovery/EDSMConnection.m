//
//  EDSMConnection.m
//  EDDiscovery
//
//  Created by thorin on 17/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "EDSMConnection.h"

#define BASE_URL @"http://www.edsm.net/api-v1"
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
  
  [self callApi:@"system"
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
  NSURL        *url     = [NSURL URLWithString:@"http://www.edsm.net/dump/systemsWithCoordinates.json"];
  NSURLRequest *request = [NSURLRequest requestWithURL:url];
  
//  NSURLResponse *urlResponse = nil;
//  NSError       *error       = nil;
//  NSData        *output      = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
  
  [NSURLConnection sendAsynchronousRequest:request
                                     queue:NSOperationQueue.mainQueue
                         completionHandler:^(NSURLResponse *urlResponse, NSData *output, NSError *error) {
  
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
                           
                         }];
}

+ (void)getSystemsInfoWithResponse:(void(^)(NSArray *response, NSError *error))response {
  NSDate           *lastSyncDate = [NSUserDefaults.standardUserDefaults objectForKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];
  NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
  
  dayComponent.day = -6;
  
  NSCalendar       *calendar     = [NSCalendar currentCalendar];
  NSDate           *minDate      = [calendar dateByAddingComponents:dayComponent toDate:NSDate.date options:0];
  
  [NSUserDefaults.standardUserDefaults setObject:lastSyncDate forKey:EDSM_SYSTEM_UPDATE_TIMESTAMP];

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
    formatter.dateFormat = @"yyyy-MM-dd HH-mm-ss";
    
    NSString *from = [formatter stringFromDate:lastSyncDate];
    
    lastSyncDate = NSDate.date;
    
    [self callApi:@"systems"
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

@end
