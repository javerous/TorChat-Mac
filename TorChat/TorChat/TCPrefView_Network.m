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

@property (strong, nonatomic) IBOutlet NSTextField	*imAddressField;
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

- (void)loadConfig
{
	TCConfigMode mode;
	
	if (!self.config)
		return;
	
	// Load view.
	[self view];
	
	mode = [self.config mode];
	
	// Set mode
	if (mode == TCConfigModeBasic)
	{
		[_imAddressField setEnabled:NO];
		[_imPortField setEnabled:NO];
		[_torAddressField setEnabled:NO];
		[_torPortField setEnabled:NO];
	}
	else if (mode == TCConfigModeAdvanced)
	{
		[_imAddressField setEnabled:YES];
		[_imPortField setEnabled:YES];
		[_torAddressField setEnabled:YES];
		[_torPortField setEnabled:YES];
	}
	
	// Set value field
	[_imAddressField setStringValue:[self.config selfAddress]];
	[_imPortField setStringValue:[@([self.config clientPort]) description]];
	[_torAddressField setStringValue:[self.config torAddress]];
	[_torPortField setStringValue:[@([self.config torPort]) description]];
}

- (BOOL)saveConfig
{
	if (!self.config)
		return NO;
	
	if ([self.config mode] == TCConfigModeAdvanced)
	{
		// Set config value.
		[self.config setSelfAddress:[_imAddressField stringValue]];
		[self.config setClientPort:(uint16_t)[[_imPortField stringValue] intValue]];
		[self.config setTorAddress:[_torAddressField stringValue]];
		[self.config setTorPort:(uint16_t)[[_torPortField stringValue] intValue]];
		
		// Reload config.
		if (changes)
		{
			changes = NO;
			return YES;
		}
	}
	
	return NO;
}

@end
