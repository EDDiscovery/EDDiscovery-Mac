//
//  ScreenshotsViewController.m
//  EDDiscovery
//
//  Created by thorin on 14/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Quartz/Quartz.h>

#import "ScreenshotsViewController.h"
#import "Commander.h"
#import "ScreenshotMonitor.h"
#import "Image.h"
#import "EventLogger.h"
#import "ScreenshotCollectionViewItem.h"

@interface ScreenshotsViewController () <NSCollectionViewDataSource, NSCollectionViewDelegate, QLPreviewPanelDataSource, QLPreviewPanelDelegate>

@end

@implementation ScreenshotsViewController {
  IBOutlet NSTextField       *screenshotsDirTextField;
  IBOutlet NSArrayController *screenshotsArrayController;
  IBOutlet NSCollectionView  *screenshotsCollectionView;
  IBOutlet NSMenu            *screenshotsCollectionViewMenu;
}

- (void)awakeFromNib {
  [super awakeFromNib];
  
  screenshotsArrayController.managedObjectContext = MAIN_CONTEXT;
  screenshotsArrayController.sortDescriptors      = @[[NSSortDescriptor sortDescriptorWithKey:@"path" ascending:NO]];
}

- (void)viewDidLoad {
  [super viewDidLoad];
  
  [screenshotsCollectionView registerNib:[[NSNib alloc] initWithNibNamed:@"ScreenshotCollectionViewItem" bundle:nil]
                   forItemWithIdentifier:@"ImaceCell"];
  
  [screenshotsCollectionView registerClass:ScreenshotCollectionViewItem.class
                     forItemWithIdentifier:@"ImaceCell"];
}

- (void)viewDidAppear {
  [super viewDidAppear];
  
  [self showScreenshots];
  
  [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(reloadScreenshots) name:SCREENSHOTS_CHANGED_NOTIFICATION object:nil];
  
  [Answers logCustomEventWithName:@"Screen view" customAttributes:@{@"screen":NSStringFromClass(self.class)}];
}

- (void)viewDidDisappear {
  [super viewDidDisappear];
  
  [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self name:SCREENSHOTS_CHANGED_NOTIFICATION object:nil];
}

//workaround for yet another SDK bug, there the menu would not register ' ' as a triggering value 
- (void)insertText:(id)insertString {
  if ([insertString isEqual:@" "]) {
    NSEvent *fakeEvent = [NSEvent keyEventWithType:NSKeyDown
                                          location:[self.view.window mouseLocationOutsideOfEventStream]
                                     modifierFlags:0
                                         timestamp:[[NSProcessInfo processInfo] systemUptime]
                                      windowNumber:self.view.window.windowNumber
                                           context:[NSGraphicsContext currentContext]
                                        characters:@" "
                       charactersIgnoringModifiers:@" "
                                         isARepeat:NO
                                           keyCode:49];
    [screenshotsCollectionViewMenu performKeyEquivalent:fakeEvent];
  } else {
    [super insertText:insertString];
  }
}

#pragma mark -
#pragma mark nscollectionview

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
  return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
  NSArray *items = screenshotsArrayController.arrangedObjects;
  
  NSLog(@"%s: %ld", __FUNCTION__, (long)items.count);
  
  return items.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
  NSCollectionViewItem *item = [collectionView makeItemWithIdentifier:@"ImaceCell" forIndexPath:indexPath];
  
  item.representedObject = screenshotsArrayController.arrangedObjects[indexPath.item];
  
  return item;
}

- (void)collectionView:(NSCollectionView *)collectionView didSelectItemsAtIndexPaths:(nonnull NSSet<NSIndexPath *> *)indexPaths {
  for (NSMenuItem *menuItem in screenshotsCollectionViewMenu.itemArray) {
    menuItem.enabled = YES;
  }
}

