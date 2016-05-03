//
//  SystemData.h
//  EDDiscovery
//
//  Created by thorin on 03/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

@class System;

@interface SystemData : NSObject

+ (double)distance:(System *)s1 :(System *)s2;
+ (double)distanceX2:(System *)s1 :(System *)s2;

@end
