//
//  TrilaterationViewController.m
//  EDDiscovery
//
//  Created by thorin on 02/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "TrilaterationViewController.h"

#import "EventLogger.h"
#import "System.h"
#import "Distance.h"
#import "Commander.h"
#import "Jump.h"

#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "Commander.h"

@interface TrilaterationViewController() <NSTableViewDataSource, NSTabViewDelegate>
@end

@implementation TrilaterationViewController {
  IBOutlet NSTextView  *textView;
  IBOutlet NSTableView *distancesTableView;
  IBOutlet NSTableView *suggestedReferencesTableView;
  IBOutlet NSArrayController *jumpsArrayController;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  
  jumpsArrayController.managedObjectContext = CoreDataManager.instance.managedObjectContext;
}

- (void)viewWillAppear {
  [super viewWillAppear];
  
  Commander *commander = Commander.activeCommander;
  
  [jumpsArrayController setFetchPredicate:CMDR_PREDICATE];
  [jumpsArrayController setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO selector:@selector(compare:)]]];;
  [jumpsArrayController fetchWithRequest:nil merge:NO error:nil];

  EventLogger.instance.textView = textView;

  distancesTableView.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"distance" ascending:YES selector:@selector(compare:)]];
  
  Jump     *jump      = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System   *system    = jump.system;

  if (system != nil) {
//    [EDSMConnection getDistancesForSystem:self.system.name response:^(NSDictionary *response, NSError *error) {
//      
//    }];
    
    Jump *jump = [Jump lastXYZJumpOfCommander:Commander.activeCommander];
    
    NSLog(@"last jump: %@", jump.system.name);
    
    NSDictionary *dict = @{
                           @"data":@{
                               @"test":@1,
                               @"commander":Commander.activeCommander.name,
                               @"p0":@{
                                   @"name":system.name
                                   }
                               }
                           };
    
    NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
    
    [EDSMConnection submitDistances:data
                           response:^(NSDictionary *response, NSError *error) {
                             
                           }];
  }
}

#pragma mark -
#pragma mark NSTableView management

//- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
//  return nil;
//}

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(NSTextFieldCell *)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == distancesTableView) {
    Jump     *jump      = [jumpsArrayController valueForKeyPath:@"selection.self"];
    System   *system    = jump.system;
    NSArray  *distances = system.sortedDistances;
    Distance *distance  = distances[rowIndex];
    
    if ([aTableColumn.identifier isEqualToString:@"calculatedDistance"] || [aTableColumn.identifier isEqualToString:@"status"]) {
      if (distance.distance == distance.calculatedDistance) {
        aCell.textColor = NSColor.greenColor;
      }
      else {
        aCell.textColor = NSColor.redColor;
      }
    }
  }
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  Jump   *jump   = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System *system = jump.system;

  if (aTableView == distancesTableView) {
    system.distanceSortDescriptors = aTableView.sortDescriptors;
  }
}

@end
