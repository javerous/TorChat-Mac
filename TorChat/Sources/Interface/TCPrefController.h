/*
 *  TCPrefController.h
 *
 *  Copyright 2013 Avérous Julien-Pierre
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

@property (strong, nonatomic) IBOutlet NSWindow	*mainWindow;

@property (strong, nonatomic) IBOutlet TCPrefView	*generalView;
@property (strong, nonatomic) IBOutlet TCPrefView	*networkView;
@property (strong, nonatomic) IBOutlet TCPrefView	*buddiesView;

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
@property (strong, nonatomic) IBOutlet NSTextField	*downloadField;

@property (strong, nonatomic) IBOutlet NSTextField	*clientNameField;
@property (strong, nonatomic) IBOutlet NSTextField	*clientVersionField;


// -- IBAction --
- (IBAction)doDownload:(id)sender;

@end




/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@interface TCPrefView_Network : TCPrefView

@property (strong, nonatomic) IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*imPortField;
@property (strong, nonatomic) IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*torPortField;

@end



/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@interface TCPrefView_Buddies : TCPrefView

@property (strong, nonatomic) IBOutlet NSTableView	*tableView;
@property (strong, nonatomic) IBOutlet NSButton	*removeButton;

@property (strong, nonatomic) IBOutlet NSWindow	*addBlockedWindow;
@property (strong, nonatomic) IBOutlet NSTextField	*addBlockedField;

- (IBAction)doAddBlockedUser:(id)sender;
- (IBAction)doRemoveBlockedUser:(id)sender;

- (IBAction)doAddBlockedCancel:(id)sender;
- (IBAction)doAddBlockedOK:(id)sender;
@end
