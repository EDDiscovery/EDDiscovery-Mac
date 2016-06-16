//
//  NetLogParser.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>

#define DEFAULT_SCREENSHOTS_DIR [NSSearchPathForDirectoriesInDomains(NSPicturesDirectory, NSUserDomainMask, YES).firstObject stringByAppendingPathComponent:@"Frontier Developments/Elite Dangerous"]

@class Commander;

@interface ScreenshotMonitor : NSObject

+ (nullable ScreenshotMonitor *)instanceOrNil:(Commander * __nonnull)commander;
+ (nullable ScreenshotMonitor *)createInstanceForCommander:(Commander * __nonnull)commander;

- (void)startInstance:(void(^__nonnull)(void))completionBlock;
- (void)stopInstance;

@end
