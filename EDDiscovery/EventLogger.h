//
//  EventLogger.h
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>

@interface EventLogger : NSObject

+ (EventLogger *)instance;

+ (void)clearLogs;
+ (void)addWarning:(NSString *)msg;
+ (void)addError:(NSString *)msg;
+ (void)addLog:(NSString *)msg;
+ (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline;

+ (NSNumberFormatter *)loggingNumberFormatter;

@property(nonatomic, strong)   NSTextView *textView;
@property(nonatomic, readonly) NSString   *currLine;

@end
