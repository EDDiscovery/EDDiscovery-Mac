//
//  NetLogParser.m
//  EDDiscovery
//
//  Created by Michele Noberasco on 18/04/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "ScreenshotMonitor.h"

#import "VDKQueue.h"
#import "EventLogger.h"
#import "CoreDataManager.h"
#import "System.h"
#import "Jump.h"
#import "Commander.h"
#import "Image.h"

#define GAMMA_LAUNCH_DATE @"141122130000"

@interface ScreenshotMonitor () <VDKQueueDelegate>
@end

@implementation ScreenshotMonitor {
  //access from any thread
  NSManagedObjectID *commanderID;
  NSString          *screenshotsDir;
  BOOL               running;
  
  //access from main thread
  VDKQueue          *queue;
}

#pragma mark -
#pragma mark instance management

static ScreenshotMonitor *instance = nil;

+ (nullable ScreenshotMonitor *)instanceOrNil:(Commander * __nonnull)commander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if (instance != nil) {
    if ([instance->commanderID isEqual:commander.objectID]) {
      return instance;
    }
  }
  
  return nil;
}

+ (nullable ScreenshotMonitor *)createInstanceForCommander:(Commander * __nonnull)commander {
  NSAssert (NSThread.isMainThread, @"Must be on main thread");
  
  if ([self instanceOrNil:commander] != nil) {
    return instance;
  }
  else if (instance != nil) {
    [instance stopInstance];
  }
  
  instance = [[ScreenshotMonitor alloc] initInstance:commander];
  
  return instance;
}

- (id)init {
  NSAssert(NO, @"This class should never be instantiated directly!");
  
  return nil;
}

- (ScreenshotMonitor *)initInstance:(Commander *)commander {
  if ([ScreenshotMonitor screenshotsDirIsValid:commander.screenshotsDir]) {
    self = [super init];
  
    if (self) {
      commanderID    = commander.objectID;
      screenshotsDir = [commander.screenshotsDir copy];
      running        = NO;
    }
    
    return self;
  }
  
  return nil;
}

- (void)startInstance:(void(^__nullable)(void))completionBlock {
  if (running == NO) {
    LoadingViewController.textField.stringValue = NSLocalizedString(@"Parsing screenshots dir", @"");
    
    running = YES;
    queue   = [[VDKQueue alloc] init];
    
    [queue setDelegate:self];
    [queue addPath:screenshotsDir];

    [WORK_CONTEXT performBlock:^{
      [self scanScreenshotsDir];
      
      if (completionBlock != nil) {
        [MAIN_CONTEXT performBlock:^{
          completionBlock();
        }];
      }
    }];
  }
  else if (completionBlock != nil) {
    completionBlock();
  }
}

- (void)stopInstance {
  running  = NO;
  instance = nil;
}

- (void)dealloc {
  queue.delegate = nil;
  
  if (screenshotsDir.length > 0) {
    [queue removePath:screenshotsDir];
  }
}

#pragma mark -
#pragma mark consistency checks

+ (BOOL)screenshotsDirIsValid:(NSString *)path {
  BOOL exists = NO;
  BOOL isDir  = NO;

  if (path != nil) {
    exists = [NSFileManager.defaultManager fileExistsAtPath:path isDirectory:&isDir];
  }

  return (exists && isDir);
}

#pragma mark -
#pragma mark VDKQueueDelegate delegate

- (void)VDKQueue:(VDKQueue *)aQueue receivedNotification:(NSString *)nm forPath:(NSString *)path {
  if ([path isEqualToString:screenshotsDir]) {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(startScanScreenshotsDir) object:nil];
    
    [self performSelector:@selector(startScanScreenshotsDir) withObject:nil afterDelay:5.0];
  }
}

#pragma mark -
#pragma mark screenshots directory scanning

- (void)startScanScreenshotsDir {
  [WORK_CONTEXT performBlock:^{
    [self scanScreenshotsDir];
  }];
}

