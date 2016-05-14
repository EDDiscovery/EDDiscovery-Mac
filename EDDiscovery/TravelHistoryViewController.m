//
//  TravelHistoryViewController.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "TravelHistoryViewController.h"

#import "CoreDataManager.h"
#import "Jump.h"
#import "System.h"
#import "EDSM.h"
#import "NetLogParser.h"
#import "Distance.h"
#import "Commander.h"
#import "LoadingViewController.h"

@interface TravelHistoryViewController() <NSTableViewDataSource, NSTabViewDelegate>
@end

@implementation TravelHistoryViewController {
  IBOutlet NSPopUpButton     *cmdrSelButton;
  IBOutlet NSTextView        *textView;
  IBOutlet NSArrayController *cmdrArrayController;
  IBOutlet NSArrayController *jumpsArrayController;
  IBOutlet NSTableView       *jumpsTableView;
  IBOutlet NSTableView       *distancesTableView;
  IBOutlet NSButton          *deleteCommanderButton;
  IBOutlet NSButton          *setNetlogDirButton;
}

#pragma mark -
#pragma mark UIViewController delegate

- (void)awakeFromNib {
  [super awakeFromNib];
  
  EventLogger.instance.textView = textView;
  
  cmdrArrayController.managedObjectContext = MAIN_CONTEXT;
  jumpsArrayController.managedObjectContext = MAIN_CONTEXT;
  
  cmdrArrayController.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"name"      ascending:YES selector:@selector(caseInsensitiveCompare:)]];
  jumpsTableView.sortDescriptors      = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO  selector:@selector(compare:)]];
  distancesTableView.sortDescriptors  = @[[NSSortDescriptor sortDescriptorWithKey:@"distance"  ascending:YES selector:@selector(compare:)]];
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [cmdrArrayController fetchWithRequest:nil merge:NO error:nil];
  });
}

- (void)viewWillAppear {
  [super viewWillAppear];

  EventLogger.instance.textView = textView;

#warning FIXME: forcing hard-coded window size!
  
  NSRect frame = self.view.window.frame;
  
  frame.size = CGSizeMake(1024, 600);
  
  [self.view.window setFrame: frame display:YES animate:NO];
}

- (void)viewDidAppear {
  [super viewDidAppear];
  
  [Answers logCustomEventWithName:@"Screen view" customAttributes:@{@"screen":NSStringFromClass(self.class)}];
  
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    [self activeCommanderDidChange];
  });
}

#pragma mark -
#pragma mark NSTableView management

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == jumpsTableView) {
    if ([aTableColumn.identifier isEqualToString:@"rowID"]) {
      return @(rowIndex + 1);
    }
  }
  
  return nil;
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(NSTextFieldCell *)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == jumpsTableView) {
    if ([aTableColumn.identifier isEqualToString:@"system"]) {
      Jump   *jump   = jumpsArrayController.arrangedObjects[rowIndex];
      System *system = jump.system;

      if (system.hasCoordinates) {
        aCell.textColor = NSColor.blackColor;
      }
      else {
        if (aTableView.selectedRow == rowIndex) {
          aCell.textColor = NSColor.whiteColor;
        }
        else {
          aCell.textColor = NSColor.blueColor;
        }
      }
    }
  }
  else if (aTableView == distancesTableView) {
    Jump     *jump      = [jumpsArrayController valueForKeyPath:@"selection.self"];
    System   *system    = jump.system;
    NSArray  *distances = system.sortedDistances;
    Distance *distance  = distances[rowIndex];
    
    if (distance.distance.doubleValue == distance.calculatedDistance.doubleValue) {
      aCell.textColor = NSColor.blackColor;
    }
    else if (ABS(distance.distance.doubleValue - distance.calculatedDistance.doubleValue) <= 0.01) {
      aCell.textColor = NSColor.orangeColor;
    }
    else {
      aCell.textColor = NSColor.redColor;
    }
  }
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
  if (aTableView == jumpsTableView) {
    Jump *jump = jumpsArrayController.arrangedObjects[rowIndex];

    jump.system.distanceSortDescriptors = distancesTableView.sortDescriptors;

    [jumpsArrayController setSelectionIndex:rowIndex];
    
    [jump.system updateFromEDSM:^{
      jump.system.distanceSortDescriptors = jump.system.distanceSortDescriptors;
    }];
  }
  
  return YES;
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  if (aTableView == jumpsTableView) {
    jumpsArrayController.sortDescriptors = aTableView.sortDescriptors;
  }
  else if (aTableView == distancesTableView) {
    if (jumpsArrayController.selectionIndex != NSNotFound) {
      Jump   *jump   = jumpsArrayController.arrangedObjects[jumpsArrayController.selectionIndex];
      System *system = jump.system;

      system.distanceSortDescriptors = aTableView.sortDescriptors;
    }
  }
}

