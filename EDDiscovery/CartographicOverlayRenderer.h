//
//  GroundOverlayRenderer.h
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//

#import <MapKit/MapKit.h>

@class ZipArchive;

@interface CartographicOverlayRenderer : MKOverlayRenderer

- (id)initWithOverlay:(id <MKOverlay>)overlay;

@end
