//
//  CartographicMapOverlay.h
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface CartographicOverlay : NSObject <MKOverlay, NSCoding>

@property (nonatomic, readonly) CLLocationCoordinate2D coordinate;
@property (nonatomic, readonly) MKMapRect              boundingMapRect;

@property(nonatomic, retain  ) NSString               *pathName;
@property(nonatomic, assign  ) CLLocationCoordinate2D  ne;
@property(nonatomic, assign  ) CLLocationCoordinate2D  sw;
@property(nonatomic, assign  ) CLLocationDegrees       rotation;
@property(nonatomic, assign  ) NSInteger               drawOrder;
@property(nonatomic, readonly) BOOL                    isValidOverlay;

@property (nonatomic, retain) NSImage    *image;

@end
