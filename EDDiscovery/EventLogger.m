//
//  EventLogger.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "EventLogger.h"

@implementation EventLogger {
  NSMutableString *text;
  NSMutableString *currLine;
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
    text     = [[NSMutableString alloc] init];
    currLine = [[NSMutableString alloc] init];
  }
  
  return self;
}

#pragma mark -
#pragma mark properties

@synthesize currLine;

#pragma mark -
#pragma mark user-visible debug logging

+ (void)addLog:(NSString *)msg {
  [self addLog:msg timestamp:YES newline:YES];
}

+ (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  [self.instance addLog:msg timestamp:timestamp newline:newline];
}

- (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  static NSDateFormatter *formatter = nil;
  static dispatch_once_t  onceToken;
  
  dispatch_once(&onceToken, ^{
    formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"HH:mm:ss - ";
  });
  
  NSLog(@"%@", msg);
  
  if (text.length > 0 && newline) {
    [text appendString:@"\n"];
    [currLine setString:@""];
  }
  
  if (timestamp) {
    NSString *str = [formatter stringFromDate:NSDate.date];
    
    [text appendString:str];
    [currLine appendString:str];
  }
  
  [text appendString:msg];
  [currLine appendString:msg];
  
  [self.textView setString:text];
  [self.textView scrollRangeToVisible:NSMakeRange(text.length, 0)];
}

@end