- (void)collectionView:(NSCollectionView *)collectionView didDeselectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
  BOOL enabled = (screenshotsCollectionView.selectionIndexes.count > 0);
  
  for (NSMenuItem *menuItem in screenshotsCollectionViewMenu.itemArray) {
    menuItem.enabled = enabled;
  }
}

- (IBAction)deleteMenuItemSelected:(id)sender {
  NSAlert *alert = [[NSAlert alloc] init];
  
  alert.messageText = NSLocalizedString(@"Are you sure you want to delete this screenshot(s)?", @"");
  alert.informativeText = NSLocalizedString(@"This operation cannot be undone!", @"");
  
  [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
  [alert addButtonWithTitle:NSLocalizedString(@"Cancel", @"")];
  
  NSInteger button = [alert runModal];
  
  if (button == NSAlertFirstButtonReturn) {
    NSMutableArray *filePATHs  = [NSMutableArray array];
    NSMutableSet   *indexPaths = [NSMutableSet set];
    
    [screenshotsCollectionView.selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
      Image *image = screenshotsArrayController.arrangedObjects[idx];
      
      [filePATHs addObject:image.path];
      [indexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:0]];
    }];
    
    [screenshotsArrayController removeObjectsAtArrangedObjectIndexes:screenshotsCollectionView.selectionIndexes];
    [screenshotsCollectionView deleteItemsAtIndexPaths:indexPaths];
    
    for (NSString *path in filePATHs) {
      [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    }
  }
}

- (IBAction)revealMenuItemSelected:(id)sender {
  NSMutableArray *fileURLs = [NSMutableArray array];
  
  [screenshotsCollectionView.selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger idx, BOOL * _Nonnull stop) {
    Image *image = screenshotsArrayController.arrangedObjects[idx];
    NSURL *url   = [NSURL fileURLWithPath:image.path];
    
    [fileURLs addObject:url];
  }];
  
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:fileURLs];
}

#pragma mark -
#pragma mark log file dir selection

