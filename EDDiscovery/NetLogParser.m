//
//  NetLogParser.m
//  EDDiscovery
//
//  Created by thorin on 18/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "NetLogParser.h"

#import "UKKQueue.h"
#import "EDSMConnection.h"
#import "EventLogger.h"

#define LOG_DIR_PATH @"/Users/thorin/Library/Application Support/Frontier Developments/Elite Dangerous/Logs"


@implementation NetLogParser {
  NSString *currNetLog;
  UKKQueue *queue;
}

#pragma mark -
#pragma mark instance management

+ (NetLogParser *)instance {
  static NetLogParser *instance = nil;
  
  if (instance == nil) {
    instance = [[NetLogParser alloc] initInstance];
  }
  
  return instance;
}

- (id)init {
  NSAssert(NO, @"This class should never be instantiated directly!");
  
  return nil;
}

- (id)initInstance {
  self = [super init];
  
  if (self) {
    queue = [UKKQueue sharedFileWatcher];
    
    [queue setDelegate:self];
    [queue addPathToQueue:LOG_DIR_PATH];
    
    [self scanLogFilesDir];
  }
  
  return self;
}

#pragma mark -
#pragma mark UKKQueue delegate

- (void)watcher:(id<UKFileWatcher>)kq receivedNotification:(NSString *)nm forPath:(NSString *)path {
  if ([path isEqualToString:LOG_DIR_PATH]) {
    [EventLogger.instance addLog:@"Log directory contents changed"];
    [self scanLogFilesDir];
  }
  else {
    [EventLogger.instance addLog:@"." timestamp:NO newline:NO];
    [self parseNetLogFile:path];
  }
}

#pragma mark -
#pragma mark log directory scanning

- (void)scanLogFilesDir {
#define FILE_KEY @"file"
#define ATTR_KEY @"attr"
  
  if (currNetLog.length > 0) {
    [queue removePathFromQueue:currNetLog];
  }
  
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:LOG_DIR_PATH error:nil];
  
  [EventLogger.instance addLog:[NSString stringWithFormat:@"Got %ld files in log directory", files.count]];
  
  NSMutableArray *netLogFiles = [NSMutableArray array];
  
  for (NSString *file in files) {
    if ([file rangeOfString:@"netLog."].location == 0) {
      [netLogFiles addObject:file];
    }
  }
  
  [EventLogger.instance addLog:[NSString stringWithFormat:@"Got %ld netLog files in log directory", netLogFiles.count]];
  
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
    
    [EventLogger.instance addLog:[NSString stringWithFormat:@"Latest netLog: %@", netLog]];
    
    [queue addPathToQueue:currNetLog];
    
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
      
      fileDate = [[currPath lastPathComponent] substringWithRange:NSMakeRange(7, 12)];
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

- (void)parseNetLogRecord:(NSString *)record referenceDate:(NSString *)referenceDateTime {
#define SYSTEM_KEY @"system"
#define TIMESTAMP_KEY @"timrstamp"
#define FLIGHT_TYPE_KEY @"space"
  
  NSDate   *date      = [self parseDateOfRecord:record referenceDateTime:referenceDateTime];
  NSString *system     = [self parseSystemNameOfRecord:record];
  NSString *flightType = [self parseFlightTypeOfRecord:record];
  
  NSDateFormatter *dateTimeFormatter = [[NSDateFormatter alloc] init];
  
  dateTimeFormatter.dateFormat = @"yyyyMMdd HH:mm:ss";
  
  NSString *dateTime = [dateTimeFormatter stringFromDate:date];
  
  NSDictionary *parsed = @{SYSTEM_KEY:system,
                           TIMESTAMP_KEY:date,
                           FLIGHT_TYPE_KEY:flightType};
  
  NSLog(@"%@ ==> %@ ==> %@", [record substringWithRange:NSMakeRange(1, 8)], dateTime, parsed);
  
  [EDSMConnection getSystemInfo:system response:^(NSDictionary *response, NSError *error) {
    
  }];
  
  [EventLogger.instance addLog:record timestamp:NO newline:YES];
}

- (NSDate *)parseDateOfRecord:(NSString *)record referenceDateTime:(NSString *)referenceDateTime {
  //netLog records have this format
  //{00:19:00} System:11(Frecku US-U d2-11) Body:1 Pos:(1.67497e+10,-2.85834e+07,1.1919e+09) Supercruise
  //{00:23:21} System:11(Frecku US-U d2-11) Body:17 Pos:(1.96291e+07,-2.16646e+07,5.13991e+07) NormalFlight
  
  static NSString        *strRefDateTime    = nil;
  static NSDate          *refDateTime       = nil;
  static NSString        *refStrDate        = nil;
  static NSDateFormatter *dateTimeFormatter = nil;
  static NSDateFormatter *dateFormatter     = nil;
  static dispatch_once_t  onceToken;
  
  dispatch_once(&onceToken, ^{
    dateTimeFormatter = [[NSDateFormatter alloc] init];
    dateFormatter     = [[NSDateFormatter alloc] init];
    
    //reference date format
    //160415232458
    dateTimeFormatter.dateFormat = @"yyMMddHHmmss";
    dateFormatter.dateFormat     = @"yyMMdd";
  });
  
  if ([strRefDateTime isEqualToString:referenceDateTime] == NO) {
    strRefDateTime = referenceDateTime;
    refDateTime    = [dateTimeFormatter dateFromString:strRefDateTime];
    refStrDate     = [dateFormatter stringFromDate:refDateTime];
  }
  
  NSString *strTime     = [[record substringWithRange:NSMakeRange(1, 8)] stringByReplacingOccurrencesOfString:@":" withString:@""];
  NSString *strDateTime = [NSString stringWithFormat:@"%@%@", refStrDate, strTime];
  NSDate   *dateTime    = [dateTimeFormatter dateFromString:strDateTime];
  
  // add 1 day to reference date if dates in netlog file wrapped
  
  if ([refDateTime earlierDate:dateTime] == dateTime) {
    NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
    NSCalendar       *calendar     = [NSCalendar currentCalendar];
    
    dayComponent.day = 1;
    
    refDateTime = [calendar dateByAddingComponents:dayComponent toDate:refDateTime options:0];
    refStrDate  = [dateFormatter stringFromDate:refDateTime];
    refDateTime = [dateFormatter dateFromString:refStrDate]; //otherwise refDateTime will be incorrect for subsequent calculations
    strDateTime = [NSString stringWithFormat:@"%@%@", refStrDate, strTime];
    dateTime    = [dateTimeFormatter dateFromString:strDateTime];
  }
  
  return dateTime;
}

- (NSString *)parseSystemNameOfRecord:(NSString *)record {
  NSRange range = [record rangeOfString:@"System:"];
  
  record = [record substringFromIndex:range.location + range.length];
  
  NSRange range1 = [record rangeOfString:@"("];
  NSRange range2 = [record rangeOfString:@")"];
  
  range  = NSMakeRange(range1.location + 1, range2.location - range1.location - 1);
  record = [record substringWithRange:range];
  
  return record;
}

- (NSString *)parseFlightTypeOfRecord:(NSString *)record {
  NSArray *words = [record componentsSeparatedByString:@" "];
  
  record = [words.lastObject stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  
  return record;
}

@end
