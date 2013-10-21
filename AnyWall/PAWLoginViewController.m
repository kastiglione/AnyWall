//
//  PAWLoginViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 2/1/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import "PAWLoginViewController.h"

#import "PAWAppDelegate.h"
#import <Parse/Parse.h>
#import "PAWActivityView.h"
#import "PAWWallViewController.h"

@implementation PAWLoginViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputChanged:) name:UITextFieldTextDidChangeNotification object:self.usernameField];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputChanged:) name:UITextFieldTextDidChangeNotification object:self.passwordField];

	self.doneButton.enabled = NO;
}

- (void)viewWillAppear:(BOOL)animated {
	[self.usernameField becomeFirstResponder];
	[super viewWillAppear:animated];
}

-  (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self.usernameField];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self.passwordField];
}

#pragma mark - IBActions

- (IBAction)cancel:(id)sender {
	[self.presentingViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction)done:(id)sender {
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];

	[self processFieldEntries];
}

#pragma mark - UITextField text field change notifications and helper methods

- (BOOL)shouldEnableDoneButton {
	BOOL enableDoneButton = NO;
	if (self.usernameField.text != nil &&
		self.usernameField.text.length > 0 &&
		self.passwordField.text != nil &&
		self.passwordField.text.length > 0) {
		enableDoneButton = YES;
	}
	return enableDoneButton;
}

- (void)textInputChanged:(NSNotification *)note {
	self.doneButton.enabled = [self shouldEnableDoneButton];
}

#pragma mark - UITextFieldDelegate methods

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	if (textField == self.usernameField) {
		[self.passwordField becomeFirstResponder];
	}
	if (textField == self.passwordField) {
		[self.passwordField resignFirstResponder];
		[self processFieldEntries];
	}

	return YES;
}

#pragma mark - Private methods:

#pragma mark Field validation

- (void)processFieldEntries {
	// Get the username text, store it in the app delegate for now
	NSString *username = self.usernameField.text;
	NSString *password = self.passwordField.text;
	NSString *noUsernameText = @"username";
	NSString *noPasswordText = @"password";
	NSString *errorText = @"No ";
	NSString *errorTextJoin = @" or ";
	NSString *errorTextEnding = @" entered";
	BOOL textError = NO;

	// Messaging nil will return 0, so these checks implicitly check for nil text.
	if (username.length == 0 || password.length == 0) {
		textError = YES;

		// Set up the keyboard for the first field missing input:
		if (password.length == 0) {
			[self.passwordField becomeFirstResponder];
		}
		if (username.length == 0) {
			[self.usernameField becomeFirstResponder];
		}
	}

	if (username.length == 0) {
		textError = YES;
		errorText = [errorText stringByAppendingString:noUsernameText];
	}

	if (password.length == 0) {
		textError = YES;
		if (username.length == 0) {
			errorText = [errorText stringByAppendingString:errorTextJoin];
		}
		errorText = [errorText stringByAppendingString:noPasswordText];
	}

	if (textError) {
		errorText = [errorText stringByAppendingString:errorTextEnding];
		UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:errorText message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
		[alertView show];
		return;
	}

	// Everything looks good; try to log in.
	// Disable the done button for now.
	self.doneButton.enabled = NO;

	PAWActivityView *activityView = [[PAWActivityView alloc] initWithFrame:CGRectMake(0.f, 0.f, self.view.frame.size.width, self.view.frame.size.height)];
	activityView.status = @"Logging in";
	[self.view addSubview:activityView];

	[PFUser logInWithUsernameInBackground:username password:password block:^(PFUser *user, NSError *error) {
		// Tear down the activity view in all cases.
		[activityView.activityIndicator stopAnimating];
		[activityView removeFromSuperview];

		if (user) {
			PAWWallViewController *wallViewController = [[PAWWallViewController alloc] initWithNibName:nil bundle:nil];
			[(UINavigationController *)self.presentingViewController pushViewController:wallViewController animated:NO];
			[self.presentingViewController dismissModalViewControllerAnimated:YES];
		} else {
			// Didn't get a user.
			NSLog(@"%s didn't get a user!", __PRETTY_FUNCTION__);

			// Re-enable the done button if we're tossing them back into the form.
			self.doneButton.enabled = [self shouldEnableDoneButton];
			UIAlertView *alertView = nil;

			if (error == nil) {
				// the username or password is probably wrong.
				alertView = [[UIAlertView alloc] initWithTitle:@"Couldn’t log in:\nThe username or password were wrong." message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
			} else {
				// Something else went horribly wrong:
				alertView = [[UIAlertView alloc] initWithTitle:[[error userInfo] objectForKey:@"error"] message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
			}
			[alertView show];
			// Bring the keyboard back up, because they'll probably need to change something.
			[self.usernameField becomeFirstResponder];
		}
	}];
}

@end
