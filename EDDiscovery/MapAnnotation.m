//
//  MapAnnotation.m
//  EDDiscovery
//
//  Created by thorin on 08/06/16.
//  Copyright © 2016 Michele Noberasco. All rights reserved.
//

#import "MapAnnotation.h"

@interface MapAnnotation()

@property(nonatomic, readonly) CLLocationCoordinate2D  _coordinate;

@end

@implementation MapAnnotation

#pragma mark -
#pragma mark memory management

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate
                   title:(NSString*)title {
	if ((self = [super init])) {
    _coordinate     = coordinate;
		_title          = title;
	}
	
	return self;
}

#pragma mark -
#pragma mark properties

@synthesize _coordinate    = _coordinate;

- (CLLocationCoordinate2D)coordinate {
  return _coordinate;
}

- (void)setCoordinate:(CLLocationCoordinate2D)coordinate {
  _coordinate = coordinate;
}

@end
