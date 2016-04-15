//
//  ViewController.m
//  EDDiscovery
//
//  Created by thorin on 15/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "ViewController.h"

#import "UKKQueue.h"

#define LOG_DIR_PATH @"/Users/thorin/Library/Application Support/Frontier Developments/Elite Dangerous/Logs"

@implementation ViewController {
  IBOutlet NSTextView *textView;
  
  NSString *currNetLog;
}

#pragma mark -
#pragma mark UIViewController delegate

- (void)viewDidLoad {
  [super viewDidLoad];

  [self addLog:@"HELLO!!!"];
  
  [[UKKQueue sharedFileWatcher] setDelegate:self];
  [[UKKQueue sharedFileWatcher] addPathToQueue:LOG_DIR_PATH];
  
  [self scanLogFilesDir];
}

#pragma mark -
#pragma mark UKKQueue delegate

- (void)watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString *)nm forPath:(NSString *)path {
  if ([path isEqualToString:LOG_DIR_PATH]) {
    [self addLog:@"Log directory contents changed"];
    [self scanLogFilesDir];
  }
  else {
    [self addLog:@"." timestamp:NO newline:NO];
    [self parseNetLogFile:path];
  }
}

#pragma mark -
#pragma mark log directory scanning

- (void)scanLogFilesDir {
#define FILE_KEY @"file"
#define ATTR_KEY @"attr"

  if (currNetLog.length > 0) {
    [[UKKQueue sharedFileWatcher] removePathFromQueue:currNetLog];
  }
  
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:LOG_DIR_PATH error:nil];
  
  [self addLog:[NSString stringWithFormat:@"Got %ld files in log directory", files.count]];
  
  NSMutableArray *netLogFiles = [NSMutableArray array];
  
  for (NSString *file in files) {
    if ([file rangeOfString:@"netLog."].location == 0) {
      [netLogFiles addObject:file];
    }
  }
  
  [self addLog:[NSString stringWithFormat:@"Got %ld netLog files in log directory", netLogFiles.count]];
  
  NSMutableArray *netLogs = [NSMutableArray arrayWithCapacity:netLogFiles.count];
  
  for (NSString *file in netLogFiles) {
    NSString     *path  = [LOG_DIR_PATH stringByAppendingPathComponent:file];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    
    if (attrs != nil) {
      [netLogs addObject:@{FILE_KEY:file, ATTR_KEY:attrs}];
    }
  }
  
  // sort inverted as we want latest date first
  [netLogs sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:[NSString stringWithFormat:@"%@.%@", ATTR_KEY, NSFileModificationDate] ascending:NO]]];
  
  if (netLogs.count > 0) {
    NSString *netLog = netLogs.firstObject[FILE_KEY];
    
    currNetLog = [LOG_DIR_PATH stringByAppendingPathComponent:netLog];
  
    [self addLog:[NSString stringWithFormat:@"Latest netLog: %@", netLog]];
  
    [[UKKQueue sharedFileWatcher] addPathToQueue:currNetLog];
    
    [self parseNetLogFile:currNetLog];
  }
}

#pragma mark -
#pragma mark log file scanning

- (void)parseNetLogFile:(NSString *)path {
  static NSString     *currPath   = nil;
  static NSFileHandle *fileHandle = nil;
  static NSString     *fileDate   = nil;
  
  if (path != nil) {
    if ([currPath isEqualToString:path] == NO) {
      currPath = path;
      
      [fileHandle closeFile];
      fileHandle = [NSFileHandle fileHandleForReadingAtPath:currPath];
      
      //extract date from file name
      //netLog.160415232458.01.log
      
      fileDate = [[currPath lastPathComponent] substringWithRange:NSMakeRange(7, 6)];
    }
    
    NSData   *data  = [fileHandle readDataToEndOfFile];
    NSString *text  = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray  *lines = [text componentsSeparatedByString:@"\n"];
    
    for (NSString *line in lines) {
      NSRange range = [line rangeOfString:@"System:"];
      
      if (range.location != NSNotFound && range.location >= 11) {
        NSString *record = [line substringFromIndex:(range.location-11)];
        
        [self parseNetLogRecord:record referenceDate:fileDate];
      }
    }
  }
}

//NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
//NSDate          *date       = nil;
//
//formatter.dateFormat = @"ddMMyy";
//
//fileDate = [[currPath lastPathComponent] substringWithRange:NSMakeRange(7, 6)];
//date     = [formatter dateFromString:fileDate];
//
//formatter.dateFormat = @"yyyyMMdd";
//
//fileDate = [formatter stringFromDate:date];

- (void)parseNetLogRecord:(NSString *)record referenceDate:(NSString *)referenceDate {
  static NSString       *refDate    = nil;
  static NSTimeInterval  dateOffset = 0;
  
  if ([refDate isEqualToString:referenceDate] == NO) {
    refDate    = referenceDate;
    dateOffset = 0;
  }
  
  [self addLog:record timestamp:NO newline:YES];
}

#pragma mark -
#pragma mark user-visible debug logging

- (void)addLog:(NSString *)msg {
#define SYSTEM_KEY @"system"
#define TIMESTAMP_KEY @"timrstamp"
#define FLIGHT_TYPE_KEY @"space"
  
  
  
  [self addLog:msg timestamp:YES newline:YES];
}

- (void)addLog:(NSString *)msg timestamp:(BOOL)timestamp newline:(BOOL)newline {
  NSMutableString *value = [NSMutableString stringWithString:textView.string];
  
  if (newline) {
    [value appendString:@"\n"];
  }
  
  if (timestamp) {
    [value appendFormat:@"%@", NSDate.date];
  }
  
  [value appendString:msg];
  
  [textView setString:value];
  [textView scrollRangeToVisible:NSMakeRange([value length], 0)];
}

@end
