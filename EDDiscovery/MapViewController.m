//
//  MapViewController.m
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <MapKit/MapKit.h>

#import "MapViewController.h"
#import "Jump.h"
#import "Commander.h"
#import "System.h"
#import "CartographicOverlayRenderer.h"
#import "CartographicOverlay.h"
#import "MapAnnotation.h"
#import "BlackTileOverlay.h"

@implementation MapViewController {
  IBOutlet MKMapView *mapView;
}

- (void)viewDidAppear {
  [super viewDidAppear];
  
  NSLog(@"%s", __FUNCTION__);
  
  [self loadMap];
}

- (void)viewDidDisappear {
  [super viewDidDisappear];
  
  [mapView removeAnnotations:mapView.annotations];
  [mapView removeOverlays:mapView.overlays];
}

- (void)loadMap {
  //determine boundaries of map view, in map view coordinate format
  
  CGRect frame = mapView.frame;
  
  frame = CGRectMake(frame.origin.x + 10, frame.origin.y + 10, frame.size.width - 20, frame.size.height - 20);
  
  if (frame.size.width > frame.size.height) {
    CGFloat h = frame.size.height;
    CGFloat w = h;
    CGFloat y = frame.origin.y;
    CGFloat x = (frame.size.width - w) / 2.0;
    
    frame = CGRectMake(x, y, w, h);
  }
  else if (frame.size.width < frame.size.height) {
    CGFloat w = frame.size.width;
    CGFloat h = w;
    CGFloat x = frame.origin.x;
    CGFloat y = (frame.size.height - h) / 2.0;
    
    frame = CGRectMake(x, y, w, h);
  }
  
  CLLocationCoordinate2D minC = [mapView convertPoint:CGPointMake(frame.origin.x, frame.origin.y) toCoordinateFromView:nil];
  CLLocationCoordinate2D maxC = [mapView convertPoint:CGPointMake(frame.origin.x+frame.size.width, frame.origin.y+frame.size.height) toCoordinateFromView:nil];
  MKMapPoint minP = MKMapPointForCoordinate(minC);
  MKMapPoint maxP = MKMapPointForCoordinate(maxC);
  
  
  //determine boundaries of galaxy, in ED coordinate format
  
  double minX = -45000;
  double maxX =  45000;
  double minY = -20000;
  double maxY =  70000;

  
  //add base layer (black) overlay, so that we do not display Apple Maps as background ;-)
  
  BlackTileOverlay *tileOverlay = [[BlackTileOverlay alloc] init];
  
  [mapView addOverlay:tileOverlay];

  
  //add background galaxy image overlay
  
  CartographicOverlay *overlay = [[CartographicOverlay alloc] init];
  double x = minP.x + ((45000 - minX) / (maxX - minX)) * (maxP.x - minP.x);
  double y = minP.y + ((70000 - minY) / (maxY - minY)) * (maxP.y - minP.y);
  MKMapPoint ne = MKMapPointMake(x, y);
  x = minP.x + ((-45000 - minX) / (maxX - minX)) * (maxP.x - minP.x);
  y = minP.y + ((-20000 - minY) / (maxY - minY)) * (maxP.y - minP.y);
  MKMapPoint sw = MKMapPointMake(x, y);
  
  overlay.image = [NSImage imageNamed:@"Galaxy_L_Grid.jpg"];
  overlay.ne    = MKCoordinateForMapPoint(ne);
  overlay.sw    = MKCoordinateForMapPoint(sw);
  
  [mapView addOverlay:overlay];
  
  
  //add polyline with CMDR jumps
  
  NSArray       *jumps  = [Jump allJumpsOfCommander:Commander.activeCommander];
  NSMutableData *points = [NSMutableData data];
  MKMapPoint     point;
  
  for (Jump *jump in jumps) {
    if (jump.system.hasCoordinates) {
      x = minP.x + ((jump.system.x - minX) / (maxX - minX)) * (maxP.x - minP.x);
      y = minP.y + ((jump.system.z - minY) / (maxY - minY)) * (maxP.y - minP.y);
      
      point = MKMapPointMake(x, y);
    
      [points appendBytes:&point length:sizeof(MKMapPoint)];
      
      //if system has a note, add an annotation for it
      
      if (jump.system.note.length > 0) {
        MapAnnotation *annotation = [[MapAnnotation alloc] initWithCoordinate:MKCoordinateForMapPoint(point)
                                                                        title:jump.system.note];
        
        [mapView addAnnotation:annotation];
      }
    }
  }
  
  MKPolyline *polyline = [MKPolyline polylineWithPoints:(MKMapPoint *)points.bytes count:(points.length / sizeof(MKMapPoint))];
  
  [mapView addOverlay:polyline];
  
  
  // zoom and center map to match selected background image
  
  MKMapRect          mapRect = overlay.boundingMapRect;
  MKCoordinateRegion region  = MKCoordinateRegionForMapRect(mapRect);
  
  [mapView setRegion:region animated:YES];
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
  if ([annotation isKindOfClass:[MapAnnotation class]]) {
    MKPinAnnotationView *res = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:nil];
    
    res.pinColor                  = MKPinAnnotationColorRed;
    res.animatesDrop              = NO;
    res.rightCalloutAccessoryView = nil;
    res.leftCalloutAccessoryView  = nil;

    res.enabled        = YES;
    res.canShowCallout = YES;

    return res;
  }
  
  return nil;
}

-(MKOverlayRenderer *)mapView:(MKMapView*)mapView rendererForOverlay:(id<MKOverlay>)overlay {
  MKOverlayRenderer *renderer = nil;
  
  if ([overlay isKindOfClass:[MKTileOverlay class]]) {
    renderer = [[MKTileOverlayRenderer alloc] initWithOverlay:overlay];
  }
  else if ([overlay isKindOfClass:[MKPolyline class]]) {
    renderer = [[MKPolylineRenderer alloc] initWithPolyline:overlay];
    
    ((MKPolylineRenderer *)renderer).strokeColor = [NSColor blueColor];
    ((MKPolylineRenderer *)renderer).lineWidth   = 2;
    ((MKPolylineRenderer *)renderer).lineJoin    = kCGLineJoinRound;
  }
  else if ([overlay isKindOfClass:[CartographicOverlay class]]) {
    renderer = [[CartographicOverlayRenderer alloc] initWithOverlay:overlay];
  }

  return renderer;
}

@end
