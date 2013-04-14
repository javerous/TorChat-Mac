/*
 *  TCBuddiesController.h
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

#import "TCCocoaBuddy.h"



/*
** Forward
*/
#pragma mark -
#pragma mark Forward

class TCConfig;
class TCController;



/*
** Notification
*/
#pragma mark -
#pragma mark Notification

#define TCBuddiesControllerSelectChanged	@"TCBuddiesControllerSelectChanged"
#define TCBuddiesControllerBuddyKey			@"buddy"


/*
** TCBuddiesController
*/
#pragma mark -
#pragma mark TCBuddiesController

@interface TCBuddiesController : NSObject <TCCocoaBuddyDelegate>
{
	IBOutlet NSWindow				*mainWindow;
	IBOutlet NSProgressIndicator	*indicator;
	IBOutlet NSTableView			*tableView;
	IBOutlet NSTextField			*imAddress;
	IBOutlet NSPopUpButton			*imStatus;
	IBOutlet NSButton				*imRemove;
	
	
	IBOutlet NSWindow				*addWindow;
	IBOutlet NSTextField			*addNameField;
	IBOutlet NSTextField			*addAddressField;
	IBOutlet NSTextView				*addCommentField;
	
@private
    TCConfig						*config;
	TCController					*control;
	
	dispatch_queue_t				mainQueue;
	
	NSMutableArray					*buddies;
	
	BOOL							running;
}

// -- Singleton --
+ (TCBuddiesController *)sharedController;

// -- IBAction --
- (IBAction)doStatus:(id)sender;
- (IBAction)doRemove:(id)sender;
- (IBAction)doAdd:(id)sender;
- (IBAction)doChat:(id)sender;
- (IBAction)doSendFile:(id)sender;

- (IBAction)doAddOk:(id)sender;
- (IBAction)doAddCancel:(id)sender;

- (IBAction)showWindow:(id)sender;

// -- Tools --
- (TCCocoaBuddy *)selectedBuddy;

// -- Running --
- (void)stop;
- (void)startWithConfig:(TCConfig *)config;

@end
