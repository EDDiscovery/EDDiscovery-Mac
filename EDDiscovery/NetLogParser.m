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
#import "NetLogFile.h"
#import "CoreDataManager.h"
#import "System.h"
#import "Jump.h"

#define LOG_DIR_PATH @"/Users/thorin/Library/Application Support/Frontier Developments/Elite Dangerous/Logs"


@implementation NetLogParser {
  NetLogFile *currNetLogFile;
  Jump       *lastJump;
  UKKQueue   *queue;
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
    [EventLogger addLog:@"Log directory contents changed"];
    [self scanLogFilesDir];
  }
  else {
    [EventLogger addProcessingStep];
    [self parseNetLogFile:currNetLogFile systems:nil names:nil];
  }
}

#pragma mark -
#pragma mark log directory scanning

- (void)scanLogFilesDir {
#define FILE_KEY @"file"
#define ATTR_KEY @"attr"
  
  if (currNetLogFile != nil) {
    [queue removePathFromQueue:currNetLogFile.path];
  }
  
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:LOG_DIR_PATH error:nil];
  
  [EventLogger addLog:[NSString stringWithFormat:@"Got %ld files in log directory", files.count]];
  
  NSMutableArray *netLogFiles = [NSMutableArray array];
  
  for (NSString *file in files) {
    if ([file rangeOfString:@"netLog."].location == 0) {
      [netLogFiles addObject:file];
    }
  }
  
  [EventLogger addLog:[NSString stringWithFormat:@"Got %ld netLog files in log directory", netLogFiles.count]];
  
  NSMutableArray *netLogs = [NSMutableArray arrayWithCapacity:netLogFiles.count];
  
  for (NSString *file in netLogFiles) {
    NSString     *path  = [LOG_DIR_PATH stringByAppendingPathComponent:file];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    
    if (attrs != nil) {
      [netLogs addObject:@{FILE_KEY:file, ATTR_KEY:attrs}];
    }
  }
  
  // sort
  [netLogs sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:[NSString stringWithFormat:@"%@.%@", ATTR_KEY, NSFileModificationDate] ascending:YES]]];
  
  NSManagedObjectContext *context = [CoreDataManager.instance managedObjectContext];
  NSError                *error   = nil;
  
#ifdef DEBUG
  NSUInteger     count = 0;
  NSTimeInterval start = 0;
  NSTimeInterval end   = 0;
#endif
  
  //parse all netlog files
  if (netLogs.count > 0) {
    NSMutableArray *systems   = nil;
    NSMutableArray *names     = nil;
    NSTimeInterval  ti        = [NSDate timeIntervalSinceReferenceDate];
    NSUInteger      numParsed = 0;
    
    if (netLogs.count > 1) {
      systems = [[System allSystemsInContext:context] mutableCopy];
      names   = [NSMutableArray arrayWithCapacity:systems.count];
      
      for (System *aSystem in systems) {
        [names addObject:aSystem.name];
      }
    }
    
    for (NSDictionary *netLogData in netLogs) {
      NSString   *netLog     = netLogData[FILE_KEY];
      NSString   *path       = [LOG_DIR_PATH stringByAppendingPathComponent:netLog];
      NetLogFile *netLogFile = [NetLogFile netLogFileWithPath:path inContext:context];
      
      if (netLogFile == nil) {
        NSString *className = NSStringFromClass(NetLogFile.class);
        
        netLogFile = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
        
        netLogFile.path = path;
      }
      
      if (netLogFile.complete == NO) {
        [EventLogger addLog:[NSString stringWithFormat:@"Parsing netLog file: %@", netLog]];
        
        if ([netLog isEqualToString:netLogs.lastObject[FILE_KEY]] == NO) {
          netLogFile.complete = YES;
        }
        
        [self parseNetLogFile:netLogFile systems:systems names:names];
        
        numParsed++;
      }
      
      if ([netLog isEqualToString:netLogs.lastObject[FILE_KEY]] == YES) {
        currNetLogFile = netLogFile;
        
        [queue addPathToQueue:currNetLogFile.path];
      }
      
#ifdef DEBUG
      NSOrderedSet<Jump *> *jumps = netLogFile.jumps;
      
      if (jumps > 0) {
        count += jumps.count;
        
        if (start == 0) {
          start = jumps.firstObject.timestamp;
        }
        
        end = jumps.lastObject.timestamp;
      }
#endif
    }
    
    if (numParsed > 1) {
      ti = [NSDate timeIntervalSinceReferenceDate] - ti;
    
      [EventLogger addLog:[NSString stringWithFormat:@"Parsed %ld netLog files in %.1f seconds", (long)numParsed, ti]];
    }
  }
  
  [context save:&error];
  
  if (error != nil) {
    NSLog(@"ERROR saving context: %@", error);
    
    exit(-1);
  }
  
