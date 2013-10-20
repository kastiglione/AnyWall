//
//  PAWWallPostsTableViewController.h
//  Anywall
//
//  Created by Christopher Bowns on 2/6/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <Parse/Parse.h>
#import "PAWWallViewController.h"

@interface PAWWallPostsTableViewController : PFQueryTableViewController <PAWWallViewControllerHighlight>

@property (nonatomic, assign) CLLocationAccuracy filterDistance;
@property (nonatomic, strong) CLLocation *currentLocation;

- (void)highlightCellForPost:(PAWPost *)post;
- (void)unhighlightCellForPost:(PAWPost *)post;

@end
