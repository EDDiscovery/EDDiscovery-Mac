//
//  EDSM.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 19/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

#define EDSM_CMDR_NAME_KEY @"EDSMCmdrNameKey"
#define EDSM_API_KEY_KEY   @"EDSMApiKeyKey"

@class Jump;
@class System;

NS_ASSUME_NONNULL_BEGIN

@interface EDSM : NSManagedObject

+ (EDSM *)instance;

@property(nonatomic, readonly) NSString *apiKey;

- (void)syncJumpsWithEDSM;
- (void)sendJumpToEDSM:(Jump *)jump;

- (void)setCommentForSystem:(System *)system;

@end

NS_ASSUME_NONNULL_END

#import "EDSM+CoreDataProperties.h"
