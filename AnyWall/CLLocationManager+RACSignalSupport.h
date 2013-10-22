//
//  CLLocationManager+RACSignalSupport.h
//  ReactiveCocoa
//
//  Created by Dave Lee on 2013-10-16.
//  Copyright (c) 2013 GitHub, Inc. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

@class RACSignal;

@interface CLLocationManager (RACSignalSupport)

/// A signal of location updates.
///
/// Returns a signal which will send location updates and errors. This signal
/// strongly references the receiver.
- (RACSignal *)rac_activeLocationUpdatesSignal;

/// A signal which sends the application's current location authorization status.
///
/// Returns a signal which will send authorization status. This signal strongly
/// references the receiver.
- (RACSignal *)rac_authorizationStatusSignal;

@end
