/*
 *  TCPrefView_General.m
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

#import "TCPrefView_General.h"


/*
** TCPrefView_General - Private
*/
#pragma mark - TCPrefView_General - Private

@interface TCPrefView_General ()

// -- Properties --
@property (strong, nonatomic) IBOutlet NSTextField		*clientNameField;
@property (strong, nonatomic) IBOutlet NSTextField		*clientVersionField;

@end



/*
** TCPrefView_General
*/
#pragma mark - TCPrefView_General

@implementation TCPrefView_General


/*
** TCPrefView_General - Instance
*/
#pragma mark - TCPrefView_General - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_General" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}



/*
** TCPrefView_General - TCPrefView
*/
#pragma mark - TCPrefView_General - TCPrefView

- (void)loadConfig
{
	if (!self.config)
		return;
	
	// Load view.
	[self view];
		
	// Client info.
	[[_clientNameField cell] setPlaceholderString:[self.config clientName:TCConfigGetDefault]];
	[[_clientVersionField cell] setPlaceholderString:[self.config clientVersion:TCConfigGetDefault]];
	
	[_clientNameField setStringValue:[self.config clientName:TCConfigGetDefined]];
	[_clientVersionField setStringValue:[self.config clientVersion:TCConfigGetDefined]];
}

- (BOOL)saveConfig
{
	[self.config setClientName:[_clientNameField stringValue]];
	[self.config setClientVersion:[_clientVersionField stringValue]];
	
	return NO;
}

@end
