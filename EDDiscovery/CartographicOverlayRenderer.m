//
//  GroundOverlayRenderer.m
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//

#import "CartographicOverlayRenderer.h"
#import "CartographicOverlay.h"

#define RAD_TO_DEG	57.29577951308232
#define DEG_TO_RAD	.0174532925199432958

@implementation CartographicOverlayRenderer {
  CGImageRef imageRef;
}

#pragma mark -
#pragma mark memory management

- (id)initWithOverlay:(id <MKOverlay>)overlay {
  self = [super initWithOverlay:overlay];
  
  if (self != nil) {
    NSImage    *image  = ((CartographicOverlay *)self.overlay).image;
    CGImageRef  imgRef = [image CGImageForProposedRect:nil context:nil hints:nil];
    
    imageRef = CGImageCreateCopy(imgRef);
  }
  
  return self;
}

- (void)dealloc {
  CGImageRelease(imageRef);
}

#pragma mark -
#pragma mark MKOverlayRenderer methods implementation

- (void)drawMapRect:(MKMapRect)mapRect zoomScale:(MKZoomScale)zoomScale inContext:(CGContextRef)context {
  CartographicOverlay *overlay    = (CartographicOverlay *)self.overlay;
  MKMapRect            theMapRect = [self.overlay boundingMapRect];
  CGRect               theRect    = [self rectForMapRect:theMapRect];
  
  [NSGraphicsContext saveGraphicsState];
  
  CGContextScaleCTM(context, 1.0, -1.0);
  CGContextTranslateCTM(context, 0.0, -theRect.size.height);
  
  // Translate to center of image. This is done to rotate around the center,
  // rather than the edge of the picture
  CGContextTranslateCTM(context, theRect.size.width / 2, theRect.size.height / 2);
  
  // _rotation is the angle from the kml-file, converted to radians.
  CGContextRotateCTM(context, overlay.rotation * DEG_TO_RAD);
  
  // Translate back after the rotation.
  CGContextTranslateCTM(context, -theRect.size.width / 2, -theRect.size.height / 2);
  
  CGContextDrawImage(context, theRect, imageRef);
  
  [NSGraphicsContext restoreGraphicsState];
}

@end
