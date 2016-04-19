//
//  EDSMConnection.h
//  EDDiscovery
//
//  Created by thorin on 17/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "HttpApiManager.h"
#import "System.h"

#define EDSM_SYSTEM_UPDATE_TIMESTAMP @"edsmSystemUpdateTimestamp"

@interface EDSMConnection : HttpApiManager

+ (void)getSystemsInfoWithResponse:(void(^)(NSArray *response, NSError *error))response;
+ (void)getSystemInfo:(NSString *)systemName response:(void(^)(NSDictionary *response, NSError *error))response;
+ (void)getTravelLogsWithResponse:(void(^)(NSDictionary *response, NSError *error))response;

@end
