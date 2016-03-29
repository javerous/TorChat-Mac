/*
 *  TCPrefView_Network.m
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

#import "TCPrefView_Network.h"


/*
** TCPrefView_Network - Private
*/
#pragma mark - TCPrefView_Network - Private

@interface TCPrefView_Network ()
{
	BOOL changes;
}


@property (strong, nonatomic) IBOutlet NSPopUpButton *modePopup;

@property (strong, nonatomic) IBOutlet NSTextField	*imIdentifierField;
@property (strong, nonatomic) IBOutlet NSTextField	*imPortField;
@property (strong, nonatomic) IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*torPortField;

@end



/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@implementation TCPrefView_Network


/*
** TCPrefView_Network - Instance
*/
#pragma mark - TCPrefView_Network - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_Network" bundle:nil];
	
	if (self)
	{
	}
	
	return self;
}



/*
** TCPrefView_Network - TextField Delegate
*/
#pragma mark - TCPrefView_Network - TextField Delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	changes = YES;
}



/*
** TCPrefView_Network - TCPrefView
*/
#pragma mark - TCPrefView_Network - TCPrefView

- (void)panelDidAppear
{
	// Load view.
	[self view];
	
	// Load configuration.
	[self _reloadConfiguration];
}

- (void)panelDidDisappear
{
	if (changes && self.config.mode == TCConfigModeCustom)
	{
		// Set config value.
		self.config.selfIdentifier = _imIdentifierField.stringValue;
		self.config.selfPort = (uint16_t)_imPortField.intValue;
		self.config.torAddress = _torAddressField.stringValue;
		self.config.torPort = (uint16_t)_torPortField.intValue;
		
		// Reload config.
		[self reloadConfigurationWithCompletionHandler:nil];
	}
}



/*
** TCPrefView_Network - IBAction
*/
#pragma mark - TCPrefView_Network - IBAction

- (IBAction)doChangeMode:(id)sender
{
	NSInteger index = _modePopup.indexOfSelectedItem;
	
	if (index == 0 && self.config.mode == TCConfigModeCustom) // bundled.
	{
		self.config.mode = TCConfigModeBundled;
		
		self.config.selfPort = 60601;
		self.config.torAddress = @"localhost";
		self.config.torPort = 60600;
		
		[self reloadConfigurationWithCompletionHandler:^{
			[self _reloadConfiguration];
		}];
		
		[self _reloadConfiguration];
	}
	else if (index == 1 && self.config.mode == TCConfigModeBundled) // custom.
	{
		self.config.mode = TCConfigModeCustom;
		
		[self reloadConfigurationWithCompletionHandler:^{
			[self _reloadConfiguration];
		}];
		
		[self _reloadConfiguration];
	}
}



/*
** TCPrefView_Network - Helper
*/
#pragma mark - TCPrefView_Network - Helper

- (void)_reloadConfiguration
{
	// > main queue <
	
	TCConfigMode mode = [self.config mode];
	
	// Set mode.
	if (mode == TCConfigModeBundled)
	{
		[_modePopup selectItemAtIndex:0];
		
		_imIdentifierField.enabled = NO;
		_imPortField.enabled = NO;
		_torAddressField.enabled = NO;
		_torPortField.enabled = NO;
	}
	else if (mode == TCConfigModeCustom)
	{
		[_modePopup selectItemAtIndex:1];
		
		_imIdentifierField.enabled = YES;
		_imPortField.enabled = YES;
		_torAddressField.enabled = YES;
		_torPortField.enabled = YES;
	}
	
	// Set value field.
	_imIdentifierField.stringValue = self.config.selfIdentifier;
	_imPortField. stringValue = [@(self.config.selfPort) description];
	_torAddressField.stringValue = self.config.torAddress;
	_torPortField.stringValue = [@(self.config.torPort) description];
}

@end
