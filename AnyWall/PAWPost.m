//
//  PAWPost.m
//  Anywall
//
//  Created by Christopher Bowns on 2/8/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "PAWPost.h"
#import "PAWAppDelegate.h"

@interface PAWPost ()

// Redefine these properties to make them read/write for internal class accesses and mutations.
@property (nonatomic, assign) CLLocationCoordinate2D coordinate;

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *subtitle;

@property (nonatomic, strong) PFObject *object;
@property (nonatomic, strong) PFGeoPoint *geopoint;
@property (nonatomic, strong) PFUser *user;
@property (nonatomic, assign) MKPinAnnotationColor pinColor;

@end

@implementation PAWPost

- (id)initWithCoordinate:(CLLocationCoordinate2D)coordinate andTitle:(NSString *)title andSubtitle:(NSString *)subtitle {
	self = [super init];
	if (self != nil) {
		_coordinate = coordinate;
		_title = [title copy];
		_subtitle = [subtitle copy];
		_animatesDrop = NO;
	}
	return self;
}

- (id)initWithPFObject:(PFObject *)object {
	self.object = object;
	self.geopoint = [object objectForKey:kPAWParseLocationKey];
	self.user = [object objectForKey:kPAWParseUserKey];

	[object fetchIfNeeded]; 
	CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(self.geopoint.latitude, self.geopoint.longitude);
	NSString *title = [object objectForKey:kPAWParseTextKey];
	NSString *subtitle = [[object objectForKey:kPAWParseUserKey] objectForKey:kPAWParseUsernameKey];

	return [self initWithCoordinate:coordinate andTitle:title andSubtitle:subtitle];
}

- (BOOL)equalToPost:(PAWPost *)post {
	if (post == nil) {
		return NO;
	}

	if (post.object && self.object) {
		// We have a PFObject inside the PAWPost, use that instead.
		if ([post.object.objectId compare:self.object.objectId] != NSOrderedSame) {
			return NO;
		}
		return YES;
	} else {
		// Fallback code:

		if ([post.title compare:self.title] != NSOrderedSame ||
			[post.subtitle compare:self.subtitle] != NSOrderedSame ||
			post.coordinate.latitude != self.coordinate.latitude ||
			post.coordinate.longitude != self.coordinate.longitude ) {
			return NO;
		}

		return YES;
	}
}

- (void)setTitleAndSubtitleOutsideDistance:(BOOL)outside {
	if (outside) {
		self.subtitle = nil;
		self.title = kPAWWallCantViewPost;
		self.pinColor = MKPinAnnotationColorRed;
	} else {
		self.title = [self.object objectForKey:kPAWParseTextKey];
		self.subtitle = [[self.object objectForKey:kPAWParseUserKey] objectForKey:kPAWParseUsernameKey];
		self.pinColor = MKPinAnnotationColorGreen;
	}
}

@end
