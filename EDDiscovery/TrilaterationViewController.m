//
//  TrilaterationViewController.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 02/05/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "TrilaterationViewController.h"

#import "System.h"
#import "Distance.h"
#import "Commander.h"
#import "Jump.h"
#import "System.h"
#import "EDSM.h"
#import "CoreDataManager.h"
#import "Commander.h"
#import "Trilateration.h"

#define PASTEBOARD_DATA_TYPE @"NSMutableDictionary"

@interface TrilaterationViewController() <NSTableViewDataSource, NSTabViewDelegate>
@end

@implementation TrilaterationViewController {
  IBOutlet NSTextView          *textView;
  IBOutlet NSTableView         *distancesTableView;
  IBOutlet NSTableView         *suggestedReferencesTableView;
  IBOutlet NSArrayController   *jumpsArrayController;
  IBOutlet NSProgressIndicator *suggestedReferencesProgressIndicator;
  IBOutlet NSTextField         *resultTextField;
  IBOutlet NSButton            *submitButton;
  IBOutlet NSButton            *resetButton;
  
  NSManagedObjectContext *context;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  
  [distancesTableView registerForDraggedTypes:@[PASTEBOARD_DATA_TYPE]];
}

- (void)viewWillAppear {
  [super viewWillAppear];
  
  if (context == nil) {
    context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
    
    context.parentContext = CoreDataManager.instance.mainContext;
    
    [jumpsArrayController setManagedObjectContext:context];
    
    [suggestedReferencesProgressIndicator startAnimation:nil];
  }
  
  Commander *commander = Commander.activeCommander;
  
  [jumpsArrayController setFetchPredicate:CMDR_PREDICATE];
  [jumpsArrayController setSortDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:NO selector:@selector(compare:)]]];;
  [jumpsArrayController fetchWithRequest:nil merge:NO error:nil];

  EventLogger.instance.textView = textView;

  distancesTableView.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"distance" ascending:YES selector:@selector(compare:)]];
  
  Jump   *jump   = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System *system = jump.system;
  
  if (system != nil) {
    [self trilaterate];
  }
}

- (void)viewDidAppear {
  [super viewDidAppear];
  
  [Answers logCustomEventWithName:@"Screen view" customAttributes:@{@"screen":NSStringFromClass(self.class)}];
}

#pragma mark -
#pragma mark row reordering

- (BOOL)tableView:(NSTableView *)aTableView writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard {
  if (aTableView == distancesTableView) {
    NSData *data = [NSKeyedArchiver archivedDataWithRootObject:rowIndexes];
    
    [pboard declareTypes:@[PASTEBOARD_DATA_TYPE] owner:jumpsArrayController];
    [pboard setData:data forType:PASTEBOARD_DATA_TYPE];
    
    return YES;
  }
  
  return NO;
}

- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id<NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation {
  if (aTableView == distancesTableView) {
    return NSDragOperationEvery;
  }
  
  return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id<NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation {
  if (aTableView == distancesTableView) {
    NSPasteboard                *pboard     = [info draggingPasteboard];
    NSData                      *rowData    = [pboard dataForType:PASTEBOARD_DATA_TYPE];
    NSIndexSet                  *rowIndexes = [NSKeyedUnarchiver unarchiveObjectWithData:rowData];
    NSUInteger                   from       = rowIndexes.firstIndex;
    Jump                        *jump       = [jumpsArrayController valueForKeyPath:@"selection.self"];
    System                      *system     = jump.system;
    NSMutableArray <Distance *> *distances  = system.sortedDistances;
    Distance                    *distance   = [distances objectAtIndex:from];

    if (from > row) {
      [distances removeObjectAtIndex:from];
      [distances insertObject:distance atIndex:row];
    }
    else{
      [distances insertObject:distance atIndex:row];
      [distances removeObjectAtIndex:from];
    }
    
    return YES;
  }
  
  return NO;
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
  else if (aTableView == suggestedReferencesTableView) {
    [suggestedReferencesProgressIndicator stopAnimation:nil];
  }
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex {
  if (aTableView == suggestedReferencesTableView) {
    static NSTimeInterval last = 0;
    NSTimeInterval curr = [NSDate timeIntervalSinceReferenceDate];
    
    //FIXME: prevent single clicks from being registered twice. Seems like an SDK bug...
    
    if ((curr - last) > 0.1) {
      Jump                        *jump       = [jumpsArrayController valueForKeyPath:@"selection.self"];
      System                      *system     = jump.system;
      NSMutableArray <Distance *> *distances  = system.sortedDistances;
      NSMutableArray <System   *> *references = system.suggestedReferences;
      System                      *refSystem  = references[rowIndex];
      NSString                    *className  = NSStringFromClass(Distance.class);
      Distance                    *distance   = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:system.managedObjectContext];
      
      distance.system = system;
      distance.name   = refSystem.name;
      
      [system willChangeValueForKey:@"sortedDistances"];
      [distances addObject:distance];
      [system didChangeValueForKey:@"sortedDistances"];
      
      [system willChangeValueForKey:@"suggestedReferences"];
      [references removeObject:refSystem];
      [system didChangeValueForKey:@"suggestedReferences"];
      
      NSInteger col = [distancesTableView columnWithIdentifier:@"system"];
      NSInteger row = [distances indexOfObject:distance];
      
      [distancesTableView editColumn:col row:row withEvent:nil select:YES];
      
      last = curr;
      
      if (references.count < 3) {
        [system addSuggestedReferences];
      }
    }
    
    return NO;
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

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == distancesTableView) {
    if ([aTableColumn.identifier isEqualToString:@"calculatedDistance"]) {
      Jump                        *jump      = [jumpsArrayController valueForKeyPath:@"selection.self"];
      System                      *system    = jump.system;
      NSMutableArray <Distance *> *distances = system.sortedDistances;
      Distance                    *distance  = distances[rowIndex];
      
      if (distance.calculatedDistance == 0) {
        return @(12345);
      }
    }
  }
  
  return nil;
}

- (void)tableView:(NSTableView *)aTableView setObjectValue:(id)anObject forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
  if (aTableView == distancesTableView) {
    if ([aTableColumn.identifier isEqualToString:@"distance"]) {
      [self trilaterate];
    }
  }
}

#pragma mark -
#pragma mark actions

