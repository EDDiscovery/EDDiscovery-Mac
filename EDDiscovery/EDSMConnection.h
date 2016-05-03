//
//  EDSMConnection.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 17/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "HttpApiManager.h"
#import "System.h"

#define EDSM_SYSTEM_UPDATE_TIMESTAMP @"edsmSystemUpdateTimestamp"

@class Commander;

@interface EDSMConnection : HttpApiManager

//system info
+ (void)getSystemsInfoWithResponse:(void(^)(NSArray *response, NSError *error))response;
+ (void)getSystemInfo:(NSString *)systemName response:(void(^)(NSDictionary *response, NSError *error))response;

//system distances
+ (void)submitDistances:(NSData *)data  response:(void(^)(NSDictionary *response, NSError *error))response;

//commander travel logs
+ (void)getJumpsForCommander:(Commander *)commander response:(void(^)(NSArray *jumps, NSError *error))response;
+ (void)addJump:(Jump *)jump forCommander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response;

//commander comments
+ (void)getNotesForCommander:(Commander *)commander response:(void(^)(NSArray *comments, NSError *error))response;
+ (void)setNote:(NSString *)note system:(NSString *)system commander:(NSString *)commanderName apiKey:(NSString *)apiKey response:(void(^)(BOOL success, NSError *error))response;

@end
