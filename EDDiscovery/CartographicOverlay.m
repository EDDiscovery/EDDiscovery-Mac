//
//  CartographicMapOverlay.m
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//

#import "CartographicOverlay.h"

@implementation CartographicOverlay {
  NSString               *pathName;
  CLLocationCoordinate2D  ne;
  CLLocationCoordinate2D  sw;
  CLLocationDegrees       rotation;
  NSInteger               drawOrder;
}

#pragma mark -
#pragma mark NSCoding protocol implementation

- (id)initWithCoder:(NSCoder *)decoder {
  self = [super init];
  
  if (self != nil) {
    CLLocation *_ne        = [decoder decodeObjectForKey:@"ne"];
    CLLocation *_sw        = [decoder decodeObjectForKey:@"sw"];
    NSNumber   *_rotation  = [decoder decodeObjectForKey:@"rotation"];

    self.ne        = CLLocationCoordinate2DMake(_ne.coordinate.latitude, _ne.coordinate.longitude);
    self.sw        = CLLocationCoordinate2DMake(_sw.coordinate.latitude, _sw.coordinate.longitude);
    self.rotation  = _rotation.doubleValue;
  }
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)encoder {
  CLLocation *_ne        = [[CLLocation alloc] initWithLatitude:self.ne.latitude longitude:self.ne.longitude];
  CLLocation *_sw        = [[CLLocation alloc] initWithLatitude:self.sw.latitude longitude:self.sw.longitude];
  NSNumber   *_rotation  = [[NSNumber alloc] initWithDouble:self.rotation];
  
  [encoder encodeObject:_ne        forKey:@"ne"];
  [encoder encodeObject:_sw        forKey:@"sw"];
  [encoder encodeObject:_rotation  forKey:@"rotation"];
}

#pragma mark -
#pragma mark MKOverlay protocol implementation

- (CLLocationCoordinate2D)coordinate {
  CLLocationDegrees      x      = (self.ne.longitude + self.sw.longitude) / 2.0;
  CLLocationDegrees      y      = (self.ne.latitude  + self.sw.latitude ) / 2.0;
  CLLocationCoordinate2D center = CLLocationCoordinate2DMake(y, x);
  
  return center;
}

- (MKMapRect)boundingMapRect {
  MKCoordinateRegion region = self.coordinateRegion;
  
  MKMapPoint a = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude + region.span.latitudeDelta / 2,
                                                                    region.center.longitude - region.span.longitudeDelta / 2));
  MKMapPoint b = MKMapPointForCoordinate(CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta / 2,
                                                                    region.center.longitude + region.span.longitudeDelta / 2));
  
  return MKMapRectMake(MIN(a.x,b.x), MIN(a.y,b.y), ABS(a.x-b.x), ABS(a.y-b.y));
}

#pragma mark -
#pragma mark properties

@synthesize ne;
@synthesize sw;
@synthesize rotation;

- (MKCoordinateRegion)coordinateRegion {
  CLLocationCoordinate2D center   = self.coordinate;
  CLLocationDegrees      latDelta = self.ne.latitude  - self.sw.latitude;
  CLLocationDegrees      lonDelta = self.ne.longitude - self.sw.longitude;
  MKCoordinateSpan       span     = MKCoordinateSpanMake(latDelta, lonDelta);
  MKCoordinateRegion     region   = MKCoordinateRegionMake(center, span);
  
  return region;
}

@end
