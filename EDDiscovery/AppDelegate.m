//
//  AppDelegate.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "AppDelegate.h"
#import "CoreDataManager.h"

@implementation AppDelegate {
  NSWindow *keyWindow;
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
  [[NSUserDefaults standardUserDefaults] registerDefaults:@{ @"NSApplicationCrashOnExceptions": @YES }];
  
  [Fabric with:@[[Crashlytics class]]];

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
  NSStoryboard       *storyboard       = [NSStoryboard storyboardWithName:@"Main" bundle:nil];
  NSWindowController *windowController = [storyboard instantiateControllerWithIdentifier:@"MainWindow"];
  
  keyWindow = windowController.window;
  
  [keyWindow makeKeyAndOrderFront:NSApp];
}

@end
