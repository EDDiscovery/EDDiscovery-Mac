//
//  AppDelegate.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "AppDelegate.h"
#import "CoreDataManager.h"

@implementation AppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
  
  [Fabric with:@[[Crashlytics class]]];

  [self initializeApplication];
  
  NSLog(@"SUFeedURL: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUFeedURL"]);
  NSLog(@"SUEnableAutomaticChecks: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUEnableAutomaticChecks"]);
  NSLog(@"SUEnableSystemProfiling: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUEnableSystemProfiling"]);
  NSLog(@"SUShowReleaseNotes: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUShowReleaseNotes"]);
  NSLog(@"SUPublicDSAKeyFile: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUPublicDSAKeyFile"]);
  NSLog(@"SUScheduledCheckInterval: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUScheduledCheckInterval"]);
  NSLog(@"SUAllowsAutomaticUpdates: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUAllowsAutomaticUpdates"]);
  NSLog(@"SUBundleName: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"SUBundleName"]);
  
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
  //nothing to do
}

@end
