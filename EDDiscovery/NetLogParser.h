//
//  NetLogParser.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

#define LOG_DIR_PATH_SETING_KEY  @"logDirPathSettingKey"
#define DEFAULT_LOG_DIR_PATH_DIR [NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Frontier Developments/Elite Dangerous/Logs"]

@interface NetLogParser : NSObject

+ (NetLogParser *)instanceWithPath:(NSString *)path;

@end