#ifdef DEBUG
  NSDateFormatter *dateTimeFormatter = [[NSDateFormatter alloc] init];
  
  dateTimeFormatter.dateFormat = @"yyyy-MM-dd";
  
  NSString *from = [dateTimeFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:start]];
  NSString *to   = [dateTimeFormatter stringFromDate:[NSDate dateWithTimeIntervalSinceReferenceDate:end]];
  NSString *msg  = [NSString stringWithFormat:@"Recorded %ld jumps from %@ to %@", (long)count, from, to];
  
  [EventLogger addLog:msg];
#endif
}

#pragma mark -
#pragma mark log file scanning

- (void)parseNetLogFile:(NetLogFile *)netLogFile systems:(NSMutableArray *)systems names:(NSMutableArray *)names {
  static NSString     *currPath   = nil;
  static NSFileHandle *fileHandle = nil;
  static NSString     *fileDate   = nil;
  
  if (netLogFile != nil) {
    if ([currPath isEqualToString:netLogFile.path] == NO) {
      currPath = netLogFile.path;
      
      [fileHandle closeFile];
      fileHandle = [NSFileHandle fileHandleForReadingAtPath:currPath];
      
      [fileHandle seekToFileOffset:netLogFile.fileOffset];
      
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
        
        [self parseNetLogRecord:record inFile:netLogFile referenceDate:fileDate systems:systems names:names];
      }
    }
    
    netLogFile.fileOffset = fileHandle.offsetInFile;

    NSUInteger count=0;
    
    for (Jump *jump in netLogFile.jumps) {
      if (jump.objectID.isTemporaryID == YES) {
        count++;
        
        if (netLogFile.complete == NO) {
          NSString *msg = [NSString stringWithFormat:@"Jump to %@ (num visits: %ld)", jump.system.name, (long)jump.system.jumps.count];
          
          if (jump.system.haveCoordinates == NO) {
            [EDSMConnection getSystemInfo:jump.system.name response:^(NSDictionary *response, NSError *error) {
              if (response != nil) {
                [jump.system parseEDSMData:response];
              }
            }];
          }
          else {
            msg = [msg stringByAppendingFormat:@" - x=%f, y=%f, z=%f", jump.system.x, jump.system.y, jump.system.z];
          }
          
          [EventLogger addLog:msg];
        }
      }
    }

    if (netLogFile.complete == YES && count > 0) {
      [EventLogger addLog:[NSString stringWithFormat:@"Parsed %ld new jumps.", (long)count]];
    }
    
    NSError *error = nil;
    
    [netLogFile.managedObjectContext save:&error];
    
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
      
      exit(-1);
    }
  }
}

- (void)parseNetLogRecord:(NSString *)record inFile:(NetLogFile *)netLogFile referenceDate:(NSString *)referenceDateTime systems:(NSMutableArray *)systems names:(NSMutableArray *)names {
  NSManagedObjectContext *context = netLogFile.managedObjectContext;
  NSDate                 *date    = [self parseDateOfRecord:record referenceDateTime:referenceDateTime];
  NSString               *name    = [self parseSystemNameOfRecord:record];
  System                 *system  = nil;
  
  if (systems == nil || names == nil) {
    system = [System systemWithName:name inContext:context];
  }
  else {
    NSUInteger idx = [names indexOfObject:name];
    
    if (idx != NSNotFound) {
      system = systems[idx];
    }
  }
  
  if (lastJump == nil) {
    lastJump = [Jump getLastJumpInContext:context];
  }
  
  if (system == nil) {
    NSString *className = NSStringFromClass(System.class);
    
    system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    
    system.name = name;
    
    if (systems != nil && names != nil) {
      NSUInteger idx = [names indexOfObject:name
                              inSortedRange:(NSRange){0, names.count}
                                    options:NSBinarySearchingInsertionIndex
                            usingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
                              return [str1 compare:str2];
                            }];
      
      [names   insertObject:name   atIndex:idx];
      [systems insertObject:system atIndex:idx];
    }
  }
  
  //cannot have two subsequent jumps to the same system
  
  if ([lastJump.system.name isEqualToString:name] == NO) {
    NSString *className = NSStringFromClass(Jump.class);
    Jump     *jump      = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    
    jump.system     = system;
    jump.timestamp  = [date timeIntervalSinceReferenceDate];
    jump.netLogFile = netLogFile;
    
    lastJump = jump;
  }
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
  
  //OLD log files do not have seconds in file name... insert them if necessary
  if ([[referenceDateTime substringWithRange:NSMakeRange(10, 1)] isEqualToString:@"."]) {
    referenceDateTime = [[referenceDateTime substringToIndex:10] stringByAppendingString:@"00"];
  }
  
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

@end
