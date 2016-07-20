//
//  ScreenshotCollectionViewItem.m
//  EDDiscovery
//
//  Created by thorin on 15/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "ScreenshotCollectionViewItem.h"
#import "Image.h"
#import "Jump.h"
#import "System.h"
#import "NSImage+Tint.h"

@implementation ScreenshotCollectionViewItem {
  __strong NSImage *img;
}

- (void)setRepresentedObject:(id)representedObject {
  [super setRepresentedObject:representedObject];
  
  if ([representedObject isKindOfClass:Image.class]) {
    Image *image = representedObject;
    
    img = [[NSImage alloc] initWithData:image.thumbnail];
    
    self.imageView.image = img;
    self.textField.stringValue = [[image.path lastPathComponent] stringByDeletingPathExtension];
  }
}

- (void)setSelected:(BOOL)selected {
  [super setSelected:selected];
  
  if (selected) {
    self.view.layer.backgroundColor = NSColor.blueColor.CGColor;
    
    self.imageView.image = [img imageTintedWithColor:NSColor.blueColor];
  }
  else {
    self.view.layer.backgroundColor = NSColor.clearColor.CGColor;
    
    self.imageView.image = img;
  }
}

@end
