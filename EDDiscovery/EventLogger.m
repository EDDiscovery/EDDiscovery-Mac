//
//  EventLogger.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "EventLogger.h"

@implementation EventLogger {
  NSMutableString *currLine;
  NSTextView      *textView;
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
    currLine = [[NSMutableString alloc] init];
  }
  
  return self;
}

#pragma mark -
#pragma mark properties

@synthesize currLine;

- (NSTextView *)textView {
  return textView;
}

- (void)setTextView:(NSTextView *)newTextView {
  if (textView != newTextView) {
    NSAttributedString *string = (textView != nil) ? self.textView.attributedString : nil;
    
    textView = newTextView;
    
    if (string != nil) {
      textView.textStorage.attributedString = string;
    
      [self.textView scrollRangeToVisible:NSMakeRange(self.textView.string.length, 0)];
    }
  }
}

+ (NSNumberFormatter *)loggingNumberFormatter {
  static NSNumberFormatter *numberFormatter = nil;
  static dispatch_once_t    onceToken;
  
  dispatch_once(&onceToken, ^{
    numberFormatter = [[NSNumberFormatter alloc] init];
    
    numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;
  });
  
  return numberFormatter;
}

#pragma mark -
#pragma mark user-visible debug logging

+ (void)clearLogs {
  NSString *appName    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
  NSString *appVersion = [NSString stringWithFormat:
                          @"%@ (build %@)",
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]];
  
  [self.instance clearLogs];
  
  [self addLog:[NSString stringWithFormat:@"Welcome to %@ %@", appName, appVersion]];
}

+ (void)addError:(NSString *)msg {
  NSDictionary *attrs = @{NSForegroundColorAttributeName:NSColor.redColor};
  
  [self.instance addLog:msg timestamp:YES newline:YES attributes:attrs];
}

+ (void)addWarning:(NSString *)msg {
  NSDictionary *attrs = @{NSForegroundColorAttributeName:NSColor.orangeColor};
  
  [self.instance addLog:msg timestamp:YES newline:YES attributes:attrs];
}

+ (void)addLog:(NSString *)msg {
  [self addLog:msg timestamp:YES newline:YES];
}

+ (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  [self.instance addLog:msg timestamp:timestamp newline:newline attributes:nil];
}

- (void)clearLogs {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.textView setString:@""];
    [currLine setString:@""];
  });
}

- (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline attributes:(NSDictionary *)attributes {
  dispatch_async(dispatch_get_main_queue(), ^{
    static NSDateFormatter *formatter = nil;
    static dispatch_once_t  onceToken;
    
    NSAttributedString *attr = nil;
    
    dispatch_once(&onceToken, ^{
      formatter = [[NSDateFormatter alloc] init];
      
      formatter.dateFormat = @"HH:mm:ss - ";
    });
    
    if (newline == YES) {
      NSLog(@"%@", msg);
    }
    
    if (self.textView.string.length > 0 && newline) {
      attr = [[NSAttributedString alloc] initWithString:@"\n" attributes:nil];
      
      [self.textView.textStorage appendAttributedString:attr];
      [currLine setString:@""];
    }
    
    if (timestamp) {
      NSString *str = [formatter stringFromDate:NSDate.date];
      
      attr = [[NSAttributedString alloc] initWithString:str attributes:attributes];
      
      [self.textView.textStorage appendAttributedString:attr];
      [currLine appendString:str];
    }
    
    attr = [[NSAttributedString alloc] initWithString:msg attributes:attributes];
    
    [self.textView.textStorage appendAttributedString:attr];
    [currLine appendString:msg];
    
    [self.textView scrollRangeToVisible:NSMakeRange(self.textView.string.length, 0)];
  });
}

@end
