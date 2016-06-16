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

//boundaries of galaxy, in ED coordinate system

#define MINX -45000
#define MAXX  45000
#define MINY -20000
#define MAXY  70000

@implementation MapViewController {
  IBOutlet MKMapView *mapView;
  
  MKPolyline     *polyline;
  NSMutableArray *waypoints;
}

#pragma mark -
#pragma mark NSViewController delegate

- (void)viewDidLoad {
  [super viewDidLoad];
  
  polyline  = nil;
  waypoints = [[NSMutableArray alloc] init];
}

- (void)viewDidAppear {
  [super viewDidAppear];
  
  [Answers logCustomEventWithName:@"Screen view" customAttributes:@{@"screen":NSStringFromClass(self.class)}];

  [self loadMap];
  
  [NSWorkspace.sharedWorkspace.notificationCenter addObserver:self selector:@selector(loadJumpsAndWaypoints) name:NEW_JUMP_NOTIFICATION object:nil];
}

- (void)viewDidDisappear {
  [super viewDidDisappear];
  
  [NSWorkspace.sharedWorkspace.notificationCenter removeObserver:self name:NEW_JUMP_NOTIFICATION object:nil];
}

#pragma mark -
#pragma mark ED coordinate system

static MKMapPoint minPoint;
static MKMapPoint maxPoint;

- (void)loadCoordinateSystem {
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
  
  minPoint = MKMapPointForCoordinate(minC);
  maxPoint = MKMapPointForCoordinate(maxC);
}

NS_INLINE MKMapPoint pointFromEDPoint(MKMapPoint point) {
  return MKMapPointMake(minPoint.x + ((point.x - MINX) / (MAXX - MINX)) * (maxPoint.x - minPoint.x),
                        minPoint.y + ((point.y - MINY) / (MAXY - MINY)) * (maxPoint.y - minPoint.y));
}

NS_INLINE CLLocationCoordinate2D coordinateFromEDPoint(MKMapPoint point) {
  return MKCoordinateForMapPoint(pointFromEDPoint(point));
}

#pragma mark -
#pragma mark map contents management

- (void)loadMap {
  static dispatch_once_t onceToken;
  
  dispatch_once(&onceToken, ^{
    
    //calculate ED coordinate system
    
    [self loadCoordinateSystem];
    
    
    //add base layer (black) overlay, so that we do not display Apple Maps as background ;-)
    
    BlackTileOverlay *tileOverlay = [[BlackTileOverlay alloc] init];
    
    [mapView addOverlay:tileOverlay];
    
    
    //add background galaxy image overlay
    
    CartographicOverlay *overlay = [[CartographicOverlay alloc] init];
    
    overlay.image = [NSImage imageNamed:@"Galaxy_L_Grid.jpg"];
    overlay.ne    = coordinateFromEDPoint(MKMapPointMake( 45000,  70000));
    overlay.sw    = coordinateFromEDPoint(MKMapPointMake(-45000, -20000));
    
    [mapView addOverlay:overlay];
    
    
    // zoom and center map to match selected background image
    
    MKMapRect          mapRect = overlay.boundingMapRect;
    MKCoordinateRegion region  = MKCoordinateRegionForMapRect(mapRect);
    
    [mapView setRegion:region animated:YES];
  });
  
  
  //add polyline with CMDR jumps
  
  [self loadJumpsAndWaypoints];
}

- (void)loadJumpsAndWaypoints {
  NSArray       *jumps  = [Jump allJumpsOfCommander:Commander.activeCommander];
  NSMutableData *points = [NSMutableData data];
  MKMapPoint     point;

  [mapView removeOverlay:polyline];
  [mapView removeAnnotations:waypoints];
  
  polyline  = nil;
  waypoints = [[NSMutableArray alloc] init];

  for (Jump *jump in jumps) {
    if (jump.system.hasCoordinates && !jump.hidden) {
      point = pointFromEDPoint(MKMapPointMake(jump.system.x, jump.system.z));
      
      [points appendBytes:&point length:sizeof(MKMapPoint)];
      
      //if system has a note, add an annotation for it
      
      if (jump.system.note.length > 0) {
        MapAnnotation *waypoint = [[MapAnnotation alloc] initWithCoordinate:MKCoordinateForMapPoint(point)
                                                                      title:jump.system.note];
        
        [waypoints addObject:waypoint];
      }
    }
  }
  
  polyline = [MKPolyline polylineWithPoints:(MKMapPoint *)points.bytes count:(points.length / sizeof(MKMapPoint))];
  
  [mapView addOverlay:polyline];
  [mapView addAnnotations:waypoints];
}

#pragma mark -
#pragma mark MKMapView delegate

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

- (MKOverlayRenderer *)mapView:(MKMapView*)mapView rendererForOverlay:(id<MKOverlay>)overlay {
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
