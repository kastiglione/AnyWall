//
//  PAWWallPostCreateViewController.h
//  Anywall
//
//  Created by Christopher Bowns on 1/31/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PAWWallPostCreateViewController : UIViewController

@property (nonatomic, strong) IBOutlet UITextView *textView;
@property (nonatomic, strong) IBOutlet UILabel *characterCount;
@property (nonatomic, strong) IBOutlet UIBarButtonItem *postButton;

@property (nonatomic, strong) CLLocation *currentLocation;

- (IBAction)cancelPost:(id)sender;
- (IBAction)postPost:(id)sender;

@end
