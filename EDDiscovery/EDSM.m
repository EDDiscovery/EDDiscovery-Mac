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

@implementation EDSM

+ (void)syncJumpsInContext:(NSManagedObjectContext *)context {
  [EDSMConnection getTravelLogsWithResponse:^(NSDictionary *response, NSError *error) {
    
    NSInteger result = [response[@"msgnum"] integerValue];
    
    //100 --> success
    
    if (result == 100) {
      
      NSArray *travelLogs = response[@"logs"];
      
      NSLog(@"Got %ld travel logs from EDSM", (long)travelLogs.count);
      
    }
    else {
      
      NSLog(@"ERROR from EDSM: %ld - %@", (long)result, response[@"msg"]);
      
    }
    
  }];
}

+ (void)addJump:(Jump *)jump {
  NSLog(@"%s: TODO!!!", __FUNCTION__);
}

@end
