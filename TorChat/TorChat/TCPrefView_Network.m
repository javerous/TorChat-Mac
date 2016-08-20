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


NS_ASSUME_NONNULL_BEGIN


/*
** TCPrefView_Network - Private
*/
#pragma mark - TCPrefView_Network - Private

@interface TCPrefView_Network ()
{
	NSString *_customIMIdentifier;
	NSNumber *_customIMPort;
	NSString *_customTorAddress;
	NSNumber *_customTorPort;
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

- (instancetype)init
{
	self = [super initWithNibName:@"PrefView_Network" bundle:nil];
	
	if (self)
	{
	}
	
	return self;
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
	
	_customIMIdentifier = self.config.selfIdentifier;
	_customIMPort = @(self.config.selfPort);
	_customTorAddress = self.config.torAddress;
	_customTorPort = @(self.config.torPort);
}

- (void)panelDidDisappear
{
	BOOL changes = NO;
	
	changes = changes || ((_modePopup.indexOfSelectedItem == 0 && self.config.mode != TCConfigModeBundled) || (_modePopup.indexOfSelectedItem == 1 && self.config.mode != TCConfigModeCustom));
	changes = changes || ([self.config.selfIdentifier isEqualToString:_imIdentifierField.stringValue] == NO);
	changes = changes || (self.config.selfPort != (uint16_t)_imPortField.intValue);
	changes = changes || ([self.config.torAddress isEqualToString:_torAddressField.stringValue] == NO);
	changes = changes || (self.config.torPort != (uint16_t)_torPortField.intValue);

	if (changes)
	{
		// Set config mode.
		if (_modePopup.indexOfSelectedItem == 0)
			self.config.mode = TCConfigModeBundled;
		else if (_modePopup.indexOfSelectedItem == 1)
			self.config.mode = TCConfigModeCustom;

		
		// Set config value.
		self.config.selfIdentifier = _imIdentifierField.stringValue;
		self.config.selfPort = (uint16_t)_imPortField.intValue;
		self.config.torAddress = _torAddressField.stringValue;
		self.config.torPort = (uint16_t)_torPortField.intValue;
		
		// Reload config.
		__weak TCPrefView_Network *weakSelf = self;
		
		[self reloadConfigurationWithCompletionHandler:^{
			dispatch_async(dispatch_get_main_queue(), ^{
				[weakSelf _reloadConfiguration];
			});
		}];
	}
}



/*
** TCPrefView_Network - IBAction
*/
#pragma mark - TCPrefView_Network - IBAction

- (IBAction)doChangeMode:(id)sender
{
	NSInteger index = _modePopup.indexOfSelectedItem;
	
	if (index == 0)
	{
		_customIMIdentifier = _imIdentifierField.stringValue;
		_customIMPort = @(_imPortField.intValue);
		_customTorAddress = _torAddressField.stringValue;
		_customTorPort = @(_torPortField.intValue);
		
		_imIdentifierField.stringValue = self.config.selfIdentifier;
		_imPortField. stringValue = @"60601";
		_torAddressField.stringValue =  @"localhost";
		_torPortField.stringValue = @"60600";
		
		_imIdentifierField.enabled = NO;
		_imPortField.enabled = NO;
		_torAddressField.enabled = NO;
		_torPortField.enabled = NO;
	}
	else if (index == 1)
	{		
		_imIdentifierField.stringValue = _customIMIdentifier;
		_imPortField. stringValue = [_customIMPort description];
		_torAddressField.stringValue =  _customTorAddress;
		_torPortField.stringValue = [_customTorPort description];
		
		_imIdentifierField.enabled = YES;
		_imPortField.enabled = YES;
		_torAddressField.enabled = YES;
		_torPortField.enabled = YES;
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

NS_ASSUME_NONNULL_END
