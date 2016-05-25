//
//  EDSM.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 19/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#define EDSM_ACCOUNT_KEY @"EDSMAccount"

NS_ASSUME_NONNULL_BEGIN

@class Jump;
@class System;
@class Note;
@class Commander;

@interface EDSM : NSManagedObject

+ (void)sendDistancesToEDSM:(System *)system response:(void(^)(BOOL distancesSubmitted, BOOL systemTrilaterated))response;

- (void)syncJumpsWithEDSM:(void(^)(void))response;
- (void)sendJumpToEDSM:(Jump *)jump;
- (void)sendNoteToEDSM:(NSString *)note forSystem:(NSString *)system;
- (void)deleteJumpFromEDSM:(Jump *)jump;

@property(nullable, nonatomic, strong) NSString *apiKey;

@end

NS_ASSUME_NONNULL_END

#import "EDSM+CoreDataProperties.h"
