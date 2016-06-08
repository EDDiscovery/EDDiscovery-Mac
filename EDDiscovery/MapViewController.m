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

- (void)viewWillAppear {
  [super viewWillAppear];
  
  NSLog(@"%s", __FUNCTION__);
  
  [self loadMap];
}

- (void)viewDidDisappear {
  [super viewDidDisappear];
  
  [mapView removeAnnotations:mapView.annotations];
  [mapView removeOverlays:mapView.overlays];
}

- (void)loadMap {
  BlackTileOverlay *tileOverlay = [[BlackTileOverlay alloc] init];
  
  [mapView addOverlay:tileOverlay];
  
  NSArray       *jumps  = [Jump allJumpsOfCommander:Commander.activeCommander];
  NSMutableData *points = [NSMutableData data];
  MKMapPoint     point;
  
  
  double minLat = - 90;
  double maxLat =   90;
  double minLon = -180;
  double maxLon =  180;

  CLLocationCoordinate2D minC = CLLocationCoordinate2DMake(minLat, minLon);
  CLLocationCoordinate2D maxC = CLLocationCoordinate2DMake(maxLat, maxLon);
  MKMapPoint minP = MKMapPointForCoordinate(minC);
  MKMapPoint maxP = MKMapPointForCoordinate(maxC);
  double x;
  double y;
  
  NSLog(@"MAP MIN: %f, %f", minP.x, minP.y);
  NSLog(@"MAP MAX: %f, %f", maxP.x, maxP.y);
  
  double minX = -40000*4;
  double maxX =  40000*4;
  double minY = -20000*4;
  double maxY =  70000*4;

  NSLog(@"POLY MIN: %f, %f", minX, minY);
  NSLog(@"POLY MAX: %f, %f", maxX, maxY);
  
  CartographicOverlay *overlay = [[CartographicOverlay alloc] init];
  
  x = minP.x + ((40000 - minX) / (maxX - minX)) * (maxP.x - minP.x);
  y = minP.y + ((70000 - minY) / (maxY - minY)) * (maxP.y - minP.y);
  MKMapPoint ne = MKMapPointMake(x, y);
  x = minP.x + ((-40000 - minX) / (maxX - minX)) * (maxP.x - minP.x);
  y = minP.y + ((-20000 - minY) / (maxY - minY)) * (maxP.y - minP.y);
  MKMapPoint sw = MKMapPointMake(x, y);
  
  overlay.image = [NSImage imageNamed:@"Galaxy_L_Grid.jpg"];
  overlay.ne    = MKCoordinateForMapPoint(ne);
  overlay.sw    = MKCoordinateForMapPoint(sw);
  
  [mapView addOverlay:overlay];
  
  for (Jump *jump in jumps) {
    if (jump.system.hasCoordinates) {
      x = minP.x + ((jump.system.x - minX) / (maxX - minX)) * (maxP.x - minP.x);
      y = minP.y + ((jump.system.z - minY) / (maxY - minY)) * (maxP.y - minP.y);
      
      point = MKMapPointMake(x, y);
    
      [points appendBytes:&point length:sizeof(MKMapPoint)];
      
      if (jump.system.note.length > 0) {
        MapAnnotation *annotation = [[MapAnnotation alloc] initWithCoordinate:MKCoordinateForMapPoint(point)
                                                                        title:jump.system.note];
        
        [mapView addAnnotation:annotation];
      }
    }
  }
  
  MKPolyline *polyline = [MKPolyline polylineWithPoints:(MKMapPoint *)points.bytes count:(points.length / sizeof(MKMapPoint))];
  
  NSLog(@"Adding polyline with %ld points", polyline.pointCount);
  
  [mapView addOverlay:polyline];
  
  MKMapRect          mapRect = overlay.boundingMapRect;
  MKCoordinateRegion region  = MKCoordinateRegionForMapRect(mapRect);
  
  //region.span = MKCoordinateSpanMake(region.span.latitudeDelta + 0.01, region.span.longitudeDelta + 0.01);
  
  NSLog(@"CENTER: %f, %f", region.center.latitude, region.center.longitude);
  NSLog(@"SPAN: %f, %f", region.span.latitudeDelta, region.span.longitudeDelta);
  
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
    ((MKPolylineRenderer *)renderer).lineWidth   = 3;
    ((MKPolylineRenderer *)renderer).lineJoin    = kCGLineJoinRound;
  }
  else if ([overlay isKindOfClass:[CartographicOverlay class]]) {
    renderer = [[CartographicOverlayRenderer alloc] initWithOverlay:overlay];
  }

  return renderer;
}

@end
