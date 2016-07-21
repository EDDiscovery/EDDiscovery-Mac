//
//  NetLogParser.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "NetLogParser.h"

#import "VDKQueue.h"
#import "EDSMConnection.h"
#import "EDSM.h"
#import "EventLogger.h"
#import "NetLogFile.h"
#import "CoreDataManager.h"
#import "System.h"
#import "Jump.h"
#import "Commander.h"

#define GAMMA_LAUNCH_DATE @"141122130000"

@interface NetLogParser () <VDKQueueDelegate>
@end

@implementation NetLogParser {
  //access from any thread
  NSManagedObjectID *commanderID;
  NSString          *netLogFilesDir;
  NSString          *currFilePath;
  BOOL               firstRun;
  BOOL               running;
  
  //access from main thread
  VDKQueue          *queue;
}

#pragma mark -
#pragma mark instance management

static NetLogParser *instance = nil;

+ (nullable NetLogParser *)instanceOrNil:(Commander * __nonnull)commander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if (instance != nil) {
    if ([instance->commanderID isEqual:commander.objectID]) {
      return instance;
    }
  }
  
  return nil;
}

+ (nullable NetLogParser *)createInstanceForCommander:(Commander * __nonnull)commander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if ([self instanceOrNil:commander] != nil) {
    return instance;
  }
  else if (instance != nil) {
    [instance stopInstance];
  }
  
  instance = [[NetLogParser alloc] initInstance:commander];
  
  return instance;
}

- (id)init {
  NSAssert(NO, @"This class should never be instantiated directly!");
  
  return nil;
}

- (NetLogParser *)initInstance:(Commander *)commander {
  if ([NetLogParser netlogDirIsValid:commander.netLogFilesDir]) {
    self = [super init];
  
    if (self) {
      commanderID    = commander.objectID;
      netLogFilesDir = [commander.netLogFilesDir copy];
      currFilePath   = nil;
      firstRun       = YES;
      running        = NO;
    }
    
    return self;
  }
  
  return nil;
}

- (void)startInstance:(void(^__nonnull)(void))completionBlock {
  if (running == NO) {
    LoadingViewController.textField.stringValue = NSLocalizedString(@"Parsing netLog files", @"");
    
    running = YES;
    queue   = [[VDKQueue alloc] init];
    
    [queue setDelegate:self];
    [queue addPath:netLogFilesDir];

    [WORK_CONTEXT performBlock:^{
      [self scanNetLogFilesDir];
      
      [MAIN_CONTEXT performBlock:^{
        completionBlock();
      }];
    }];
  }
  else {
    completionBlock();
  }
}

- (void)stopInstance {
  running  = NO;
  instance = nil;
}

- (void)dealloc {
  queue.delegate = nil;
  
  if (currFilePath.length > 0) {
    [queue removePath:currFilePath];
  }
  
  if (netLogFilesDir.length > 0) {
    [queue removePath:netLogFilesDir];
  }
}

#pragma mark -
#pragma mark consistency checks

+ (BOOL)netlogDirIsValid:(NSString *)path {
  BOOL exists = NO;
  BOOL isDir  = NO;

  if (path != nil) {
    exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir];
  }

  return (exists && isDir);
}

#pragma mark -
#pragma mark VDKQueueDelegate delegate

- (void)VDKQueue:(VDKQueue *)aQueue receivedNotification:(NSString *)nm forPath:(NSString *)path {
  [WORK_CONTEXT performBlock:^{
    if ([path isEqualToString:netLogFilesDir]) {
      [self scanNetLogFilesDir];
    }
    else {
      [self parseCurrNetLogFile];
    }
  }];
}

#pragma mark -
#pragma mark log directory scanning