#pragma mark -
#pragma mark log file dir selection

- (IBAction)selectLogDirPathButtonTapped:(id)sender {
  NSOpenPanel *openDlg = NSOpenPanel.openPanel;
  NSString    *path    = Commander.activeCommander.netLogFilesDir;
  
  if (path == nil) {
    path = DEFAULT_LOG_DIR_PATH_DIR;
  }

  NSLog(@"%s: %@", __FUNCTION__, path);
  
  openDlg.canChooseFiles = NO;
  openDlg.canChooseDirectories = YES;
  openDlg.allowsMultipleSelection = NO;
  openDlg.directoryURL = [NSURL fileURLWithPath:path];
  
  if ([openDlg runModal] == NSFileHandlingPanelOKButton) {
    NSString *path   = openDlg.URLs.firstObject.path;
    BOOL      exists = NO;
    BOOL      isDir  = NO;
    
    if (path != nil) {
      exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir];
    }
    
    if (exists == YES && isDir == YES) {
      NSArray *commanders = [Commander allCommanders];
      BOOL     goOn       = YES;
      
      for (Commander *commander in commanders) {
        if ([Commander.activeCommander.name isEqualToString:commander.name] == NO) {
          if ([path isEqualToString:commander.netLogFilesDir]) {
            goOn = NO;

            NSAlert *alert = [[NSAlert alloc] init];
            
            alert.messageText = [NSLocalizedString(@"This path is already in use by commander $$", @"") stringByReplacingOccurrencesOfString:@"$$" withString:commander.name];
            alert.informativeText = NSLocalizedString(@"Plase select a different path", @"");
            
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
            
            [alert runModal];
            
            break;
          }
        }
        else if ([path isEqualToString:commander.netLogFilesDir] == NO && commander.netLogFilesDir.length > 0) {
          NSAlert *alert = [[NSAlert alloc] init];
          
          alert.messageText = NSLocalizedString(@"Are you sure you want to change log files directory?", @"");
          alert.informativeText = NSLocalizedString(@"All jumps parsed from current directory will be lost!", @"");
          
          [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
          [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
          
          NSInteger button = [alert runModal];
          
          if (button != NSAlertFirstButtonReturn) {
            goOn = NO;
          }
        }
      }
      
      if (goOn == YES) {
        [LoadingViewController presentLoadingViewControllerInWindow:self.view.window];
        
        [Commander.activeCommander setNetLogFilesDir:path completion:^{
          [LoadingViewController dismiss];
        }];
        
        [Answers logCustomEventWithName:@"NETLOG configure path" customAttributes:@{@"path":path}];
      }
    }
    else {
      NSAlert *alert = [[NSAlert alloc] init];
      
      alert.messageText = NSLocalizedString(@"Invalid path", @"");
      alert.informativeText = NSLocalizedString(@"Plase select a different path", @"");
      
      [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
      
      [alert runModal];
    }
  }
}

#pragma mark -
#pragma mark EDSM account selection

- (IBAction)ESDMAccountChanged:(id)sender {
  NSString *cmdrName = Commander.activeCommander.name;
  NSString *apiKey   = Commander.activeCommander.edsmAccount.apiKey;

  NSLog(@"%s: %@ - %@", __FUNCTION__, cmdrName, apiKey);
  
  [LoadingViewController presentLoadingViewControllerInWindow:self.view.window];
  
  if (cmdrName.length > 0 && apiKey.length > 0) {
    [Commander.activeCommander.edsmAccount syncJumpsWithEDSM:^{
      [LoadingViewController dismiss];
    }];
    
    [Answers logCustomEventWithName:@"EDSM configure account" customAttributes:nil];
  }
  else {
    [LoadingViewController dismiss];
  }
}

#pragma mark -
#pragma mark commander management

- (IBAction)commanderSelected:(id)sender {
  Commander *commander = cmdrArrayController.arrangedObjects[cmdrSelButton.indexOfSelectedItem];
  
  if ([Commander.activeCommander.name isEqualToString:commander.name] == NO) {
    Commander.activeCommander = commander;
    
    [self activeCommanderDidChange];
    
    [Answers logCustomEventWithName:@"CMDR change" customAttributes:nil];
  }
}

- (IBAction)newCommanderButtonTapped:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  
  alert.messageText = NSLocalizedString(@"Please insert new commander name", @"");
  
  [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
  
  NSTextField *input = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 200, 24)];
  
  input.placeholderString = NSLocalizedString(@"Commander name", @"");
  
  [alert setAccessoryView:input];
  
  NSInteger button = [alert runModal];
  
  if (button == NSAlertFirstButtonReturn) {
    [input validateEditing];
    
    Commander *commander = [Commander createCommanderWithName:[input stringValue]];
    
    if (commander != nil) {
      [self activeCommanderDidChange];
      
      [Answers logCustomEventWithName:@"CMDR create" customAttributes:nil];
    }
  }
}

