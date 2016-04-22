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

@end
