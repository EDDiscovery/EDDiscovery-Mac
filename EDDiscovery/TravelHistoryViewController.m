//
//  TravelHistoryViewController.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 15/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "TravelHistoryViewController.h"

#import "EventLogger.h"
#import "CoreDataManager.h"
#import "Jump.h"
#import "System.h"
#import "EDSM.h"
#import "AppDelegate.h"
#import "NetLogParser.h"


@interface TravelHistoryViewController() <NSTableViewDataSource, NSTabViewDelegate, NSTextFieldDelegate>
@end

@implementation TravelHistoryViewController {
  IBOutlet NSTextView        *textView;
  IBOutlet NSTableView       *tableView;
  IBOutlet NSArrayController *coreDataContent;
  IBOutlet NSTableView       *distancesTableView;
}

#pragma mark -
#pragma mark UIViewController delegate

- (void)awakeFromNib {
  [super awakeFromNib];
  
  EventLogger.instance.textView = textView;
  
  coreDataContent.managedObjectContext = CoreDataManager.instance.managedObjectContext;
  
  tableView.sortDescriptors          = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO  selector:@selector(compare:)]];
  distancesTableView.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"distance"  ascending:YES selector:@selector(compare:)]];
}

#pragma mark -
#pragma mark NSTableView management

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
//  NSLog(@"%s: row %ld, col %@", __FUNCTION__, (long)rowIndex, aTableColumn.identifier);
  
  if (aTableView == tableView) {
    if ([aTableColumn.identifier isEqualToString:@"rowID"]) {
      return @(rowIndex + 1);
    }
  }
  
  return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == tableView) {
    NSLog(@"%s: %@ (row %ld, col %@)", __FUNCTION__, anObject, (long)rowIndex, aTableColumn.identifier);
    
    if ([aTableColumn.identifier isEqualToString:@"note"]) {
      Jump   *jump   = coreDataContent.arrangedObjects[rowIndex];
      System *system = jump.system;
      
      [self systemNoteUpdated:system];
    }
  }
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(NSTextFieldCell *)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == tableView) {
    if ([aTableColumn.identifier isEqualToString:@"system"]) {
      Jump   *jump   = coreDataContent.arrangedObjects[rowIndex];
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
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
  if (aTableView == tableView) {
    Jump        *jump     = coreDataContent.arrangedObjects[rowIndex];
    AppDelegate *delegate = NSApplication.sharedApplication.delegate;

    jump.system.distanceSortDescriptors = distancesTableView.sortDescriptors;

    delegate.selectedJump = jump;
    
    [coreDataContent setSelectionIndex:rowIndex];
    
    [jump.system updateFromEDSM:^{
      jump.system.distanceSortDescriptors = jump.system.distanceSortDescriptors;
    }];
  }
  
  return YES;
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  if (aTableView == tableView) {
    coreDataContent.sortDescriptors = aTableView.sortDescriptors;
  }
  else if (aTableView == distancesTableView) {
    if (coreDataContent.selectionIndex != NSNotFound) {
      Jump   *jump   = coreDataContent.arrangedObjects[coreDataContent.selectionIndex];
      System *system = jump.system;

      system.distanceSortDescriptors = aTableView.sortDescriptors;
    }
  }
}

#pragma mark -
#pragma mark text field delegate

- (void)controlTextDidEndEditing:(NSNotification *)aNotification {
  Jump   *jump   = coreDataContent.arrangedObjects[coreDataContent.selectionIndex];
  System *system = jump.system;
  
  [self systemNoteUpdated:system];
}

#pragma mark -
#pragma mark update notes

- (void)systemNoteUpdated:(System *)system {
  static NSString *prevSystem = nil;
  static NSString *prevNote   = nil;

  if (prevSystem != nil && prevNote != nil && [prevSystem isEqualToString:system.name] && [prevNote isEqualToString:system.comment]) {
    return;
  }
  
  NSLog(@"New comment for system %@", system.name);
  
  [EDSM.instance setCommentForSystem:system];
  
  prevSystem = system.name;
  prevNote   = system.comment;
}

#pragma mark -
#pragma mark log file dir selection

- (IBAction)selectLogDirPathButtonTapped:(id)sender {
  NSOpenPanel *openDlg = NSOpenPanel.openPanel;
  NSString    *path    = [NSUserDefaults.standardUserDefaults objectForKey:LOG_DIR_PATH_SETING_KEY];
  
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
      [NSUserDefaults.standardUserDefaults setObject:path forKey:LOG_DIR_PATH_SETING_KEY];
      
      [NetLogParser instanceWithPath:path];
    }

  }
}

@end
