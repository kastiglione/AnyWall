//
//  PAWWallViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 1/30/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

#import "PAWWallViewController.h"

#import "PAWSettingsViewController.h"
#import "PAWWallPostCreateViewController.h"
#import "PAWAppDelegate.h"
#import "PAWWallPostsTableViewController.h"
#import "PAWSearchRadius.h"
#import "PAWCircleView.h"
#import "PAWPost.h"
#import <CoreLocation/CoreLocation.h>

// private methods and properties
@interface PAWWallViewController ()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) PAWSearchRadius *searchRadius;
@property (nonatomic, strong) PAWWallPostsTableViewController *wallPostsTableViewController;
@property (nonatomic, assign) BOOL mapPinsPlaced;
@property (nonatomic, assign) BOOL trackCurrentLocation;

// posts:
@property (nonatomic, strong) NSMutableArray *allPosts;

@property (nonatomic, assign) CLLocationAccuracy filterDistance;
@property (nonatomic, strong) CLLocation *currentLocation;

@end

@implementation PAWWallViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	if (self != nil) {
		_allPosts = [[NSMutableArray alloc] initWithCapacity:10];
	}
	return self;
}

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.

	self.title = @"Anywall";

	// Desired search radius. Use 1000 feet as default.
	// Assign directly to ivar to prevent side effects for initialization.
	_filterDistance = [NSUserDefaults.standardUserDefaults doubleForKey:kPAWDefaultsFilterDistanceKey] ?: 1000 * kPAWFeetToMeters;

	// Add the wall posts tableview as a subview with view containment (new in iOS 5.0):
	self.wallPostsTableViewController = [[PAWWallPostsTableViewController alloc] initWithStyle:UITableViewStylePlain];
	RAC(self.wallPostsTableViewController, filterDistance) = [RACObserve(self, filterDistance) skip:1];
	RAC(self.wallPostsTableViewController, currentLocation) = [RACObserve(self, currentLocation) skip:1];
	[self addChildViewController:self.wallPostsTableViewController];

	self.wallPostsTableViewController.view.frame = CGRectMake(6.0f, 215.0f, 308.0f, self.view.bounds.size.height - 215.0f);
	[self.view addSubview:self.wallPostsTableViewController.view];

	// Set our nav bar items.
	[self.navigationController setNavigationBarHidden:NO animated:NO];
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
											  initWithTitle:@"Post" style:UIBarButtonItemStylePlain target:self action:@selector(postButtonSelected:)];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
											 initWithTitle:@"Settings" style:UIBarButtonItemStylePlain target:self action:@selector(settingsButtonSelected:)];
	self.navigationItem.titleView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"Anywall.png"]];

	self.mapView.region = MKCoordinateRegionMake(CLLocationCoordinate2DMake(37.332495f, -122.029095f), MKCoordinateSpanMake(0.008516f, 0.021801f));

	self.trackCurrentLocation = YES;

	RACSignal *currentCoordinate = [RACObserve(self, currentLocation) map:^(CLLocation* location) {
		return [NSValue valueWithMKCoordinate:location.coordinate];
	}];

	// Define search radius overlay.
	self.searchRadius = [[PAWSearchRadius alloc] init];
	[self.mapView addOverlay:self.searchRadius];
	RAC(self.searchRadius, coordinate) = currentCoordinate;
	RAC(self.searchRadius, radius) = RACObserve(self, filterDistance);

	// Query for nearby posts when the location changes.
	[self
		rac_liftSelector:@selector(queryForAllPostsNearLocation:)
		withSignals:RACObserve(self, currentLocation), nil];

	// Update pin state for nearby posts when either location or radius change.
	[self
		rac_liftSelector:@selector(updatePostsForLocation:withNearbyDistance:)
		withSignals:RACObserve(self, currentLocation), RACObserve(self, filterDistance), nil];

	// Synchronize filter distance to user defaults.
	RACSignal *filterDistanceUpdates = [[RACObserve(self, filterDistance) skip:1] distinctUntilChanged];
	[[NSUserDefaults.standardUserDefaults
		rac_liftSelector:@selector(setDouble:forKey:)
		withSignals:filterDistanceUpdates, [RACSignal return:kPAWDefaultsFilterDistanceKey], nil]
		subscribeNext:^(id _) {
			[NSUserDefaults.standardUserDefaults synchronize];
		}];

	[self startStandardUpdates];
}

