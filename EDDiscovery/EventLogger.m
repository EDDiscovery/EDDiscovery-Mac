//
//  EventLogger.m
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "EventLogger.h"

@implementation EventLogger {
  NSMutableString *text;
}

#pragma mark -
#pragma mark instance management

+ (EventLogger *)instance {
  static EventLogger *instance = nil;
  
  if (instance == nil) {
    instance = [[EventLogger alloc] initInstance];
  }
  
  return instance;
}

- (id)init {
  NSAssert(NO, @"This class should never be instantiated directly!");
  
  return nil;
}

- (id)initInstance {
  self = [super init];
  
  if (self != nil) {
    text = [[NSMutableString alloc] init];
  }
  
  return self;
}

#pragma mark -
#pragma mark user-visible debug logging

+ (void)addLog:(NSString *)msg {
  [self addLog:msg timestamp:YES newline:YES];
}

+ (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  [self.instance addLog:msg timestamp:timestamp newline:newline];
}

+ (void)addProcessingStep {
  [self.instance addProcessingStep];
}

- (void)addProcessingStep {
  if (text.length == 0) {
    [text appendString:@"\n"];
  }
  else if ([text hasSuffix:@"."] == NO) {
    [text appendString:@"\n"];
  }
  
  [text appendString:@"."];
  
  [self.textView setString:text];
  [self.textView scrollRangeToVisible:NSMakeRange(text.length, 0)];
}

- (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  NSLog(@"%@", msg);
  
  if (newline) {
    [text appendString:@"\n"];
  }
  
  if (timestamp) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"HH:mm:ss - ";
    
    [text appendString:[formatter stringFromDate:NSDate.date]];
  }
  
  [text appendString:msg];
  
  [self.textView setString:text];
  [self.textView scrollRangeToVisible:NSMakeRange(text.length, 0)];
}

@end
