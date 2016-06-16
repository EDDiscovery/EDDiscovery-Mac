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

@implementation ScreenshotCollectionViewItem

- (void)setRepresentedObject:(id)representedObject {
  [super setRepresentedObject:representedObject];
  
  if ([representedObject isKindOfClass:Image.class]) {
    Image   *image = representedObject;
    NSImage *img   = [[NSImage alloc] initWithData:image.thumbnail];
    
    self.imageView.image = img;
    self.textField.stringValue = [[image.path lastPathComponent] stringByDeletingPathExtension];
  }
}

@end
