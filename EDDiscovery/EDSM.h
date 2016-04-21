//
//  EDSM.h
//  EDDiscovery
//
//  Created by thorin on 19/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Jump;

NS_ASSUME_NONNULL_BEGIN

@interface EDSM : NSManagedObject

+ (EDSM *)instance;

@property(nonatomic, strong) NSString *apiKey;

- (void)syncJumpsWithEDSM;
- (void)sendJumpToEDSM:(Jump *)jump;

@end

NS_ASSUME_NONNULL_END

#import "EDSM+CoreDataProperties.h"