- (IBAction)deleteCommanderButtonTapped:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  
  alert.messageText = [NSLocalizedString(@"Are you sure you want to delete commander $$?", @"") stringByReplacingOccurrencesOfString:@"$$" withString:Commander.activeCommander.name];
  alert.informativeText = NSLocalizedString(@"This operation cannot be undone!", @"");
  
  [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
  
  NSInteger button = [alert runModal];
  
  if (button == NSAlertFirstButtonReturn) {
    [Commander.activeCommander deleteCommander];
    
    [Commander setActiveCommander:nil];
    
    [self activeCommanderDidChange];
    
    [Answers logCustomEventWithName:@"CMDR delete" customAttributes:nil];
  }
}

- (void)activeCommanderDidChange {
  Commander *commander = Commander.activeCommander;
  NSString  *name      = commander.name;
  
  if (name.length == 0) {
    if ([cmdrArrayController.arrangedObjects count] > 0) {
      commander = cmdrArrayController.arrangedObjects[0];
      name      = commander.name;
      
      Commander.activeCommander = commander;
    }
  }
  
  NSLog(@"%s: %@", __FUNCTION__, name);
  
  [EventLogger clearLogs];
  
  if (name.length > 0) {
    [cmdrSelButton selectItemWithTitle:name];
    
    [cmdrArrayController setSelectedObjects:@[commander]];
    
    [jumpsArrayController setFetchPredicate:CMDR_PREDICATE];
    [jumpsArrayController fetchWithRequest:nil merge:NO error:nil];
    
    deleteCommanderButton.enabled = YES;
    setNetlogDirButton.enabled    = YES;
  }
  else {
    deleteCommanderButton.enabled = NO;
    setNetlogDirButton.enabled    = NO;
  }
  
  [LoadingViewController presentLoadingViewControllerInWindow:self.view.window];
  
  [System updateSystemsFromEDSM:^{
    if (name.length == 0) {
      [LoadingViewController dismiss];
    }
    else {
      NetLogParser *netLogParser = [NetLogParser createInstanceForCommander:commander];
      
      if (netLogParser == nil) {
        [self ESDMAccountChanged:nil];
      }
      else {
        [netLogParser startInstance:^{
          [commander.edsmAccount syncJumpsWithEDSM:^{
            [LoadingViewController dismiss];
          }];
        }];
      }
    }
  }];
}

@end
