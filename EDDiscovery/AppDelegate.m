//
//  AppDelegate.m
//  EDDiscovery
//
//  Created by thorin on 15/04/16.
//  Copyright © 2016 Moonrays. All rights reserved.
//

#import "AppDelegate.h"
#import "CoreDataManager.h"
#import "NetLogParser.h"

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
  
  NSLog(@"Welcome to %@ %@", appName, appVersion);
  
  [NetLogParser instance];
}

@end
