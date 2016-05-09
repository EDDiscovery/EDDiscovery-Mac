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

@interface NetLogParser () <VDKQueueDelegate>

@end

@implementation NetLogParser {
  Commander         *commander;
  NSManagedObjectID *commanderID;
  NSString          *netLogFilesDir;
  NetLogFile        *currNetLogFile;
  Jump              *lastJump;
  VDKQueue          *queue;
  BOOL               firstRun;
}

#pragma mark -
#pragma mark instance management

static NetLogParser *instance = nil;

+ (void)instanceWithCommander:(Commander *)commander response:(void(^)(NetLogParser *netLogParser))response {
  if (instance == nil || instance->commander != commander) {
    (void)[[NetLogParser alloc] initInstance:commander response:^(NetLogParser *netLogParser) {
      instance = netLogParser;
      
      response(instance);
    }];
  }
  else {
    response(instance);
  }
}

- (id)init {
  NSAssert(NO, @"This class should never be instantiated directly!");
  
  return nil;
}

- (NetLogParser *)initInstance:(Commander *)aCommander response:(void(^)(NetLogParser *netLogParser))response {
  self = [super init];
  
  if (self) {
    commander      = aCommander;
    commanderID    = aCommander.objectID;
    netLogFilesDir = aCommander.netLogFilesDir;
    
    if ([self netlogDirIsValid]) {
      LoadingViewController.loadingViewController.textField.stringValue = NSLocalizedString(@"Parsing netLog files", @"");
      
      firstRun = YES;
      queue    = [[VDKQueue alloc] init];
      
      [queue setDelegate:self];
      [queue addPath:netLogFilesDir];
      
      [self scanLogFilesDir:^{
        response(self);
      }];
    }
    else {
      self = nil;
      
      response(self);
    }
  }
  
  return nil;
}

- (void)stopInstance {
  instance = nil;
}

- (void)dealloc {
  NSLog(@"%s", __FUNCTION__);
  
  queue.delegate = nil;
  
  if (currNetLogFile.path.length > 0) {
    [queue removePath:currNetLogFile.path];
  }
  
  if (netLogFilesDir.length > 0) {
    [queue removePath:netLogFilesDir];
  }
  
  queue          = nil;
  commander      = nil;
  netLogFilesDir = nil;
}

#pragma mark -
#pragma mark UKKQueue delegate

- (BOOL)netlogDirIsValid {
  NSString  *path  = netLogFilesDir;
  BOOL      exists = NO;
  BOOL      isDir  = NO;

  if (path != nil) {
    exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir];
  }

  return (exists && isDir);
}

#pragma mark -
#pragma mark VDKQueueDelegate delegate

- (void)VDKQueue:(VDKQueue *)queue receivedNotification:(NSString *)nm forPath:(NSString *)path {
  if ([path isEqualToString:netLogFilesDir]) {
    NSLog(@"Log directory contents changed");
    
    [self scanLogFilesDir:nil];
  }
  else {
    [self parseNetLogFile:currNetLogFile systems:nil names:nil jumps:nil];
  }
}

#pragma mark -
#pragma mark log directory scanning