- (void)viewWillAppear:(BOOL)animated {
	[self.locationManager startUpdatingLocation];
	[super viewWillAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	[self.locationManager stopUpdatingLocation];
	[super viewDidDisappear:animated];
}

- (void)dealloc {
	[self.locationManager stopUpdatingLocation];
}

#pragma mark - NSNotificationCenter notification handlers

- (void)setFilterDistance:(CLLocationAccuracy)filterDistance {
	_filterDistance = filterDistance;

	// If they panned the map since our last location update, don't recenter it.
	if (self.trackCurrentLocation) {
		// Set the map's region centered on their location at 2x filterDistance
		MKCoordinateRegion newRegion = MKCoordinateRegionMakeWithDistance(self.currentLocation.coordinate, self.filterDistance * 2.0f, self.filterDistance * 2.0f);

		[self.mapView setRegion:newRegion animated:YES];
		self.trackCurrentLocation = YES;
	} else {
		// Just zoom to the new search radius (or maybe don't even do that?)
		MKCoordinateRegion currentRegion = self.mapView.region;
		MKCoordinateRegion newRegion = MKCoordinateRegionMakeWithDistance(currentRegion.center, self.filterDistance * 2.0f, self.filterDistance * 2.0f);

		BOOL oldMapPannedValue = self.trackCurrentLocation;
		[self.mapView setRegion:newRegion animated:YES];
		self.trackCurrentLocation = oldMapPannedValue;
	}
}

- (void)setCurrentLocation:(CLLocation *)currentLocation {
	_currentLocation = currentLocation;

	// If they panned the map since our last location update, don't recenter it.
	if (self.trackCurrentLocation) {
		// Set the map's region centered on their new location at 2x filterDistance
		MKCoordinateRegion newRegion = MKCoordinateRegionMakeWithDistance(self.currentLocation.coordinate, self.filterDistance * 2.0f, self.filterDistance * 2.0f);

		BOOL oldMapPannedValue = self.trackCurrentLocation;
		[self.mapView setRegion:newRegion animated:YES];
		self.trackCurrentLocation = oldMapPannedValue;
	} // else do nothing.
}

#pragma mark - UINavigationBar-based actions

- (IBAction)settingsButtonSelected:(id)sender {
	PAWSettingsViewController *settingsViewController = [[PAWSettingsViewController alloc] initWithNibName:nil bundle:nil];
	settingsViewController.modalTransitionStyle = UIModalTransitionStyleFlipHorizontal;
	settingsViewController.filterDistance = self.filterDistance;

	RAC(self, filterDistance) = [[RACObserve(settingsViewController, filterDistance) skip:1] takeLast:1];

	[self.navigationController presentViewController:settingsViewController animated:YES completion:nil];
}

- (IBAction)postButtonSelected:(id)sender {
	PAWWallPostCreateViewController *createPostViewController = [[PAWWallPostCreateViewController alloc] initWithNibName:nil bundle:nil];
	RAC(createPostViewController, currentLocation) = RACObserve(self, currentLocation);

	[[[RACObserve(createPostViewController, createdPost) skip:1] takeLast:1] subscribeNext:^(id _) {
		[self queryForAllPostsNearLocation:self.currentLocation];
		[self.wallPostsTableViewController loadObjects];
	}];

	[self.navigationController presentViewController:createPostViewController animated:YES completion:nil];
}

#pragma mark - CLLocationManagerDelegate methods and helpers

- (void)startStandardUpdates {
	if (nil == self.locationManager) {
		self.locationManager = [[CLLocationManager alloc] init];
	}

	self.locationManager.delegate = self;
	self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;

	// Set a movement threshold for new events.
	self.locationManager.distanceFilter = kCLLocationAccuracyNearestTenMeters;

	[self.locationManager startUpdatingLocation];

	CLLocation *currentLocation = self.locationManager.location;
	if (currentLocation) {
		self.currentLocation = currentLocation;
	}
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	NSLog(@"%s", __PRETTY_FUNCTION__);
	switch (status) {
		case kCLAuthorizationStatusAuthorized:
			NSLog(@"kCLAuthorizationStatusAuthorized");
			// Re-enable the post button if it was disabled before.
			self.navigationItem.rightBarButtonItem.enabled = YES;
			[self.locationManager startUpdatingLocation];
			break;
		case kCLAuthorizationStatusDenied:
			NSLog(@"kCLAuthorizationStatusDenied");
			{{
				UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Anywall can’t access your current location.\n\nTo view nearby posts or create a post at your current location, turn on access for Anywall to your location in the Settings app under Location Services." message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
				[alertView show];
				// Disable the post button.
				self.navigationItem.rightBarButtonItem.enabled = NO;
			}}
			break;
		case kCLAuthorizationStatusNotDetermined:
			NSLog(@"kCLAuthorizationStatusNotDetermined");
			break;
		case kCLAuthorizationStatusRestricted:
			NSLog(@"kCLAuthorizationStatusRestricted");
			break;
	}
}

- (void)locationManager:(CLLocationManager *)manager
    didUpdateToLocation:(CLLocation *)newLocation
           fromLocation:(CLLocation *)oldLocation {
	NSLog(@"%s", __PRETTY_FUNCTION__);

	self.currentLocation = newLocation;
}

- (void)locationManager:(CLLocationManager *)manager
       didFailWithError:(NSError *)error {
	NSLog(@"%s", __PRETTY_FUNCTION__);
	NSLog(@"Error: %@", [error description]);

	if (error.code == kCLErrorDenied) {
		[self.locationManager stopUpdatingLocation];
	} else if (error.code == kCLErrorLocationUnknown) {
		// todo: retry?
		// set a timer for five seconds to cycle location, and if it fails again, bail and tell the user.
	} else {
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error retrieving location"
		                                                message:[error description]
		                                               delegate:nil
		                                      cancelButtonTitle:nil
		                                      otherButtonTitles:@"Ok", nil];
		[alert show];
	}
}

