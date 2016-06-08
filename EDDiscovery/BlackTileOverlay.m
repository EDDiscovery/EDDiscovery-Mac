//
//  BlackTileOverlay.m
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "BlackTileOverlay.h"

@implementation BlackTileOverlay

- (id)init
{
  self = [super initWithURLTemplate:@""];
  
  if (self != nil) {
    self.canReplaceMapContent = YES;
  }
  
  return self;
}

- (void)loadTileAtPath:(MKTileOverlayPath)path result:(void (^)(NSData *tileData, NSError *error))result {
  static NSData *tileData = nil;
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    NSImage          *image = [[NSImage alloc] initWithSize:self.tileSize];
    NSColor          *color = [NSColor blackColor];
    NSBitmapImageRep *rep   = nil;
    
    [image lockFocus];
    
    [color drawSwatchInRect:NSMakeRect(0, 0, image.size.width, image.size.height)];
    
    rep = [[NSBitmapImageRep alloc] initWithFocusedViewRect:NSMakeRect(0.0, 0.0, image.size.width, image.size.height)];
    
    [image unlockFocus];
    
    tileData = [rep representationUsingType:NSPNGFileType properties:@{}];
  });
  
  result(tileData, nil);
}

@end