- (void)scanLogFilesDir:(void(^)(void))completionBlock {
#define FILE_KEY @"file"
#define ATTR_KEY @"attr"
  
  if (currNetLogFile != nil) {
    [queue removePath:currNetLogFile.path];
  }
  
  NSArray *files = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:netLogFilesDir error:nil];
  
  if (firstRun) {
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    
    numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;
    
    [EventLogger addLog:[NSString stringWithFormat:@"Have %@ files in log directory", [numberFormatter stringFromNumber:@(files.count)]]];
  }
  
  NSMutableArray *netLogFiles = [NSMutableArray array];
  
  for (NSString *file in files) {
    if ([file rangeOfString:@"netLog."].location == 0) {
      [netLogFiles addObject:file];
    }
  }
  
  if (firstRun) {
    NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
    
    numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
    numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;
    
    [EventLogger addLog:[NSString stringWithFormat:@"Have %@ netLog files in log directory", [numberFormatter stringFromNumber:@(netLogFiles.count)]]];
  }
  
  NSMutableArray *netLogs = [NSMutableArray arrayWithCapacity:netLogFiles.count];
  
  for (NSString *file in netLogFiles) {
    NSString     *path  = [netLogFilesDir stringByAppendingPathComponent:file];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    
    if (attrs != nil) {
      [netLogs addObject:@{FILE_KEY:file, ATTR_KEY:attrs}];
    }
  }
  
  // sort
  [netLogs sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:[NSString stringWithFormat:@"%@.%@", ATTR_KEY, NSFileModificationDate] ascending:YES]]];
  
  [CoreDataManager.instance.bgContext performBlock:^{
    Commander *myCommander = [CoreDataManager.instance.bgContext existingObjectWithID:commanderID error:nil];
    
    //parse all netlog files
    if (netLogs.count > 0) {
      NSMutableArray *systems   = nil;
      NSMutableArray *names     = nil;
      NSMutableArray *jumps     = nil;
      NSTimeInterval  ti        = [NSDate timeIntervalSinceReferenceDate];
      NSUInteger      numParsed = 0;
      NSUInteger      numJumps  = 0;
      
      NSProgressIndicator *progress      = LoadingViewController.loadingViewController.progressIndicator;
      double               progressValue = 0;
      
      [CoreDataManager.instance.mainContext performBlockAndWait:^{
        progress.indeterminate = NO;
        progress.maxValue      = netLogs.count;
      }];
      
      for (NSDictionary *netLogData in netLogs) {
        NSString   *netLog     = netLogData[FILE_KEY];
        NSString   *path       = [netLogFilesDir stringByAppendingPathComponent:netLog];
        NetLogFile *netLogFile = [NetLogFile netLogFileWithPath:path inContext:CoreDataManager.instance.bgContext];
        
        if (netLogFile == nil) {
          NSString *className = NSStringFromClass(NetLogFile.class);
          
          netLogFile = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:CoreDataManager.instance.bgContext];
          
          netLogFile.commander = myCommander;
          netLogFile.path      = path;
        }
        
        progressValue++;
        
        if (netLogFile.complete == NO) {
          NSLog(@"Parsing netLog file: %@", netLog);
          
          if ([netLog isEqualToString:netLogs.lastObject[FILE_KEY]] == NO && systems == nil) {
            systems = [[System allSystemsInContext:CoreDataManager.instance.bgContext] mutableCopy];
            names   = [NSMutableArray arrayWithCapacity:systems.count];
            jumps   = [[Jump allJumpsOfCommander:myCommander] mutableCopy];
            
            for (System *aSystem in systems) {
              [names addObject:aSystem.name];
            }
          }
          
          netLogFile.complete = YES;
          
          numJumps += [self parseNetLogFile:netLogFile systems:systems names:names jumps:jumps];
          
          numParsed++;
          
          [CoreDataManager.instance.mainContext performBlockAndWait:^{
            progress.doubleValue = progressValue;
          }];
        }
        
        if ([netLog isEqualToString:netLogs.lastObject[FILE_KEY]] == YES) {
          netLogFile.complete = NO;
          
          currNetLogFile = netLogFile;
          
          [queue addPath:currNetLogFile.path];
        }
      }
      
      if (firstRun) {
        if (numParsed > 1) {
          ti = [NSDate timeIntervalSinceReferenceDate] - ti;
          
          NSNumberFormatter* numberFormatter = [[NSNumberFormatter alloc] init];
          
          numberFormatter.formatterBehavior = NSNumberFormatterBehavior10_4;
          numberFormatter.numberStyle       = NSNumberFormatterDecimalStyle;
          
          [EventLogger addLog:[NSString stringWithFormat:@"Parsed %@ jumps from %@ netLog files in %.1f seconds", [numberFormatter stringFromNumber:@(numJumps)], [numberFormatter stringFromNumber:@(numParsed)], ti]];
          
          [Answers logCustomEventWithName:@"NETLOG parse" customAttributes:@{@"jumps":@(numJumps),@"files":@(numParsed)}];
        }
      }
    }
    
    NSError *error = nil;

    [CoreDataManager.instance.bgContext save:&error];
    
    if (error != nil) {
      NSLog(@"ERROR saving context: %@", error);
      
      exit(-1);
    }
    
    [CoreDataManager.instance.mainContext performBlockAndWait:^{
      NSError *error = nil;
      
      [CoreDataManager.instance.mainContext save:&error];
      
      if (error != nil) {
        NSLog(@"ERROR saving context: %@", error);
        
        exit(-1);
      }
    }];
    
    if (firstRun && myCommander.edsmAccount != nil) {
      [myCommander.edsmAccount syncJumpsWithEDSM:^{
        if (completionBlock != nil) {
          [CoreDataManager.instance.mainContext performBlock:^{
            completionBlock();
          }];
        }
      }];
    }
    else if (completionBlock != nil) {
      [CoreDataManager.instance.mainContext performBlock:^{
        completionBlock();
      }];
    }
    
    if (firstRun) {
      firstRun = NO;
    }
  }];
}

#pragma mark -
#pragma mark log file scanning

