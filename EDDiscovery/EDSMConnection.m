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
responseCallback:^(id response, NSError *error) {
  
//  NSLog(@"ERR: %@", error);
//  NSLog(@"RES: %@", response);
  
}
     parameters:3,
   @"sysname", systemName,
   @"coords", @"1",
   @"distances", @"1"
   ];
}

@end
