//
//  PAWNewUserViewController.h
//  Anywall
//
//  Created by Christopher Bowns on 2/1/12.
//  Copyright (c) 2013 Parse. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface PAWNewUserViewController : UIViewController <UITextFieldDelegate>

@property (nonatomic, weak) IBOutlet UIBarButtonItem *doneButton;

@property (nonatomic, weak) IBOutlet UITextField *usernameField;
@property (nonatomic, weak) IBOutlet UITextField *passwordField;
@property (nonatomic, weak) IBOutlet UITextField *passwordAgainField;

- (IBAction)cancel:(id)sender;
- (IBAction)done:(id)sender;

@end