#pragma mark - MKMapViewDelegate methods

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id <MKOverlay>)overlay {
	// Only display the search radius in iOS 5.1+
	float version = [[[UIDevice currentDevice] systemVersion] floatValue];
	if (version >= 5.1f && [overlay isKindOfClass:[PAWSearchRadius class]]) {
		MKOverlayPathView *pathView = [[PAWCircleView alloc] initWithOverlay:overlay];
		pathView.fillColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.2];
		pathView.strokeColor = [[UIColor darkGrayColor] colorWithAlphaComponent:0.7];
		pathView.lineWidth = 2;

		// Redraw the overlay when either location or radius chages.
		[[[RACSignal
			merge:@[ RACObserve(self, currentLocation), RACObserve(self, filterDistance) ]]
			takeUntil:pathView.rac_willDeallocSignal]
			subscribeNext:^(id x) {
				[pathView invalidatePath];
			}];

		return pathView;
	}

	return nil;
}

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation {
	// Let the system handle user location annotations.
	if ([annotation isKindOfClass:[MKUserLocation class]]) return nil;

	if (![annotation isKindOfClass:[PAWPost class]]) return nil;

	PAWPost *post = (PAWPost *)annotation;

	// Try to dequeue an existing pin view first.
	static NSString *pinIdentifier = @"CustomPinAnnotation";
	MKPinAnnotationView *pinView = (MKPinAnnotationView*)[mapView dequeueReusableAnnotationViewWithIdentifier:pinIdentifier];
	if (pinView == nil) {
		pinView = [[MKPinAnnotationView alloc] initWithAnnotation:post reuseIdentifier:pinIdentifier];
	} else {
		pinView.annotation = post;
	}

	pinView.pinColor = post.pinColor;
	pinView.animatesDrop = post.animatesDrop;
	pinView.canShowCallout = YES;

	return pinView;
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view {
	id<MKAnnotation> annotation = [view annotation];
	if ([annotation isKindOfClass:[PAWPost class]]) {
		PAWPost *post = [view annotation];
		[self.wallPostsTableViewController highlightCellForPost:post];
	} else if ([annotation isKindOfClass:[MKUserLocation class]]) {
		// Center the map on the user's current location:
		MKCoordinateRegion newRegion = MKCoordinateRegionMakeWithDistance(self.currentLocation.coordinate, self.filterDistance * 2, self.filterDistance * 2);

		[self.mapView setRegion:newRegion animated:YES];
		self.trackCurrentLocation = YES;
	}
}

- (void)mapView:(MKMapView *)mapView didDeselectAnnotationView:(MKAnnotationView *)view {
	id<MKAnnotation> annotation = [view annotation];
	if ([annotation isKindOfClass:[PAWPost class]]) {
		PAWPost *post = [view annotation];
		[self.wallPostsTableViewController unhighlightCellForPost:post];
	}
}

- (void)mapView:(MKMapView *)mapView regionWillChangeAnimated:(BOOL)animated {
	self.trackCurrentLocation = NO;
}

#pragma mark - Fetch map pins

- (void)queryForAllPostsNearLocation:(CLLocation *)currentLocation {
	PFQuery *query = [PFQuery queryWithClassName:kPAWParsePostsClassKey];

	if (currentLocation == nil) {
		NSLog(@"%s got a nil location!", __PRETTY_FUNCTION__);
	}

	// If no objects are loaded in memory, we look to the cache first to fill the table
	// and then subsequently do a query against the network.
	if ([self.allPosts count] == 0) {
		query.cachePolicy = kPFCachePolicyCacheThenNetwork;
	}

	// Query for posts sort of kind of near our current location.
	PFGeoPoint *point = [PFGeoPoint geoPointWithLatitude:currentLocation.coordinate.latitude longitude:currentLocation.coordinate.longitude];
	[query whereKey:kPAWParseLocationKey nearGeoPoint:point withinKilometers:kPAWWallPostMaximumSearchDistance];
	[query includeKey:kPAWParseUserKey];
	query.limit = kPAWWallPostsSearch;

	[query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
		if (error) {
			NSLog(@"error in geo query!"); // todo why is this ever happening?
		} else {
			// We need to make new post objects from objects,
			// and update allPosts and the map to reflect this new array.
			// But we don't want to remove all annotations from the mapview blindly,
			// so let's do some work to figure out what's new and what needs removing.

			// 1. Find genuinely new posts:
			NSMutableArray *newPosts = [[NSMutableArray alloc] initWithCapacity:kPAWWallPostsSearch];
			// (Cache the objects we make for the search in step 2:)
			NSMutableArray *allNewPosts = [[NSMutableArray alloc] initWithCapacity:kPAWWallPostsSearch];
			for (PFObject *object in objects) {
				PAWPost *newPost = [[PAWPost alloc] initWithPFObject:object];
				[allNewPosts addObject:newPost];
				BOOL found = NO;
				for (PAWPost *currentPost in self.allPosts) {
					if ([newPost equalToPost:currentPost]) {
						found = YES;
					}
				}
				if (!found) {
					[newPosts addObject:newPost];
				}
			}
			// newPosts now contains our new objects.

			// 2. Find posts in allPosts that didn't make the cut.
			NSMutableArray *postsToRemove = [[NSMutableArray alloc] initWithCapacity:kPAWWallPostsSearch];
			for (PAWPost *currentPost in self.allPosts) {
				BOOL found = NO;
				// Use our object cache from the first loop to save some work.
				for (PAWPost *allNewPost in allNewPosts) {
					if ([currentPost equalToPost:allNewPost]) {
						found = YES;
					}
				}
				if (!found) {
					[postsToRemove addObject:currentPost];
				}
			}
			// postsToRemove has objects that didn't come in with our new results.

			// 3. Configure our new posts; these are about to go onto the map.
			for (PAWPost *newPost in newPosts) {
				CLLocation *objectLocation = [[CLLocation alloc] initWithLatitude:newPost.coordinate.latitude longitude:newPost.coordinate.longitude];
				// if this post is outside the filter distance, don't show the regular callout.
				CLLocationDistance distanceFromCurrent = [currentLocation distanceFromLocation:objectLocation];
				[newPost setTitleAndSubtitleOutsideDistance:( distanceFromCurrent > self.filterDistance )];
				// Animate all pins after the initial load:
				newPost.animatesDrop = self.mapPinsPlaced;
			}

			// At this point, newAllPosts contains a new list of post objects.
			// We should add everything in newPosts to the map, remove everything in postsToRemove,
			// and add newPosts to allPosts.
			[self.mapView removeAnnotations:postsToRemove];
			[self.mapView addAnnotations:newPosts];
			[self.allPosts addObjectsFromArray:newPosts];
			[self.allPosts removeObjectsInArray:postsToRemove];

			self.mapPinsPlaced = YES;
		}
	}];
}

// When we update the search filter distance, we need to update our pins' titles to match.
- (void)updatePostsForLocation:(CLLocation *)currentLocation withNearbyDistance:(CLLocationAccuracy) nearbyDistance {
	for (PAWPost *post in self.allPosts) {
		CLLocation *objectLocation = [[CLLocation alloc] initWithLatitude:post.coordinate.latitude longitude:post.coordinate.longitude];
		// if this post is outside the filter distance, don't show the regular callout.
		CLLocationDistance distanceFromCurrent = [currentLocation distanceFromLocation:objectLocation];
		if (distanceFromCurrent > nearbyDistance) { // Outside search radius
			[post setTitleAndSubtitleOutsideDistance:YES];
			[self.mapView viewForAnnotation:post];
			[(MKPinAnnotationView *) [self.mapView viewForAnnotation:post] setPinColor:post.pinColor];
		} else {
			[post setTitleAndSubtitleOutsideDistance:NO]; // Inside search radius
			[self.mapView viewForAnnotation:post];
			[(MKPinAnnotationView *) [self.mapView viewForAnnotation:post] setPinColor:post.pinColor];
		}
	}
}

@end
