//
//  PAWViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 1/30/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "PAWWelcomeViewController.h"

#import "PAWWallViewController.h"
#import "PAWLoginViewController.h"
#import "PAWNewUserViewController.h"

@implementation PAWWelcomeViewController

#pragma mark - Transition methods

- (IBAction)loginButtonSelected:(id)sender {
	PAWLoginViewController *loginViewController = [[PAWLoginViewController alloc] initWithNibName:nil bundle:nil];
	[self.navigationController presentViewController:loginViewController animated:YES completion:^{}];
}

- (IBAction)createButtonSelected:(id)sender {
	PAWNewUserViewController *newUserViewController = [[PAWNewUserViewController alloc] initWithNibName:nil bundle:nil];
	[self.navigationController presentViewController:newUserViewController animated:YES completion:^{}];
}

- (IBAction)gotoParse:(id)sender {
	UIApplication *ourApplication = [UIApplication sharedApplication];
    NSURL *url = [NSURL URLWithString:@"https://www.parse.com/"];
    [ourApplication openURL:url];
}

@end
