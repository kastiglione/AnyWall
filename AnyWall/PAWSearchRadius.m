//
//  PAWSearchRadius.m
//  Anywall
//
//  Created by Christopher Bowns on 2/8/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "PAWSearchRadius.h"

@implementation PAWSearchRadius

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate radius:(CLLocationDistance)radius {
	self = [super init];
	if (self != nil) {
		_coordinate = coordinate;
		_radius = radius;
	}
	return self;
}

- (MKMapRect)boundingMapRect {
	return MKMapRectWorld;
}

@end
