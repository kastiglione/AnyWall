//
//  PAWWallPostCreateViewController.m
//  Anywall
//
//  Created by Christopher Bowns on 1/31/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <ReactiveCocoa/ReactiveCocoa.h>
#import <ReactiveCocoa/EXTScope.h>

#import "PAWWallPostCreateViewController.h"

#import "PAWAppDelegate.h"
#import <Parse/Parse.h>

@interface PAWWallPostCreateViewController ()
@property (nonatomic, strong, readwrite) PFObject *createdPost;
@end

@implementation PAWWallPostCreateViewController

#pragma mark - View lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];

	// Do any additional setup after loading the view from its nib.
	
	self.characterCount = [[UILabel alloc] initWithFrame:CGRectMake(0.0f, 0.0f, 154.0f, 21.0f)];
	self.characterCount.backgroundColor = [UIColor clearColor];
	self.characterCount.textColor = [UIColor whiteColor];
	self.characterCount.shadowColor = [UIColor colorWithWhite:0.0f alpha:0.7f];
	self.characterCount.shadowOffset = CGSizeMake(0.0f, -1.0f);
	self.characterCount.text = @"0/140";

	[self.textView setInputAccessoryView:self.characterCount];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(textInputChanged:) name:UITextViewTextDidChangeNotification object:self.textView];
	[self updateCharacterCount:self.textView];
	[self checkCharacterCount:self.textView];

	// Show the keyboard/accept input.
	[self.textView becomeFirstResponder];
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self name:UITextViewTextDidChangeNotification object:self.textView];
}

#pragma mark UINavigationBar-based actions

- (IBAction)cancelPost:(id)sender {
	[self dismissModalViewControllerAnimated:YES];
}

- (IBAction)postPost:(id)sender {
	// Resign first responder to dismiss the keyboard and capture in-flight autocorrect suggestions
	[self.textView resignFirstResponder];

	// Capture current text field contents:
	[self updateCharacterCount:self.textView];
	BOOL isAcceptableAfterAutocorrect = [self checkCharacterCount:self.textView];

	if (!isAcceptableAfterAutocorrect) {
		[self.textView becomeFirstResponder];
		return;
	}

	// Data prep:
	CLLocationCoordinate2D currentCoordinate = self.currentLocation.coordinate;
	PFGeoPoint *currentPoint = [PFGeoPoint geoPointWithLatitude:currentCoordinate.latitude longitude:currentCoordinate.longitude];
	PFUser *user = [PFUser currentUser];

	// Stitch together a postObject and send this async to Parse
	PFObject *postObject = [PFObject objectWithClassName:kPAWParsePostsClassKey];
	[postObject setObject:self.textView.text forKey:kPAWParseTextKey];
	[postObject setObject:user forKey:kPAWParseUserKey];
	[postObject setObject:currentPoint forKey:kPAWParseLocationKey];
	// Use PFACL to restrict future modifications to this object.
	PFACL *readOnlyACL = [PFACL ACL];
	[readOnlyACL setPublicReadAccess:YES];
	[readOnlyACL setPublicWriteAccess:NO];
	[postObject setACL:readOnlyACL];

	@weakify(postObject);
	[postObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
		if (error) {
			NSLog(@"Couldn't save!");
			NSLog(@"%@", error);
			UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:[[error userInfo] objectForKey:@"error"] message:nil delegate:self cancelButtonTitle:nil otherButtonTitles:@"Ok", nil];
			[alertView show];
			return;
		}
		if (succeeded) {
			NSLog(@"Successfully saved!");
			NSLog(@"%@", postObject);
			@strongify(postObject);
			self.createdPost = postObject;
		} else {
			NSLog(@"Failed to save.");
		}
	}];

	[self dismissModalViewControllerAnimated:YES];
}

#pragma mark UITextView notification methods

- (void)textInputChanged:(NSNotification *)note {
	// Listen to the current text field and count characters.
	UITextView *localTextView = [note object];
	[self updateCharacterCount:localTextView];
	[self checkCharacterCount:localTextView];
}

#pragma mark Private helper methods

- (void)updateCharacterCount:(UITextView *)textView {
	NSUInteger count = textView.text.length;
	self.characterCount.text = [NSString stringWithFormat:@"%i/140", count];
	if (count > kPAWWallPostMaximumCharacterCount || count == 0) {
		self.characterCount.font = [UIFont boldSystemFontOfSize:self.characterCount.font.pointSize];
	} else {
		self.characterCount.font = [UIFont systemFontOfSize:self.characterCount.font.pointSize];
	}
}

- (BOOL)checkCharacterCount:(UITextView *)textView {
	NSUInteger count = textView.text.length;
	if (count > kPAWWallPostMaximumCharacterCount || count == 0) {
		self.postButton.enabled = NO;
		return NO;
	} else {
		self.postButton.enabled = YES;
		return YES;
	}
}

@end
