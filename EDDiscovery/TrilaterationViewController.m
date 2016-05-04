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
#import "System.h"

#import "EDSMConnection.h"
#import "CoreDataManager.h"
#import "Commander.h"

#import "Trilateration.h"

@interface TrilaterationViewController() <NSTableViewDataSource, NSTabViewDelegate>
@end

@implementation TrilaterationViewController {
  IBOutlet NSTextView        *textView;
  IBOutlet NSTableView       *distancesTableView;
  IBOutlet NSTableView       *suggestedReferencesTableView;
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
    [self trilaterate];
  }
}

- (void)viewWillDisappear {
  [super viewWillDisappear];
  
  Jump                        *jump       = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System                      *system     = jump.system;
  NSMutableArray <Distance *> *distances  = system.sortedDistances;
  NSMutableArray <System   *> *references = system.suggestedReferences;
  NSMutableArray <Distance *> *restore    = [NSMutableArray array];
  
  for (Distance *distance in distances) {
    if (distance.objectID.isTemporaryID == YES) {
      [restore addObject:distance];
    }
  }
  
  for (Distance *distance in restore) {
    [distance.managedObjectContext deleteObject:distance];
    
    [system willChangeValueForKey:@"sortedDistances"];
    [distances removeObject:distance];
    [system didChangeValueForKey:@"sortedDistances"];
    
    [system willChangeValueForKey:@"suggestedReferences"];
    [references addObject:[System systemWithName:distance.name]];
    [system didChangeValueForKey:@"suggestedReferences"];
  }
}

#pragma mark -
#pragma mark NSTableView management

- (IBAction)singleClickEdit:(NSTableView *)aTableView {
  if (aTableView == distancesTableView) {
    NSInteger row = aTableView.clickedRow;
    NSInteger col = aTableView.clickedColumn;
    
    if (row != -1 && col != -1) {
      NSLog(@"%s: row %ld, col %ld", __FUNCTION__, (long)row, (long)col);
      
      NSTableColumn *aTableColumn = aTableView.tableColumns[col];
      
      if (![aTableColumn.identifier isEqualToString:@"system"] && ![aTableColumn.identifier isEqualToString:@"distance"]) {
        col = [aTableView columnWithIdentifier:@"distance"];
      }
      
      aTableColumn = aTableView.tableColumns[col];
      
      [aTableView editColumn:col row:row withEvent:nil select:YES];
    }
  }
}

- (BOOL)control:(NSControl *)control textView:(NSTextView *)aTextView doCommandBySelector:(SEL)commandSelector {
  NSInteger      row          = distancesTableView.editedRow;
  NSInteger      col          = distancesTableView.editedColumn;
  NSTableColumn *aTableColumn = distancesTableView.tableColumns[col];
  BOOL           tabbing      = (commandSelector == @selector(insertTab:) || commandSelector == @selector(insertBacktab:));
  BOOL           backwards    = (commandSelector == @selector(insertBacktab:));
  
  if (tabbing) {
    Jump       *jump   = [jumpsArrayController valueForKeyPath:@"selection.self"];
    System     *system = jump.system;
    NSUInteger  maxRow = system.sortedDistances.count - 1;
    
    if (backwards) {
      if ([aTableColumn.identifier isEqualToString:@"distance"]) {
        col--;
      }
      else if (row == 0) {
        row = maxRow;
        col = 1;
      }
      else {
        row--;
        col = 1;
      }
    }
    else {
      if ([aTableColumn.identifier isEqualToString:@"system"]) {
        col++;
      }
      else if (row < maxRow) {
        row++;
        col = 0;
      }
      else {
        row = 0;
        col = 0;
      }
    }
    
    [distancesTableView editColumn:col row:row withEvent:nil select:YES];
    
    return YES;
  }
  
  return NO;
}

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

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
  if (aTableView == suggestedReferencesTableView) {
    Jump                        *jump       = [jumpsArrayController valueForKeyPath:@"selection.self"];
    System                      *system     = jump.system;
    NSMutableArray <Distance *> *distances  = system.sortedDistances;
    NSMutableArray <System   *> *references = system.suggestedReferences;
    System                      *refSystem  = references[rowIndex];
    
    NSString *className = NSStringFromClass(Distance.class);
    Distance *distance  = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:system.managedObjectContext];
    
    distance.system = system;
    distance.name   = refSystem.name;
    
    [system willChangeValueForKey:@"sortedDistances"];
    [distances addObject:distance];
    [system didChangeValueForKey:@"sortedDistances"];
    
    [system willChangeValueForKey:@"suggestedReferences"];
    [references removeObject:refSystem];
    [system didChangeValueForKey:@"suggestedReferences"];
  }
  
  return YES;
}

