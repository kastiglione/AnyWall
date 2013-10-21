//
//  PAWSearchRadius.h
//  Anywall
//
//  Created by Christopher Bowns on 2/8/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <MapKit/MapKit.h>

@interface PAWSearchRadius : NSObject <MKOverlay>

@property (nonatomic, assign, readwrite) CLLocationCoordinate2D coordinate;
@property (nonatomic, assign, readwrite) CLLocationDistance radius;
@property (nonatomic, assign) MKMapRect boundingMapRect;

@end
