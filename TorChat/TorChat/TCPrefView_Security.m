/*
 *  TCPrefView_Security.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
 *
 *  This file is part of TorChat.
 *
 *  TorChat is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  TorChat is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with TorChat.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "TCPrefView_Security.h"

#import "TCConfigSQLite.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPrefView_Security
*/
#pragma mark - TCPrefView_Security

@implementation TCPrefView_Security
{
	// Main view.
	IBOutlet NSButton *encryptCheckBox;
	IBOutlet NSButton *changePasswordButton;
	
	// Password window.
	IBOutlet NSWindow *passwordWindow;
	
	IBOutlet NSTextField *passwordTitle;
	IBOutlet NSTextField *verifyTitle;
	IBOutlet NSSecureTextField *passwordField;
	IBOutlet NSSecureTextField *verifyField;
	
	IBOutlet NSButton *okButton;
	
	// Vars.
	void (^_passwordHandler)(NSString * _Nullable password);
}



/*
** TCPrefView_Security - Instance
*/
#pragma mark - TCPrefView_Security - Instance

- (instancetype)init
{
	self = [super initWithNibName:@"PrefView_Security" bundle:nil];
	
	if (self)
	{
	}
	
	return self;
}



/*
** TCPrefView_Security - TCPrefView
*/
#pragma mark - TCPrefView_Security - TCPrefView

- (void)panelDidAppear
{
	[self updateConfig];
}



/*
** TCPrefView_Security - IBAction
*/
#pragma mark - TCPrefView_Security - IBAction

- (IBAction)doEncrypt:(id)sender
{
	__weak TCPrefView_Security	*weakSelf = self;
	id <TCConfigAppEncryptable>	config = self.config;
	
	// Activate encryption.
	if (encryptCheckBox.state == NSOnState)
	{
		if ([self.config isEncrypted] == YES)
		{
			NSBeep();
			return;
		}

		_passwordHandler = ^(NSString * _Nullable password) {

			if (!password)
			{
				[weakSelf updateConfig];
				return;
			}
			
			[config changePassword:password completionHandler:^(NSError *error) {
				dispatch_async(dispatch_get_main_queue(), ^{
					[weakSelf updateConfig];
				});
			}];
		};
		
		[self disableUI];
		[self.view.window beginSheet:passwordWindow completionHandler:nil];
	}
	
	// Deactivate encryption.
	else
	{
		if ([self.config isEncrypted] == NO)
		{
			NSBeep();
			return;
		}
		
		[self disableUI];

		[config changePassword:nil completionHandler:^(NSError *error) {
			[weakSelf updateConfig];
		}];
	}
}

- (IBAction)doChangePassword:(id)sender
{
	__weak TCPrefView_Security	*weakSelf = self;
	id <TCConfigAppEncryptable>	config = self.config;
	
	_passwordHandler = ^(NSString * _Nullable password) {
		
		if (!password)
		{
			[weakSelf updateConfig];
			return;
		}
		
		[config changePassword:password completionHandler:^(NSError *error) {
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf updateConfig];
			});
		}];
	};
	
	[self disableUI];
	[self.view.window beginSheet:passwordWindow completionHandler:nil];
}

- (IBAction)doCancel:(id)sender
{
	if (_passwordHandler)
		_passwordHandler(nil);
	
	[self.view.window endSheet:passwordWindow];
	
	passwordField.stringValue = @"";
	verifyField.stringValue = @"";
	
	[self checkValidity];
	
}

- (IBAction)doValidate:(id)sender
{
	if (_passwordHandler)
		_passwordHandler(passwordField.stringValue);
	
	[self.view.window endSheet:passwordWindow];

	passwordField.stringValue = @"";
	verifyField.stringValue = @"";
	
	[self checkValidity];
}



/*
** TCPrefView_Security - NSControlDelegate
*/
#pragma mark - TCPrefView_Security - NSControlDelegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self checkValidity];
}



/*
** TCPrefView_Security - Helpers
*/
#pragma mark - TCPrefView_Security - Helpers

- (void)disableUI
{
	encryptCheckBox.enabled = NO;
	changePasswordButton.enabled = NO;

}

- (void)updateConfig
{
	encryptCheckBox.enabled = YES;

	if ([self.config isEncrypted])
	{
		encryptCheckBox.state = NSOnState;
		changePasswordButton.enabled = YES;
	}
	else
	{
		encryptCheckBox.state = NSOffState;
		changePasswordButton.enabled = NO;
	}
}

- (void)checkValidity
{
	okButton.enabled = (passwordField.stringValue.length > 0 && [passwordField.stringValue isEqualToString:verifyField.stringValue]);
}

@end


NS_ASSUME_NONNULL_END
