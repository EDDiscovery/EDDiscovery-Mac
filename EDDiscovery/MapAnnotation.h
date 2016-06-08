//
//  MapAnnotation.h
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MapAnnotation : NSObject <MKAnnotation> {
@private
	CLLocationCoordinate2D  _coordinate;
	NSString               *_title;
}

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                   title:(NSString *)title;

@property (nonatomic, assign)         CLLocationCoordinate2D  coordinate;
@property (nonatomic, readonly, copy) NSString               *title;

@end