- (void)scanNetLogFilesDir {
#define FILE_KEY @"file"
#define ATTR_KEY @"attr"
  
  if (currFilePath != nil) {
    [MAIN_CONTEXT performBlock:^{
      [queue removePath:currFilePath];
    }];
  }
  
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:netLogFilesDir error:nil];
  
  if (firstRun) {
    [EventLogger addLog:[NSString stringWithFormat:@"Have %@ files in log directory", FORMAT(files.count)]];
  }
  
  NSMutableArray *netLogFiles = [NSMutableArray array];
  
  for (NSString *file in files) {
    if ([file rangeOfString:@"netLog."].location == 0) {
      [netLogFiles addObject:file];
    }
  }
  
  if (firstRun) {
    [EventLogger addLog:[NSString stringWithFormat:@"Have %@ netLog files in log directory", FORMAT(netLogFiles.count)]];
  }
  
  NSMutableArray *netLogsFilesAttrs = [NSMutableArray arrayWithCapacity:netLogFiles.count];
  
  for (NSString *file in netLogFiles) {
    NSString     *path  = [netLogFilesDir stringByAppendingPathComponent:file];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    
    if (attrs != nil) {
      [netLogsFilesAttrs addObject:@{FILE_KEY:file, ATTR_KEY:attrs}];
    }
  }
  
  // sort
  [netLogsFilesAttrs sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:[NSString stringWithFormat:@"%@.%@", ATTR_KEY, NSFileModificationDate] ascending:YES]]];
  
  //parse all netlog files
  if (netLogsFilesAttrs.count > 0) {
    Commander      *commander  = [WORK_CONTEXT existingObjectWithID:commanderID error:nil];
    NSTimeInterval  ti         = [NSDate timeIntervalSinceReferenceDate];
    NSUInteger      numParsed  = 0;
    NSUInteger      numJumps   = 0;
    NSMutableArray *allSystems = nil;
    NSMutableArray *allNames   = nil;
    NSMutableArray *allJumps   = nil;
    Jump           *lastJump   = nil;
    
    double progressValue = 0;
    
    [MAIN_CONTEXT performBlock:^{
      LoadingViewController.progressIndicator.indeterminate = NO;
      LoadingViewController.progressIndicator.maxValue      = netLogsFilesAttrs.count;
    }];
    
    for (NSDictionary *netLogData in netLogsFilesAttrs) {
      NSString   *netLog     = netLogData[FILE_KEY];
      NetLogFile *netLogFile = nil;
      
      currFilePath = [netLogFilesDir stringByAppendingPathComponent:netLog];
      netLogFile   = [NetLogFile netLogFileWithPath:currFilePath inContext:WORK_CONTEXT];
      
      if (netLogFile == nil) {
        NSString *className = NSStringFromClass(NetLogFile.class);
        
        netLogFile = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
        
        netLogFile.commander = commander;
        netLogFile.path      = currFilePath;
      }
      
      progressValue++;
      
      if (netLogFile.complete == NO) {
        NSLog(@"Parsing netLog file: %@", netLog);
        
        if ([netLog isEqualToString:netLogsFilesAttrs.lastObject[FILE_KEY]] == NO && allSystems == nil) {
          allSystems = [[System allSystemsInContext:WORK_CONTEXT] mutableCopy];
          allNames   = [NSMutableArray arrayWithCapacity:allSystems.count];
          allJumps   = [[Jump allJumpsOfCommander:commander] mutableCopy];
          
          for (System *system in allSystems) {
            [allNames addObject:system.name];
          }
        }
        
        netLogFile.complete = YES;
        
        numJumps += [self parseNetLogFile:netLogFile systems:allSystems names:allNames jumps:allJumps lastJump:&lastJump];
        
        numParsed++;
        
        [MAIN_CONTEXT performBlock:^{
          LoadingViewController.progressIndicator.doubleValue = progressValue;
        }];
      }
      
      if ([netLog isEqualToString:netLogsFilesAttrs.lastObject[FILE_KEY]] == YES) {
        NSString *path = netLogFile.path;
        
        netLogFile.complete = NO;
        
        [MAIN_CONTEXT performBlock:^{
          [queue addPath:path];
        }];
      }
    }
    
    if (firstRun) {
      if (numParsed > 1) {
        ti = [NSDate timeIntervalSinceReferenceDate] - ti;
        
        [EventLogger addLog:[NSString stringWithFormat:@"Parsed %@ jumps from %@ netLog files in %.1f seconds", FORMAT(numJumps), FORMAT(numParsed), ti]];
        
        [Answers logCustomEventWithName:@"NETLOG parse" customAttributes:@{@"jumps":@(numJumps),@"files":@(numParsed)}];
      }
    }
  }
  
  [WORK_CONTEXT save];
  
  if (firstRun) {
    firstRun = NO;
  }
}

#pragma mark -
#pragma mark log file scanning

- (NSUInteger)parseCurrNetLogFile {
  NetLogFile *currNetLogFile = [NetLogFile netLogFileWithPath:currFilePath inContext:WORK_CONTEXT];
  Jump       *lastJump       = nil;
  
  return [self parseNetLogFile:currNetLogFile systems:nil names:nil jumps:nil lastJump:&lastJump];
}