- (NSUInteger)parseNetLogFile:(NetLogFile *)netLogFile systems:(NSMutableArray *)systems names:(NSMutableArray *)names jumps:(NSMutableArray *)jumps {
  static NSString     *currPath   = nil;
  static NSFileHandle *fileHandle = nil;
  static NSString     *fileDate   = nil;
  
  NSUInteger           count      = 0;
  
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
    
    NSData   *data    = [fileHandle readDataToEndOfFile];
    NSString *text    = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSArray  *records = [text componentsSeparatedByString:@"{"];
    
    for (NSString *record in records) {
      NSString *entry = [[NSString stringWithFormat:@"{%@", record] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
      
      [self parseNetLogRecord:entry inFile:netLogFile referenceDate:fileDate systems:systems names:names jumps:jumps];
    }
    
    netLogFile.fileOffset = fileHandle.offsetInFile;

    for (Jump *jump in netLogFile.jumps) {
      if (jump.objectID.isTemporaryID == YES) {
        count++;
        
        if (netLogFile.complete == NO) {
          NSString *msg = [NSString stringWithFormat:@"Jump to %@ (num visits: %ld)", jump.system.name, (long)jump.system.jumps.count];
          
          [Answers logCustomEventWithName:@"NETLOG parse" customAttributes:@{@"jumps":@1,@"files":@1}];
          
          if (jump.system.hasCoordinates == NO) {
            [jump.system updateFromEDSM:nil];
          }

          if (commander.edsmAccount != nil) {
            [commander.edsmAccount sendJumpToEDSM:jump];
          }
          
          [EventLogger addLog:msg];
        }
      }
    }

    if (count > 0 /*&& firstRun == NO*/) {
      NSError *error = nil;
      
      [netLogFile.managedObjectContext save:&error];
      
      if (error != nil) {
        NSLog(@"ERROR saving context: %@", error);
        
        exit(-1);
      }
      
      [netLogFile.managedObjectContext.parentContext performBlockAndWait:^{
        NSError *error = nil;
        
        [netLogFile.managedObjectContext.parentContext save:&error];
        
        if (error != nil) {
          NSLog(@"ERROR saving context: %@", error);
          
          exit(-1);
        }
      }];
      
      if (netLogFile.complete == YES && count > 0) {
        NSLog(@"Parsed %ld jumps.", (long)count);
      }
    }
  }
  
  return count;
}

- (void)parseNetLogRecord:(NSString *)record inFile:(NetLogFile *)netLogFile referenceDate:(NSString *)referenceDateTime systems:(NSMutableArray *)systems names:(NSMutableArray *)names jumps:(NSMutableArray *)jumps {
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
    systemName = [[self parseSystemNameOfRecord:record] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    
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
  
  //cannot have two subsequent jumps to the same system
  
  if (parseRecord) {
    if (lastJump == nil) {
      lastJump = [Jump lastJumpOfCommander:commander];
    }
    
    if ([lastJump.system.name isEqualToString:systemName] == YES) {
      parseRecord = NO;
    }
  }
  
  if (parseRecord) {
    [self parseNetLogSystemRecord:record inFile:netLogFile referenceDate:referenceDateTime systems:systems names:names jumps:jumps];
  }
}

- (void)parseNetLogSystemRecord:(NSString *)record inFile:(NetLogFile *)netLogFile referenceDate:(NSString *)referenceDateTime systems:(NSMutableArray *)systems names:(NSMutableArray *)names jumps:(NSMutableArray *)jumps {
  NSDate   *date = [self parseDateOfRecord:record referenceDateTime:referenceDateTime];
  NSString *name = [self parseSystemNameOfRecord:record];
  
  if (name != nil && date != nil) {
    NSManagedObjectContext *context  = netLogFile.managedObjectContext;
    System                 *system   = nil;
    
    if (systems == nil || names == nil) {
      system = [System systemWithName:name inContext:context];
    }
    else {
      NSUInteger idx = [names indexOfObject:name];
      
      if (idx != NSNotFound) {
        system = systems[idx];
      }
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
    
    Jump *jump = [jumps filteredArrayUsingPredicate:[NSPredicate predicateWithFormat:@"timestamp == %@", date]].lastObject;
    
    if (jump == nil) {
      NSString *className = NSStringFromClass(Jump.class);
      
      jump = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:context];
    
      jump.system    = system;
      jump.timestamp = [date timeIntervalSinceReferenceDate];
    }
    else {
      [jumps removeObject:jump];
    }
    
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
  static NSDate          *gammaLaunchDate   = nil;
  static dispatch_once_t  onceToken;
  
  dispatch_once(&onceToken, ^{
    NSString *gammaLaunch = @"141122130000";
    
    dateTimeFormatter = [[NSDateFormatter alloc] init];
    dateFormatter     = [[NSDateFormatter alloc] init];
    
    //reference date format
    //160415232458
    dateTimeFormatter.dateFormat = @"yyMMddHHmmss";
    dateFormatter.dateFormat     = @"yyMMdd";
    
    gammaLaunchDate = [dateTimeFormatter dateFromString:gammaLaunch];
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
  
  //make sure jump date is *after* gamma launch date
  
  if ([gammaLaunchDate earlierDate:dateTime] == dateTime) {
    dateTime = nil;
  }
  
  return dateTime;
}

- (NSString *)parseSystemNameOfRecord:(NSString *)record {
  NSString *name  = nil;
  NSRange   range = [record rangeOfString:@"System:"];
  
  if (range.location != NSNotFound) {
    record = [record substringFromIndex:range.location + range.length];
  
    NSRange range1 = [record rangeOfString:@"("];
    NSRange range2 = [record rangeOfString:@")"];
  
    if (range1.location != NSNotFound && range2.location != NSNotFound && range2.location > (range1.location + 1)) {
      range  = NSMakeRange(range1.location + 1, range2.location - range1.location - 1);
      
      name = [record substringWithRange:range];
    }
  }
  
  return name;
}

@end
