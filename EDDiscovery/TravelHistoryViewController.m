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

@interface TravelHistoryViewController() <NSTableViewDataSource, NSTabViewDelegate>
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
  coreDataContent.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO selector:@selector(compare:)]];
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
    
    NSLog(@"New comment for system %@", system.name);
    
    [EDSM.instance setCommentForSystem:system];
  }
}

@end
