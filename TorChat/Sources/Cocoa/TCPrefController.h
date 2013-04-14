/*
 *  TCPrefController.h
 *
 *  Copyright 2012 Avérous Julien-Pierre
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
** Forward
*/
#pragma mark - Forward

@class TCPrefView;



/*
** TCPrefController
*/
#pragma mark - TCPrefController

@interface TCPrefController : NSObject

@property (assign) IBOutlet NSWindow	*mainWindow;

@property (assign) IBOutlet TCPrefView	*generalView;
@property (assign) IBOutlet TCPrefView	*networkView;
@property (assign) IBOutlet TCPrefView	*buddiesView;

// -- Singleton --
+ (TCPrefController *)sharedController;

// -- Tools --
- (void)showWindow;

// -- IBAction --
- (IBAction)doToolbarItem:(id)sender;

@end



/*
** TCPrefView
*/
#pragma mark - TCPrefView

@interface TCPrefView : NSView

@end



/*
** TCPrefView_General
*/
#pragma mark - TCPrefView_General

@interface TCPrefView_General : TCPrefView

// -- Properties --
@property (assign) IBOutlet NSTextField	*downloadField;

@property (assign) IBOutlet NSTextField	*clientNameField;
@property (assign) IBOutlet NSTextField	*clientVersionField;


// -- IBAction --
- (IBAction)doDownload:(id)sender;

@end




/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@interface TCPrefView_Network : TCPrefView

@property (assign) IBOutlet NSTextField	*imAddressField;
@property (assign) IBOutlet NSTextField	*imPortField;
@property (assign) IBOutlet NSTextField	*torAddressField;
@property (assign) IBOutlet NSTextField	*torPortField;

@end



/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@interface TCPrefView_Buddies : TCPrefView

@property (assign) IBOutlet NSTableView	*tableView;
@property (assign) IBOutlet NSButton	*removeButton;

@property (assign) IBOutlet NSWindow	*addBlockedWindow;
@property (assign) IBOutlet NSTextField	*addBlockedField;

- (IBAction)doAddBlockedUser:(id)sender;
- (IBAction)doRemoveBlockedUser:(id)sender;

- (IBAction)doAddBlockedCancel:(id)sender;
- (IBAction)doAddBlockedOK:(id)sender;
@end
