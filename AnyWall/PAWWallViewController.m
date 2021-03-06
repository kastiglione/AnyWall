//
//  PAWWallViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 1/30/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>
#import <ReactiveCocoa/EXTScope.h>
#import <Parse-RACExtensions/PFQuery+RACExtensions.h>

#import "PAWWallViewController.h"

#import "PAWSettingsViewController.h"
#import "PAWWallPostCreateViewController.h"
#import "PAWAppDelegate.h"
#import "PAWWallPostsTableViewController.h"
#import "PAWSearchRadius.h"
#import "PAWCircleView.h"
#import "PAWPost.h"
#import <CoreLocation/CoreLocation.h>
#import "CLLocationManager+RACSignalSupport.h"

// private methods and properties
@interface PAWWallViewController ()

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) PAWSearchRadius *searchRadius;
@property (nonatomic, strong) PAWWallPostsTableViewController *wallPostsTableViewController;
@property (nonatomic, assign) BOOL mapPinsPlaced;
@property (nonatomic, assign) BOOL trackCurrentLocation;

// posts:
@property (nonatomic, strong) NSArray *allPosts;

@property (nonatomic, assign) CLLocationAccuracy filterDistance;
@property (nonatomic, strong) CLLocation *currentLocation;

@end

@implementation PAWWallViewController

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

	self.trackCurrentLocation = YES;

	@weakify(self);

	RACSignal *currentCoordinate = [RACObserve(self, currentLocation) map:^(CLLocation* location) {
		return [NSValue valueWithMKCoordinate:location.coordinate];
	}];

	RACSignal *currentRegion = [RACObserve(self, filterDistance) map:^(NSNumber *radius) {
		@strongify(self);
		CLLocationAccuracy diameter = 2 * radius.doubleValue;
		MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(self.mapView.centerCoordinate, diameter, diameter);
		return [NSValue valueWithBytes:&region objCType:@encode(MKCoordinateRegion)];
	}];

	// Function to create a signal for a given annotation action (selection or
	// deselection), and for a given annotation class.
	RACSignal *(^annotationForTap)(SEL, Class) = ^(SEL selector, Class annotationClass) {
		return [[[self
			rac_signalForSelector:selector fromProtocol:@protocol(MKMapViewDelegate)]
			reduceEach:^(MKMapView *mapView, MKAnnotationView *annotationView) {
				return annotationView.annotation;
			}]
			filter:^(id annotation) {
				return [annotation isKindOfClass:annotationClass];
			}];
	};

	// Annotation selection triggers cell highlighting.
	[self.wallPostsTableViewController
		rac_liftSelector:@selector(highlightCellForPost:)
		withSignals:annotationForTap(@selector(mapView:didSelectAnnotationView:), PAWPost.class), nil];

	// Annotation deselection triggers cell unhighlighting.
	[self.wallPostsTableViewController
		rac_liftSelector:@selector(unhighlightCellForPost:)
		withSignals:annotationForTap(@selector(mapView:didDeselectAnnotationView:), PAWPost.class), nil];

	// Helper function to update the map center or region, but only when the
	// current location is being tracked.
	void (^updateMapWhenTracking)(SEL, RACSignal *) = ^(SEL selector, RACSignal *property) {
		RACSignal *trackedChanged = [property filter:^(id _) {
			@strongify(self);
			return self.trackCurrentLocation;
		}];

		[[self.mapView
			rac_liftSelector:selector
			withSignals:trackedChanged, [RACSignal return:@YES], nil]
			subscribeNext:^(id x) {
				// Ensure tracking state is maintained.
				@strongify(self);
				self.trackCurrentLocation = YES;
			}];
	};

	// Update map center when location has changed, but only when tracking.
	updateMapWhenTracking(@selector(setCenterCoordinate:animated:), currentCoordinate);

	// Update map region when search radius has changed, but only when tracking.
	updateMapWhenTracking(@selector(setRegion:animated:), currentRegion);

	// Assume map region changes are triggered by the user (pan, zoom). Changes
	// by the user turn off trackCurrentLocation. The user can turn on tracking
	// by tapping the current location annotaion view (blue dot).
	RAC(self, trackCurrentLocation) = [[self
		rac_signalForSelector:@selector(mapView:regionWillChangeAnimated:) fromProtocol:@protocol(MKMapViewDelegate)]
		mapReplace:@NO];

	// When the user taps the user location annotation (blue dot), center the
	// map, and turn on location tracking.
	[annotationForTap(@selector(mapView:didSelectAnnotationView:), MKUserLocation.class) subscribeNext:^(id _) {
		@strongify(self);
		[self.mapView setCenterCoordinate:self.currentLocation.coordinate animated:YES];
		self.trackCurrentLocation = YES;
	}];

	// Define search radius overlay.
	self.searchRadius = [[PAWSearchRadius alloc] init];
	[self.mapView addOverlay:self.searchRadius];
	RAC(self.searchRadius, coordinate) = currentCoordinate;
	RAC(self.searchRadius, radius) = RACObserve(self, filterDistance);

	// Query for nearby posts when the location changes.
	RAC(self, allPosts) = [[self
		rac_liftSelector:@selector(queryForAllPostsNearLocation:)
		withSignals:[RACObserve(self, currentLocation) ignore:nil], nil]
		switchToLatest];

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

	self.locationManager = [[CLLocationManager alloc] init];
	self.locationManager.delegate = self;
	self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
	self.locationManager.distanceFilter = kCLLocationAccuracyNearestTenMeters;

	// Signal to determine whether core location is authorized. Note that
	// kCLAuthorizationStatusNotDetermined is considered to be authorized.
	RACSignal *locationAuthorized = [self.locationManager.rac_authorizationStatusSignal
		map:^(NSNumber *authorization) {
			CLAuthorizationStatus status = authorization.unsignedIntegerValue;
			return @(status == kCLAuthorizationStatusAuthorized || status == kCLAuthorizationStatusNotDetermined);
		}];

	// Disable the post button when core location is unauthorized.
	RAC(self, navigationItem.rightBarButtonItem.enabled) = locationAuthorized;

	// Start location updates only when authorized *and* when view is visible.
	RACSignal *enableLocationUpdates = [[[RACSignal
		merge:@[
			[[self rac_signalForSelector:@selector(viewWillAppear:)] mapReplace:@YES],
			[[self rac_signalForSelector:@selector(viewDidDisappear:)] mapReplace:@NO],
		]]
		combineLatestWith:locationAuthorized]
		and];

	// Switch on/off location updates based on conditions.
	RACSignal *conditionalCurrentLocation = [RACSignal
		if:enableLocationUpdates
		then:self.locationManager.rac_activeLocationUpdatesSignal
		else:[RACSignal never]];

	RAC(self, currentLocation) = [conditionalCurrentLocation
		catch:^(NSError *error) {
			// Nothing we can do about this, propogate the error.
			if (error.code == kCLErrorDenied) return [RACSignal error:error];

			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error retrieving location" message:error.localizedDescription delegate:nil cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
			[alert show];

			// Silence the error.
			return [RACSignal empty];
		}];

	// Bust any caching of which methods the delegate implements.
	self.mapView.delegate = nil;
	self.mapView.delegate = self;
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
		// Assigning to currentLocation triggers requerying for nearby posts.
		self.currentLocation = self.locationManager.location;
		[self.wallPostsTableViewController loadObjects];
	}];

	[self.navigationController presentViewController:createPostViewController animated:YES completion:nil];
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

#pragma mark - Fetch map pins

- (RACSignal *)queryForAllPostsNearLocation:(CLLocation *)currentLocation {
	return [RACSignal defer:^{
		PFQuery *query = [PFQuery queryWithClassName:kPAWParsePostsClassKey];

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

		return [[query rac_findObjects] map:^(NSArray *objects) {
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

			self.mapPinsPlaced = YES;

			return [allNewPosts copy];
		}];
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