- (void)trilaterate {
  Trilateration            *trilateration = [[Trilateration alloc] init];
  Jump                     *jump          = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System                   *system        = jump.system;
  NSMutableArray <Entry *> *entries       = [NSMutableArray <Entry *> array];

//#warning testing trilateration with a system of known coords!
//  system = [Jump lastXYZJumpOfCommander:Commander.activeCommander].system;
  
  for (Distance *distance in [system.sortedDistances reverseObjectEnumerator]) {
    if (distance.distance != 0) {
      System *system = [System systemWithName:distance.name inContext:distance.managedObjectContext];
      
      if (system.hasCoordinates) {
        Entry *entry = [[Entry alloc] initWithSystem:system distance:distance.distance.doubleValue];
        
        [entries addObject:entry];
        
        if (entries.count == 24) {
          break;
        }
      }
    }
  }
  
  if (entries.count < 3) {
    resultTextField.stringValue     = NSLocalizedString(@"Enter distances", @"");
    resultTextField.backgroundColor = NSColor.cyanColor;
    
    return;
  }
  
  for (Entry *entry in [entries reverseObjectEnumerator]) {
    [trilateration.entries addObject:entry];
  }
  
  NSLog(@"Trilaterating system %@ against %ld distances", system.name, (long)trilateration.entries.count);
  
  Result *result = [trilateration run];
  
  NSString *resultState = @"";
  
  switch (result.state) {
    case Exact:
      resultState = @"Exact";
      resultTextField.stringValue     = NSLocalizedString(@"Success, coordinates found!", @"");
      resultTextField.backgroundColor = NSColor.greenColor;
      break;
    case MultipleSolutions:
      resultState = @"Multiple solutions";
      resultTextField.stringValue     = NSLocalizedString(@"Enter more distances", @"");
      resultTextField.backgroundColor = NSColor.orangeColor;
      break;
    case NeedMoreDistances:
      resultState = @"Need more distances";
      resultTextField.stringValue     = NSLocalizedString(@"Enter more distances", @"");
      resultTextField.backgroundColor = NSColor.orangeColor;
      break;
    case NotExact:
      resultState = @"Not exact";
      resultTextField.stringValue     = NSLocalizedString(@"Enter more distances", @"");
      resultTextField.backgroundColor = NSColor.orangeColor;
      break;
    default:
      NSAssert1(NO, @"unknown result %ld", (long)result.state);
      break;
  }
  
  NSLog(@"%s: result: %@", __FUNCTION__, resultState);
  
  [Answers logCustomEventWithName:@"Trilateration" customAttributes:@{@"result":resultState}];
  
  if (result.coordinate != nil) {
    NSLog(@"Trilaterated coords ==> x:%.5f y:%.5f z:%.5f", result.coordinate.x, result.coordinate.y, result.coordinate.z);
    
    if (result.state == Exact) {
      system.x = result.coordinate.x;
      system.y = result.coordinate.y;
      system.z = result.coordinate.z;
    }
  }
  
  if (result.entries.count > 0) {
    NSLog(@"entries");
    
    for (Distance *distance in system.sortedDistances) {
      distance.calculatedDistance = nil;
    }

    for (Entry *entry in result.entries) {
      double dist = entry.correctedDistance;
      
      NSLog(@"\tentry for %@: %.5f <==> %@", entry.system.name, entry.distance, (dist != 0) ? [NSString stringWithFormat:@"%.5f", dist] : @"NULL");

      for (Distance *distance in system.sortedDistances) {
        if ([distance.name isEqualToString:entry.system.name]) {
          if (dist != 0) {
            distance.calculatedDistance = @(dist);
          }
          
          break;
        }
      }
    }
  }
}

- (IBAction)resetDistances:(id)sender {
  Jump                        *jump       = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System                      *system     = jump.system;
  NSMutableArray <Distance *> *distances  = system.sortedDistances;
  NSMutableArray <System   *> *references = system.suggestedReferences;
  NSMutableArray <Distance *> *restore    = [NSMutableArray array];

  for (Distance *distance in distances) {
    if (distance.objectID.isTemporaryID == YES) {
      [restore addObject:distance];
    }
    else {
      [distance reset];
    }
  }

  [system willChangeValueForKey:@"sortedDistances"];
  [system willChangeValueForKey:@"suggestedReferences"];

  for (Distance *distance in restore) {
    [distance.managedObjectContext deleteObject:distance];

    [distances removeObject:distance];

    [references addObject:[System systemWithName:distance.name inContext:distance.managedObjectContext]];
  }
  
  [system didChangeValueForKey:@"sortedDistances"];
  [system didChangeValueForKey:@"suggestedReferences"];

  if (system != nil) {
    [self trilaterate];
  }
}

- (IBAction)submitDistances:(id)sender {
  Jump   *jump   = [jumpsArrayController valueForKeyPath:@"selection.self"];
  System *system = jump.system;
  
  [EDSM sendDistancesToEDSM:system response:^(BOOL distancesSubmitted, BOOL systemTrilaterated) {
    
    if (distancesSubmitted == YES) {
      NSManagedObjectID      *systemID    = system.objectID;
      NSManagedObjectContext *mainContext = CoreDataManager.instance.mainContext;
      System                 *system      = [mainContext existingObjectWithID:systemID error:nil];
      
      [system updateFromEDSM:^{
        
        [context rollback];
        context = nil;
        
        [self viewWillAppear];
        
      }];
    }
    
  }];
}

@end
