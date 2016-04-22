//
//  EDSM.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 19/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Jump;
@class System;

NS_ASSUME_NONNULL_BEGIN

@interface EDSM : NSManagedObject

+ (EDSM *)instance;

@property(nonatomic, strong) NSString *apiKey;

- (void)syncJumpsWithEDSM;
- (void)sendJumpToEDSM:(Jump *)jump;

- (void)setCommentForSystem:(System *)system;

@end

NS_ASSUME_NONNULL_END

#import "EDSM+CoreDataProperties.h"
