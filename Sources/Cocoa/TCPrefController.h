/*
 *  TCPrefController.h
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#import <Cocoa/Cocoa.h>


/*
** TCPrefController
*/
#pragma mark -
#pragma mark TCPrefController

@interface TCPrefController : NSObject
{
	IBOutlet NSWindow		*mainWindow;
	
	IBOutlet NSTextField	*imAddressField;
	IBOutlet NSTextField	*imPortField;
	IBOutlet NSTextField	*downloadField;
	IBOutlet NSTextField	*torAddressField;
	IBOutlet NSTextField	*torPortField;
	
@private
}

// -- Singleton --
+ (TCPrefController *)sharedController;

// -- Tools --
- (void)showWindow;

// -- IBAction --
- (IBAction)doDownload:(id)sender;

@end