- (IBAction)selectScreenshotDirPathButtonTapped:(id)sender {
  NSOpenPanel *openDlg = NSOpenPanel.openPanel;
  NSString    *path    = Commander.activeCommander.screenshotsDir;
  
  if (path == nil) {
    path = DEFAULT_SCREENSHOTS_DIR;
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
          if ([path isEqualToString:commander.screenshotsDir]) {
            goOn = NO;
            
            NSAlert *alert = [[NSAlert alloc] init];
            
            alert.messageText = [NSLocalizedString(@"This path is already in use by commander $$", @"") stringByReplacingOccurrencesOfString:@"$$" withString:commander.name];
            alert.informativeText = NSLocalizedString(@"Plase select a different path", @"");
            
            [alert addButtonWithTitle:NSLocalizedString(@"OK", @"")];
            
            [alert runModal];
            
            break;
          }
        }
        else if ([path isEqualToString:commander.screenshotsDir] == NO && commander.screenshotsDir.length > 0) {
          NSAlert *alert = [[NSAlert alloc] init];
          
          alert.messageText = NSLocalizedString(@"Are you sure you want to change screenshots directory?", @"");
          
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
        
        [self hideScreenshots];
        
        screenshotsDirTextField.stringValue = path;
        
        [Commander.activeCommander setScreenshotsDir:path completion:^{
          [LoadingViewController dismiss];
          
          [self showScreenshots];
        }];
        
        [Answers logCustomEventWithName:@"SCREENSHOTS configure path" customAttributes:@{@"path":path}];
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
#pragma mark data management

- (void)showScreenshots {
  Commander *commander = Commander.activeCommander;
  NSString  *name      = commander.name;
  
  if (name.length > 0) {
    NSString *path = commander.screenshotsDir;
    
    if (path.length > 0) {
      screenshotsDirTextField.stringValue = path;
      
      screenshotsArrayController.fetchPredicate = IMG_CMDR_PREDICATE_THUMB;
    
      [screenshotsArrayController fetchWithRequest:nil merge:NO error:nil];
    
      [screenshotsCollectionView reloadData];
    }
  }
}

- (void)hideScreenshots {
  screenshotsArrayController.fetchPredicate = IMG_VOID_PREDICATE;
  
  [screenshotsCollectionView reloadData];
}

- (void)reloadScreenshots {
  Commander *commander = Commander.activeCommander;
  NSString  *name      = commander.name;
  
  if (name.length > 0) {
    [screenshotsArrayController fetchWithRequest:nil merge:NO error:nil];
  
    [screenshotsCollectionView reloadData];
  }
}

#pragma mark -
#pragma mark QuickLook support

- (IBAction)togglePreviewPanel:(id)previewPanel {
  if ([QLPreviewPanel sharedPreviewPanelExists] && [[QLPreviewPanel sharedPreviewPanel] isVisible])
  {
    [[QLPreviewPanel sharedPreviewPanel] orderOut:nil];
  }
  else
  {
    [[QLPreviewPanel sharedPreviewPanel] makeKeyAndOrderFront:nil];
  }
}

- (BOOL)acceptsPreviewPanelControl:(QLPreviewPanel *)panel {
  return YES;
}

- (void)beginPreviewPanelControl:(QLPreviewPanel *)panel {
  panel.delegate = self;
  panel.dataSource = self;
}

- (void)endPreviewPanelControl:(QLPreviewPanel *)panel {
  panel.delegate = nil;
  panel.dataSource = nil;
}

- (NSInteger)numberOfPreviewItemsInPreviewPanel:(QLPreviewPanel *)panel {
  return screenshotsCollectionView.selectionIndexes.count;
}

- (id <QLPreviewItem>)previewPanel:(QLPreviewPanel *)panel previewItemAtIndex:(NSInteger)index {
  __block NSUInteger idx = 0;
  
  [screenshotsCollectionView.selectionIndexes enumerateIndexesUsingBlock:^(NSUInteger currIdx, BOOL * _Nonnull stop) {
    if (idx == index) {
      idx = currIdx;
      
      *stop = YES;
    }
    else {
      idx++;
    }
  }];
  
  Image *image = screenshotsArrayController.arrangedObjects[idx];
  
  return image;
}

- (BOOL)previewPanel:(QLPreviewPanel *)panel handleEvent:(NSEvent *)event {
  // redirect all key down events to the collection view
  if ([event type] == NSKeyDown) {
    [screenshotsCollectionView keyDown:event];
    
    return YES;
  }
  
  return NO;
}

// This delegate method provides the rect on screen from which the panel will zoom.
- (NSRect)previewPanel:(QLPreviewPanel *)panel sourceFrameOnScreenForPreviewItem:(id <QLPreviewItem>)item {
  NSInteger index = [screenshotsArrayController.arrangedObjects indexOfObject:item];
  
  if (index == NSNotFound) {
    return NSZeroRect;
  }
  
  NSRect iconRect = [screenshotsCollectionView frameForItemAtIndex:index];
  
  // check that the icon rect is visible on screen
  NSRect visibleRect = [screenshotsCollectionView visibleRect];
  
  if (!NSIntersectsRect(visibleRect, iconRect)) {
    return NSZeroRect;
  }
  
  // convert icon rect to screen coordinates
  iconRect = [screenshotsCollectionView convertRectToBacking:iconRect];
  NSRect test = [[screenshotsCollectionView window] convertRectToScreen:iconRect];
  iconRect.origin = test.origin;
  
  return iconRect;
}

// this delegate method provides a transition image between the table view and the preview panel
//
- (id)previewPanel:(QLPreviewPanel *)panel transitionImageForPreviewItem:(id <QLPreviewItem>)item contentRect:(NSRect *)contentRect {
  Image *image = (Image *)item;
  
  return [[NSImage alloc] initWithData:image.thumbnail];
}

@end
