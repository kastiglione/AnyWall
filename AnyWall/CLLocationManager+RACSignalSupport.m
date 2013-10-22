//
//  CLLocationManager+RACSignalSupport.m
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>

#import "CLLocationManager+RACSignalSupport.h"
#import <objc/runtime.h>

@implementation CLLocationManager (RACSignalSupport)

static void const * const CLLocationManagerSubscriberCountKey = &CLLocationManagerSubscriberCountKey;

- (RACSignal *)rac_activeLocationUpdatesSignal {
	// Reference self intentionally to bind its lifetime to at least as long as
	// this signal.
	return [[RACSignal
		createSignal:^ id (id<RACSubscriber> subscriber) {
			// The preferred delegate method for OS X 10.9+ and iOS 6.0+.
			SEL preferredSelector = NSSelectorFromString(@"locationManager:didUpdateLocations:");
			struct objc_method_description preferredMethod = protocol_getMethodDescription(@protocol(CLLocationManagerDelegate), preferredSelector, NO, YES);

			if (preferredMethod.name != NULL) {
				[[[self
					rac_valuesForDelegateSelector:preferredSelector]
					map:^(NSArray *locations) {
						return [locations lastObject];
					}]
					subscribe:subscriber];
			} else {
				// Fallback for OS X [10.7, 10.9) and iOS 5.
				[[self
					rac_valuesForDelegateSelector:@selector(locationManager:didUpdateToLocation:fromLocation:)]
					subscribe:subscriber];
			}

			[[self
				rac_valuesForDelegateSelector:@selector(locationManager:didFailWithError:)]
				subscribeNext:^(NSError *error) {
					// Documentation says Core Location will keep trying in the
					// case of kCLErrorLocationUnknown, so ignore it.
					if (error.domain == kCLErrorDomain && error.code == kCLErrorLocationUnknown) return;

					[subscriber sendError:error];
				}];

			// Bust any caching of which methods the delegate implements.
			id<CLLocationManagerDelegate> delegate = self.delegate;
			self.delegate = nil;
			self.delegate = delegate;

			void (^withSubscriberCount)(void (^)(NSUInteger *)) = ^(void (^block)(NSUInteger *)) {
				@synchronized (self) {
					NSUInteger subscriberCount = [objc_getAssociatedObject(self, CLLocationManagerSubscriberCountKey) unsignedIntegerValue];
					block(&subscriberCount);
					objc_setAssociatedObject(self, CLLocationManagerSubscriberCountKey, @(subscriberCount), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
				}
			};

			withSubscriberCount(^(NSUInteger *subscriberCount) {
				if (++*subscriberCount == 1) {
					[self startUpdatingLocation];
				} else {
					// Replay most recent location to later subscribers.
					if (self.location != nil) [subscriber sendNext:self.location];
				}
			});

			return [RACDisposable disposableWithBlock:^{
				withSubscriberCount(^(NSUInteger *subscriberCount) {
					if (--*subscriberCount == 0) {
						[self startUpdatingLocation];
					}
				});
			}];
		}]
		setNameWithFormat:@"<%@: %p> -rac_activeLocationUpdatesSignal", self.class, self];
}

- (RACSignal *)rac_authorizationStatusSignal {
	RACSignal *statusChanged = [[[RACSignal
		defer:^{
			// Reference self intentionally to bind its lifetime to at least as
			// long as this signal.
			return [RACSignal return:@(self.class.authorizationStatus)];
		}]
		concat:[self rac_valuesForDelegateSelector:@selector(locationManager:didChangeAuthorizationStatus:)]]
		setNameWithFormat:@"<%@: %p> -rac_authorizationStatusSignal", self.class, self];

	// Bust any caching of which methods the delegate implements.
	id<CLLocationManagerDelegate> delegate = self.delegate;
	self.delegate = nil;
	self.delegate = delegate;

	return statusChanged;
}

#pragma mark - Private

- (RACSignal *)rac_valuesForDelegateSelector:(SEL)selector {
	return [[(id)self.delegate
		rac_signalForSelector:selector fromProtocol:@protocol(CLLocationManagerDelegate)]
		map:^(RACTuple *tuple) {
			// Handle selectors of varying arity, always taking the second.
			return tuple[1];
		}];
}

@end
