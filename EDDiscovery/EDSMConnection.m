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
  
  NSURLResponse *urlResponse = nil;
  NSError       *error       = nil;
  NSData        *output      = [NSURLConnection sendSynchronousRequest:request returningResponse:&urlResponse error:&error];
  
//  [NSURLConnection sendAsynchronousRequest:request
//                                     queue:NSOperationQueue.mainQueue
//                         completionHandler:^(NSURLResponse *urlResponse, NSData *output, NSError *error) {
  
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
                           
//                         }];
}

+ (void)getSystemsInfo:(NSDate *)fromDate response:(void(^)(NSArray *response, NSError *error))response {
  if (fromDate == nil) {
    [self getNightlyDumpWithResponse:^(NSArray *output, NSError *error) {
      response(output, error);
    }];
  }
  else {
    [self setup];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"yyyy-MM-dd HH-mm-ss";
    
    NSString       *from    = @"2015-05-10 00:00:00";//@"2015-04-29 00:00:00";
    NSDate         *minDate = [formatter dateFromString:from];
    NSTimeInterval  minTi   = [minDate timeIntervalSinceReferenceDate];
    NSTimeInterval  ti      = [fromDate timeIntervalSinceReferenceDate];
    
    if (ti > minTi) {
      from = [formatter stringFromDate:fromDate];
    }
    
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
    }
    else {
      response(nil, error);
    }
  }
     parameters:3,
   //@"startdatetime", from,
   @"coords", @"1",
   @"distances", @"1",
   //@"submitted", @"1",
   @"known", @"1"
   ];
  }
}

@end
