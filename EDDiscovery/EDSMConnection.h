//
//  EDSMConnection.h
//  EDDiscovery
//
//  Created by thorin on 17/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "HttpApiManager.h"

@interface EDSMConnection : HttpApiManager

+ (void)getSystemInfo:(NSString *)systemName response:(void(^)(NSDictionary *response, NSError *error))response;

@end