- (NSUInteger)parseNetLogFile:(NetLogFile *)netLogFile systems:(NSMutableArray *)allSystems names:(NSMutableArray *)allNames jumps:(NSMutableArray *)allJumps lastJump:(Jump **)lastJump {
  NSAssert([netLogFile.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  
  NSMutableArray *newJumps = [NSMutableArray array];
  
  if (netLogFile != nil) {
    NSFileHandle *currFileHandle = [NSFileHandle fileHandleForReadingAtPath:netLogFile.path];
    
    if (netLogFile.fileOffset == 0) {
      //extract date from file name
      //netLog.160415232458.01.log

      netLogFile.fileDate = [[currFilePath lastPathComponent] substringWithRange:NSMakeRange(7, 12)];
    }
    else {
      [currFileHandle seekToFileOffset:netLogFile.fileOffset];
    }
  
    NSData   *data = [currFileHandle readDataToEndOfFile];
    NSString *text = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    
    if (text.length == 0 && data.length > 0) {
      text = [[NSString alloc] initWithData:data encoding:NSISOLatin1StringEncoding];
      
      if (text.length == 0) {
        text = [[NSString alloc] initWithData:data encoding:NSASCIIStringEncoding];
      }
    }
    
    NSArray *records = [text componentsSeparatedByString:@"{"];
    
    for (NSString *record in records) {
      NSString *entry = [[NSString stringWithFormat:@"{%@", record] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      
      [self parseNetLogRecord:entry inFile:netLogFile systems:allSystems names:allNames jumps:allJumps lastJump:lastJump];
    }
    
    netLogFile.fileOffset = currFileHandle.offsetInFile;

    for (Jump *jump in netLogFile.jumps) {
      if (jump.objectID.isTemporaryID == YES) {
        [newJumps addObject:jump];
      }
    }

    if (newJumps.count > 0) {
      [WORK_CONTEXT save];
      
      if (netLogFile.complete == YES) {
        NSLog(@"Parsed %ld jumps.", (long)newJumps.count);
        
        if ((newJumps.count % 1000) == 0 && newJumps.count != 0) {
          [EventLogger addLog:[NSString stringWithFormat:@"%@ jumps parsed...", FORMAT(newJumps.count)]];
        }
      }
      else {
        NSError *error  = nil;
        BOOL     result = [WORK_CONTEXT obtainPermanentIDsForObjects:newJumps error:&error];
        
        if (error != nil) {
          NSLog(@"ERROR obtaining permanend IDs: %@", error.localizedDescription);
        }
        else if (result == YES) {
          for (Jump *jump in newJumps) {
            NSString *msg = [NSString stringWithFormat:@"Jump to %@ (num visits: %ld)", jump.system.name, (long)jump.system.jumps.count];
            
            [Answers logCustomEventWithName:@"NETLOG parse" customAttributes:@{@"jumps":@1,@"files":@1}];
            
            if (jump.system.hasCoordinates == NO) {
              [jump.system updateFromEDSM:nil];
            }
            
            if (netLogFile.commander.edsmAccount != nil) {
              if (jump.edsm == nil) {
                [netLogFile.commander.edsmAccount sendJumpToEDSM:jump log:YES response:nil];
              }
            }
            
            [EventLogger addLog:msg];
            
            [MAIN_CONTEXT performBlock:^{
              [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:NEW_JUMP_NOTIFICATION object:self];
            }];
          }
        }
      }
    }
  }
  
  return newJumps.count;
}

- (void)parseNetLogRecord:(NSString *)record inFile:(NetLogFile *)netLogFile systems:(NSMutableArray *)allSystems names:(NSMutableArray *)allNames jumps:(NSMutableArray *)allJumps lastJump:(Jump **)lastJump {
  NSAssert(netLogFile != nil, @"netLogFile MUST have a value");
  NSAssert([netLogFile.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  
  BOOL      logRecord   = NO;
  BOOL      parseRecord = NO;
  NSString *systemName  = nil;
  
  //determine whether we are inside a CQC session
  
  if ([record containsString:@"[PG] [Notification] Left a playlist lobby"]) {
    netLogFile.cqc = NO;
    logRecord      = YES;
  }
  
  if ([record containsString:@"[PG] Destroying playlist lobby."]) {
    netLogFile.cqc = NO;
    logRecord      = YES;
  }
  
  if ([record containsString:@"[PG] [Notification] Joined a playlist lobby"]) {
    netLogFile.cqc = YES;
    logRecord      = YES;
  }
  
  if ([record containsString:@"[PG] Created playlist lobby"]) {
    netLogFile.cqc = YES;
    logRecord      = YES;
  }
  
  if ([record containsString:@"[PG] Found matchmaking lobby object"]) {
    netLogFile.cqc = YES;
    logRecord      = YES;
  }

  //make sure record is a jump record, and that we are not inside a CQC session
  
  if ([record containsString:@" System:"]) {
    logRecord      = YES;
    parseRecord    = ((netLogFile.cqc == NO) && ([record containsString:@"ProvingGround"] == NO));
  }
  
  if (logRecord) {
    NSLog(@"%@", record);
  }
  
  //make sure we have a valid system name
  
  if (parseRecord) {
    systemName = [[self parseSystemNameOfRecord:record haveCoords:nil] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
    if (systemName.length == 0) {
      parseRecord = NO;
    }
  }
  
  //make sure we are not visiting training systems
  
  if (parseRecord) {
    if ([systemName isEqualToString:@"Training"]) {
      parseRecord = NO;
    }
    
    if ([systemName isEqualToString:@"Destination"]) {
      parseRecord = NO;
    }
    
    if ([systemName isEqualToString:@"Altiris"]) {
      parseRecord = NO;
    }
  }
  
  if (parseRecord) {
    [self parseNetLogSystemRecord:record inFile:netLogFile systems:allSystems names:allNames jumps:allJumps lastJump:lastJump];
  }
}

- (void)parseNetLogSystemRecord:(NSString *)record inFile:(NetLogFile *)netLogFile systems:(NSMutableArray *)allSystems names:(NSMutableArray *)allNames jumps:(NSMutableArray *)allJumps lastJump:(Jump **)lastJump {
  NSAssert(netLogFile != nil, @"netLogFile MUST have a value");
  NSAssert([netLogFile.managedObjectContext isEqual:WORK_CONTEXT], @"Wrong context!");
  
  BOOL      haveCoords = NO;
  NSDate   *date       = [self parseDateOfRecord:record inFile:netLogFile];
  NSString *name       = [self parseSystemNameOfRecord:record haveCoords:&haveCoords];
  
  if (name != nil && date != nil) {
    //cannot have two subsequent jumps to the same system

    if ((*lastJump) == nil) {
      (*lastJump) = [Jump lastNetlogJumpOfCommander:netLogFile.commander beforeDate:date];
    }

    if ([(*lastJump).system.name isEqualToString:name] == NO) {
      System *system  = nil;
      
      if (allSystems == nil || allNames == nil) {
        system = [System systemWithName:name inContext:WORK_CONTEXT];
      }
      else {
        NSUInteger idx = [allNames indexOfObject:name];
        
        if (idx != NSNotFound) {
          system = allSystems[idx];
        }
      }
    
      if (system == nil) {
        NSString *className = NSStringFromClass(System.class);
        
        system = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
        
        system.name = name;
        
        if (allSystems != nil && allNames != nil) {
          NSUInteger idx = [allNames indexOfObject:name
                                     inSortedRange:(NSRange){0, allNames.count}
                                           options:NSBinarySearchingInsertionIndex
                                   usingComparator:^NSComparisonResult(NSString *str1, NSString *str2) {
                                     return [str1 compare:str2];
                                   }];
          
          [allNames   insertObject:name   atIndex:idx];
          [allSystems insertObject:system atIndex:idx];
        }
      }
      
      Jump *jump = [allJumps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"timestamp == %@", date]].lastObject;
      
      if (jump == nil) {
        NSString *className = NSStringFromClass(Jump.class);
        
        jump = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
      
        jump.system    = system;
        jump.timestamp = [date timeIntervalSinceReferenceDate];
        
        if (haveCoords) {
          [self parseSystemCoordsOfRecord:record intoSystem:system];
        }
      }
      else {
        [allJumps removeObject:jump];
      }
      
      jump.netLogFile = netLogFile;
      
      (*lastJump) = jump;
    }
  }
}

- (NSDate *)parseDateOfRecord:(NSString *)record inFile:(NetLogFile *)netLogFile {
  //netLog records have this format
  //{00:19:00} System:11(Frecku US-U d2-11) Body:1 Pos:(1.67497e+10,-2.85834e+07,1.1919e+09) Supercruise
  //{00:23:21} System:11(Frecku US-U d2-11) Body:17 Pos:(1.96291e+07,-2.16646e+07,5.13991e+07) NormalFlight
  //note that dates will wrap if current netlog file crosses the midnight mark
  
  static NSDateFormatter *dateTimeFormatter = nil;
  static NSDateFormatter *dateFormatter     = nil;
  static NSDate          *gammaLaunchDate   = nil;
  static dispatch_once_t  onceToken;
  
  dispatch_once(&onceToken, ^{
    dateTimeFormatter = [[NSDateFormatter alloc] init];
    dateFormatter     = [[NSDateFormatter alloc] init];
    
    //reference date format
    //160415232458
    dateTimeFormatter.dateFormat = @"yyMMddHHmmss";
    dateFormatter.dateFormat     = @"yyMMdd";
    
    gammaLaunchDate = [dateTimeFormatter dateFromString:GAMMA_LAUNCH_DATE];
  });
  
  //OLD log files do not have seconds in file name... insert them if necessary
  if ([[netLogFile.fileDate substringWithRange:NSMakeRange(10, 1)] isEqualToString:@"."]) {
    netLogFile.fileDate = [[netLogFile.fileDate substringToIndex:10] stringByAppendingString:@"00"];
  }

  //extract date component from netlog file date, time component from netlog record, and combine them together
  
  NSDate   *refDateTime = [dateTimeFormatter dateFromString:netLogFile.fileDate];
  NSString *refStrDate  = [dateFormatter stringFromDate:refDateTime];
  NSString *strTime     = [[record substringWithRange:NSMakeRange(1, 8)] stringByReplacingOccurrencesOfString:@":" withString:@""];
  NSString *strDateTime = [NSString stringWithFormat:@"%@%@", refStrDate, strTime];
  NSDate   *dateTime    = [dateTimeFormatter dateFromString:strDateTime];
  
  //if calculated date-time is earlier than netlog file date-time, it means that in-game time passed the midnight mark
  //and need to add one day to calculated date-time
  
  if (dateTime.timeIntervalSinceReferenceDate < refDateTime.timeIntervalSinceReferenceDate) {
    NSDateComponents *dayComponent = [[NSDateComponents alloc] init];
    NSCalendar       *calendar     = [NSCalendar currentCalendar];
    
    dayComponent.day = 1;
    
    //add 1 day to calculated date-time
    
    dateTime = [calendar dateByAddingComponents:dayComponent toDate:dateTime options:0];
  }
  
  //set netlog file date-time to calculated date-time
  
  netLogFile.fileDate = [dateTimeFormatter stringFromDate:dateTime];

  //make sure jump date is *after* gamma launch date
  
  if (dateTime.timeIntervalSinceReferenceDate < gammaLaunchDate.timeIntervalSinceReferenceDate) {
    dateTime = nil;
  }
  
  return dateTime;
}

- (NSString *)parseSystemNameOfRecord:(NSString *)record haveCoords:(BOOL *)haveCoords {
  NSString *name  = nil;
  NSRange   range = [record rangeOfString:@"System:"];
  
  if (range.location != NSNotFound) {
    record = [record substringFromIndex:range.location + range.length];
  
    if (record.length > 0) {
      if ([[record substringToIndex:1] isEqualToString:@"\""]) {
        
        //engineers (1.6 / 2.1) netlog file format
        
        record = [record substringFromIndex:1];
        
        NSRange range = [record rangeOfString:@"\""];
        
        if (range.location != NSNotFound) {
          name = [record substringToIndex:range.location];
          
          if (haveCoords != nil) {
            *haveCoords = YES;
          }
        }
      }
      else {
        
        //old netlog file format
        
        NSRange range1 = [record rangeOfString:@"("];
        NSRange range2 = [record rangeOfString:@")"];
      
        if (range1.location != NSNotFound && range2.location != NSNotFound && range2.location > (range1.location + 1)) {
          range  = NSMakeRange(range1.location + 1, range2.location - range1.location - 1);
          
          name = [record substringWithRange:range];
        }
      }
    }
  }
  
  return name;
}

- (void)parseSystemCoordsOfRecord:(NSString *)record intoSystem:(System *)system {
  NSRange range = [record rangeOfString:@"StarPos:("];
  
  if (range.location != NSNotFound) {
    record = [record substringFromIndex:(range.location + range.length)];
    range  = [record rangeOfString:@")"];
    
    if (range.location != NSNotFound) {
      record = [record substringToIndex:range.location];
      
      NSArray *comps = [record componentsSeparatedByString:@","];
      
      if (comps.count >= 3) {
        double x = [comps[0] doubleValue];
        double y = [comps[1] doubleValue];
        double z = [comps[2] doubleValue];
        
        if (x != 0 || y != 0 || z != 0 || [system.name compare:@"Sol" options:NSCaseInsensitiveSearch] == NSOrderedSame) {
          if ([system hasCoordinates] == NO) {
            system.x = x;
            system.y = y;
            system.z = z;
          }
        }
      }
    }
  }
}

@end
