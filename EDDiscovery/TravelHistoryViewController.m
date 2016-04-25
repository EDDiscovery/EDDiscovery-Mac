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

@interface TravelHistoryViewController() <NSTableViewDataSource, NSTabViewDelegate, NSTextFieldDelegate>
@end

@implementation TravelHistoryViewController {
  IBOutlet NSTextView        *textView;
  IBOutlet NSTableView       *tableView;
  IBOutlet NSArrayController *coreDataContent;
}

#pragma mark -
#pragma mark UIViewController delegate

- (void)awakeFromNib {
  [super awakeFromNib];
  
  EventLogger.instance.textView = textView;
  
  coreDataContent.managedObjectContext = CoreDataManager.instance.managedObjectContext;
  
  tableView.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO selector:@selector(compare:)]];
}

#pragma mark -
#pragma mark NSTableView management

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
//  NSLog(@"%s: row %ld, col %@", __FUNCTION__, (long)rowIndex, aTableColumn.identifier);
  
  if ([aTableColumn.identifier isEqualToString:@"rowID"]) {
    return @(rowIndex + 1);
  }
  
  return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  NSLog(@"%s: %@ (row %ld, col %@)", __FUNCTION__, anObject, (long)rowIndex, aTableColumn.identifier);
  
  if ([aTableColumn.identifier isEqualToString:@"note"]) {
    Jump   *jump   = coreDataContent.arrangedObjects[rowIndex];
    System *system = jump.system;
    
    [self systemNoteUpdated:system];
  }
}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(NSTextFieldCell *)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
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

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
  [coreDataContent setSelectionIndex:rowIndex];
  
  return YES;
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  coreDataContent.sortDescriptors = aTableView.sortDescriptors;
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
  NSLog(@"New comment for system %@", system.name);
  
  [EDSM.instance setCommentForSystem:system];
}

@end