- (void)scanScreenshotsDir {
#define FILE_KEY @"file"
#define ATTR_KEY @"attr"
  
  Commander      *commander            = [WORK_CONTEXT existingObjectWithID:commanderID error:nil];
  NSArray        *screenshotFiles      = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:screenshotsDir error:nil];
  NSMutableArray *screenshotFilesAttrs = [NSMutableArray arrayWithCapacity:screenshotFiles.count];
  
  for (NSString *file in screenshotFiles) {
    NSString     *path  = [screenshotsDir stringByAppendingPathComponent:file];
    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    
    if (attrs != nil) {
      [screenshotFilesAttrs addObject:@{FILE_KEY:file, ATTR_KEY:attrs}];
    }
  }
  
  // sort
  [screenshotFilesAttrs sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:[NSString stringWithFormat:@"%@.%@", ATTR_KEY, NSFileModificationDate] ascending:YES]]];
  
  //parse all screenshot files
  if (screenshotFilesAttrs.count > 0) {
    NSTimeInterval  ti        = [NSDate timeIntervalSinceReferenceDate];
    NSMutableArray *jumps     = [[Jump allJumpsOfCommander:commander] mutableCopy];
    NSUInteger      numParsed = 0;
    
    double progressValue = 0;
    
    [MAIN_CONTEXT performBlock:^{
      LoadingViewController.progressIndicator.indeterminate = NO;
      LoadingViewController.progressIndicator.maxValue      = screenshotFilesAttrs.count;
    }];
    
    for (NSDictionary *screenshotData in screenshotFilesAttrs) {
      NSString *screenshot   = screenshotData[FILE_KEY];
      NSDate   *date         = screenshotData[ATTR_KEY][NSFileModificationDate];
      NSString *currFilePath = [screenshotsDir stringByAppendingPathComponent:screenshot];
      Image    *image        = [Image imageWithPath:currFilePath inContext:WORK_CONTEXT];
      
      if (image == nil) {
        NSString *className = NSStringFromClass(Image.class);
        
        NSLog(@"%@: %@", date, screenshot);
        
        image = [NSEntityDescription insertNewObjectForEntityForName:className inManagedObjectContext:WORK_CONTEXT];
        
        image.path = currFilePath;
        image.jump = [self jumpForDate:date.timeIntervalSinceReferenceDate jumps:jumps];
        
        if (image.jump != nil) {
          NSLog(@"got jump: %@", image.jump.system.name);
          
          [self saveImageAsPNG:image date:date];
        }
        else {
          NSLog(@"no jump");
        }
        
        numParsed++;
      }
      
      progressValue++;
      
      [MAIN_CONTEXT performBlock:^{
        LoadingViewController.progressIndicator.doubleValue = progressValue;
      }];
    }
    
    [EventLogger addLog:[NSString stringWithFormat:@"Parsed %ld screenshots in %.1f seconds", (long)numParsed, ([NSDate timeIntervalSinceReferenceDate] - ti)]];
  }
  
  //purge no-longer existing screenshots
  
  NSArray *screenshots = [Image screenshotsForCommander:commander];
  
  for (Image *screenshot in screenshots) {
    if ([NSFileManager.defaultManager fileExistsAtPath:screenshot.path] == NO) {
      [WORK_CONTEXT deleteObject:screenshot];
    }
  }
  
  [WORK_CONTEXT save];
  
  [MAIN_CONTEXT performBlock:^{
    [NSWorkspace.sharedWorkspace.notificationCenter postNotificationName:SCREENSHOTS_CHANGED_NOTIFICATION object:self];
  }];
}

- (Jump *)jumpForDate:(NSTimeInterval)date jumps:(NSMutableArray <Jump *> *)jumps {
  Jump *jump = nil;
  
  while (jump == nil && jumps.count > 0) {
    if (jumps[0].timestamp <= date) {
      if (jumps.count == 1) {
        jump = jumps[0];
      }
      else if (jumps[1].timestamp > date) {
        jump = jumps[0];
      }
      else {
        [jumps removeObjectAtIndex:0];
      }
    }
    else {
      break;
    }
  }
  
  return jump;
}

- (void)saveImageAsPNG:(Image *)image date:(NSDate *)date {
  static NSDateFormatter *formatter = nil;
  static dispatch_once_t  onceToken;
  
  dispatch_once(&onceToken, ^{
    formatter = [[NSDateFormatter alloc] init];
    
    formatter.dateFormat = @"yyyyMMdd-HHmmss";
  });
  
  NSImage *img = [[NSImage alloc] initWithContentsOfFile:image.path];
  
  if (img != nil) {
    NSString *fileName = [NSString stringWithFormat:@"%@ - %@.png", [formatter stringFromDate:date], image.jump.system.name];
    
    if (![image.path.lastPathComponent isEqualToString:fileName]) {
      CGImageRef        cgRef  = [img CGImageForProposedRect:NULL context:nil hints:nil];
      NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
      
      NSLog(@"renaming %@ to %@", image.path.lastPathComponent, fileName);
      
      newRep.size = img.size;
      
      NSData   *pngData = [newRep representationUsingType:NSPNGFileType properties:@{}];
      NSString *newPath = [[image.path stringByDeletingLastPathComponent] stringByAppendingPathComponent:fileName];
      
      [[NSFileManager defaultManager] createFileAtPath:newPath contents:pngData attributes:@{NSFileModificationDate:date}];
      [[NSFileManager defaultManager] removeItemAtPath:image.path error:nil];
      
      image.path = newPath;
    }

    image.thumbnail = [self thumbnailForImage:img];
  }
}

- (NSData *)thumbnailForImage:(NSImage *)image {
  NSData *thumbnail = nil;
  
  if (image != nil) {
    CGFloat  w     = image.size.width;
    CGFloat  h     = image.size.height;
    CGFloat *major = (w >= h) ? &w : &h;
    CGFloat *minor = (w  < h) ? &w : &h;
    CGFloat  ratio = *major / *minor;
    
    *major = 300.0;
    *minor = *major / ratio;
    
    NSImage          *thumb  = [self imageResize:image newSize:NSMakeSize(w, h)];
    CGImageRef        cgRef  = [thumb CGImageForProposedRect:NULL context:nil hints:nil];
    NSBitmapImageRep *newRep = [[NSBitmapImageRep alloc] initWithCGImage:cgRef];
    
    newRep.size = thumb.size;
    
    thumbnail = [newRep representationUsingType:NSPNGFileType properties:@{}];
  }
  
  return thumbnail;
}

- (NSImage *)imageResize:(NSImage*)anImage newSize:(NSSize)newSize {
  NSImage *sourceImage = anImage;
  NSImage *smallImage  = nil;
  
  if (sourceImage.isValid){
    smallImage = [[NSImage alloc] initWithSize: newSize];
    
    [smallImage lockFocus];
    
    [sourceImage setSize:newSize];
    [[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationHigh];
    [sourceImage drawAtPoint:NSZeroPoint fromRect:CGRectMake(0, 0, newSize.width, newSize.height) operation:NSCompositeCopy fraction:1.0];
    
    [smallImage unlockFocus];
  }
  
  return smallImage;
}

@end
