//
//  EventLogger.m
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "EventLogger.h"

@implementation EventLogger

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
  
  return self;
}

#pragma mark -
#pragma mark user-visible debug logging

- (void)addLog:(NSString *)msg {
  [self addLog:msg timestamp:YES newline:YES];
}

- (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  NSMutableString *value = [NSMutableString stringWithString:self.textView.string];
  
  if (newline) {
    [value appendString:@"\n"];
  }
  
  if (timestamp) {
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"HH:mm:ss - ";
    
    [value appendString:[formatter stringFromDate:NSDate.date]];
  }
  
  [value appendString:msg];
  
  [self.textView setString:value];
  [self.textView scrollRangeToVisible:NSMakeRange([value length], 0)];
}

@end
