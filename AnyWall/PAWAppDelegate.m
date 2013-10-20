//
//  PAWAppDelegate.m
//  Anywall
//
//  Created by Christopher Bowns on 1/30/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "PAWAppDelegate.h"

#import <Parse/Parse.h>

#import "PAWWelcomeViewController.h"
#import "PAWWallViewController.h"

@implementation PAWAppDelegate

#pragma mark - UIApplicationDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
	
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
	
	// ****************************************************************************
    // Parse initialization
	[Parse setApplicationId:@(getenv("PARSE_APPLICATION_ID")) clientKey:@(getenv("PARSE_CLIENT_KEY"))];
	// ****************************************************************************
	
	// Grab values from NSUserDefaults:
	NSUserDefaults *userDefaults = [NSUserDefaults standardUserDefaults];
	
	// Set the global tint on the navigation bar
	[[UINavigationBar appearance] setTintColor:[UIColor colorWithRed:200.0f/255.0f green:83.0f/255.0f blue:70.0f/255.0f alpha:1.0f]];
	[[UINavigationBar appearance] setBackgroundImage:[UIImage imageNamed:@"bar.png"] forBarMetrics:UIBarMetricsDefault];
	
	UINavigationController *navController = nil;

	if ([PFUser currentUser]) {
		// Skip straight to the main view.
		PAWWallViewController *wallViewController = [[PAWWallViewController alloc] initWithNibName:nil bundle:nil];
		navController = [[UINavigationController alloc] initWithRootViewController:wallViewController];
		navController.navigationBarHidden = NO;
		self.viewController = navController;
		self.window.rootViewController = self.viewController;
	} else {
		// Go to the welcome screen and have them log in or create an account.
		[self presentWelcomeViewController];
	}
	
	[PFAnalytics trackAppOpenedWithLaunchOptions:launchOptions];
	
    [self.window makeKeyAndVisible];
    return YES;
}


#pragma mark - PAWAppDelegate

- (void)presentWelcomeViewController {
	// Go to the welcome screen and have them log in or create an account.
	PAWWelcomeViewController *welcomeViewController = [[PAWWelcomeViewController alloc] initWithNibName:@"PAWWelcomeViewController" bundle:nil];
	welcomeViewController.title = @"Welcome to Anywall";
	
	UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:welcomeViewController];
	navController.navigationBarHidden = YES;

	self.viewController = navController;
	self.window.rootViewController = self.viewController;
}

@end
