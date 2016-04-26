//
//  AppDelegate.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "AppDelegate.h"
#import "CoreDataManager.h"
#import "NetLogParser.h"
#import "EventLogger.h"
#import "System.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [self initializeApplication];
}

#pragma mark -
#pragma mark application initialization

- (void)initializeApplication {
  BOOL needDataMigration = [[CoreDataManager instance] needDataMigration];
  
  if (needDataMigration == YES) {
    NSLog(@"Need migration from old CORE DATA!");
    
    [self performDataMigration];
  }
  else {
    [CoreDataManager.instance initializeDatabaseContents];
    
    [self finishInitialization];
  }
}

- (void)performDataMigration {
  @autoreleasepool {
    NSLog(@"%s", __FUNCTION__);
    
    [CoreDataManager.instance initializeDatabaseContents];
    
    [self finishInitialization];
  }
}

- (void)finishInitialization {
  NSString *appName    = [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
  NSString *appVersion = [NSString stringWithFormat:
                          @"%@ (build %@)",
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                          [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString*)kCFBundleVersionKey]];
  
  [EventLogger addLog:[NSString stringWithFormat:@"Welcome to %@ %@", appName, appVersion]];
  
  [System updateSystemsFromEDSM:^{
    NSString *path   = [NSUserDefaults.standardUserDefaults objectForKey:LOG_DIR_PATH_SETING_KEY];
    BOOL      exists = NO;
    BOOL      isDir  = NO;

    if (path != nil) {
      exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir];
    }
    
    if (exists == YES && isDir == YES) {
      [NetLogParser instanceWithPath:path];
    }
  }];
}

@end