- (void)tableView:(NSTableView *)aTableView sortDescriptorsDidChange:(NSArray<NSSortDescriptor *> *)oldDescriptors {
  Jump   *jump   = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System *system = jump.system;

  if (aTableView == distancesTableView) {
    system.distanceSortDescriptors = aTableView.sortDescriptors;
  }
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == distancesTableView) {
    if ([aTableColumn.identifier isEqualToString:@"distance"]) {
      Jump                        *jump      = [jumpsArrayController valueForKeyPath:@"selection.self"];
      System                      *system    = jump.system;
      NSMutableArray <Distance *> *distances = system.sortedDistances;
      Distance                    *distance  = distances[rowIndex];
      
      distance.edited = (distance.distance != 0);
      
      if (distance.edited) {
        [self trilaterate];
      }
    }
  }
}

- (void)submitDistances {
  Jump           *jump   = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System         *system = jump.system;
  NSMutableArray *refs   = [NSMutableArray array];
  
  for (Distance *distance in system.sortedDistances) {
    if (distance.distance != 0 && distance.edited == YES) {
      [refs addObject:@{
                        @"name":distance.name,
                        @"dist":@(distance.distance)
                        }];
    }
  }
  
  NSDictionary *dict = @{
                         @"data":@{
                             @"test":@1,
                             @"commander":Commander.activeCommander.name,
                             @"p0":@{
                                 @"name":system.name
                                 },
                             @"refs":refs
                             }
                         };
  
  NSData *data = [NSJSONSerialization dataWithJSONObject:dict options:0 error:nil];
  
  [EDSMConnection submitDistances:data
                         response:^(NSDictionary *response, NSError *error) {
                           
                         }];
}

- (void)trilaterate {
  Trilateration *trilateration = [[Trilateration alloc] init];
  Jump          *jump          = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System        *system        = jump.system;

  NSLog(@"%s", __FUNCTION__);
  
#warning XXX
  system = [Jump lastXYZJumpOfCommander:Commander.activeCommander].system;
  
  for (Distance *distance in [system.sortedDistances reverseObjectEnumerator]) {
    if (distance.distance != 0) {
      System *system = [System systemWithName:distance.name];
      
      if (system.hasCoordinates) {
        Coordinate *coordinate = [[Coordinate alloc] initWithX:system.x y:system.y z:system.z];
        Entry      *entry      = [[Entry alloc] initWithCoordinate:coordinate distance:distance.distance];
        
        [trilateration.entries addObject:entry];
        
        NSLog(@"\t%@: x:%.2f y:%.2f z:%.2f dist:%.2f", system.name, entry.coordinate.x, entry.coordinate.y, entry.coordinate.z, entry.distance);
        
        if (trilateration.entries.count == 24) {
          break;
        }
      }
    }
  }
  
  NSLog(@"Trilaterating system %@ against %ld distances", system.name, (long)trilateration.entries.count);
  
  Result *result = [trilateration run:RedWizzard_Native];
  
  NSString *resultState = @"";
  
  switch (result.state) {
    case Exact:
      resultState = @"Exact";
      break;
    case MultipleSolutions:
      resultState = @"MultipleSolutions";
      break;
    case NeedMoreDistances:
      resultState = @"NeedMoreDistances";
      break;
    case NotExact:
      resultState = @"NotExact";
      break;
    default:
      NSAssert1(NO, @"unknown result %ld", (long)result.state);
      break;
  }
  
  NSLog(@"%s: result: %@", __FUNCTION__, resultState);
  
  if (result.coordinate != nil) {
    NSLog(@"Trilaterated coords ==> x:%.2f y:%.2f z:%.2f", result.coordinate.x, result.coordinate.y, result.coordinate.z);
  }
  
  if (result.entriesDistances.count > 0) {
    NSLog(@"entries");
    
    NSArray <Entry *> *entries = result.entriesDistances.allKeys;
    
    for (Entry *entry in entries) {
      NSNumber *distance = [result.entriesDistances objectForKey:entry];
      double    dist     = [distance doubleValue];
      
      NSLog(@"\tentry x:%.2f y:%.2f z:%.2f dist:%.2f <==> %.2f", entry.coordinate.x, entry.coordinate.y, entry.coordinate.z, entry.distance, dist);
    }
  }
}

@end
