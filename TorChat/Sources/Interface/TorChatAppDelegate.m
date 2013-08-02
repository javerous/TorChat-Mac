/*
 *  TorChatAppDelegate.mm
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



#import "TorChatAppDelegate.h"

#import "TCMainController.h"
#import "TCBuddiesController.h"
#import "TCFilesController.h"
#import "TCBuddyInfoController.h"
#import "TCLogsController.h"
#import "TCPrefController.h"

#import "TCBuddy.h"



/*
** TorChatAppDelegate
*/
#pragma mark - TorChatAppDelegate

@implementation TorChatAppDelegate


/*
** TorChatAppDelegate - Properties
*/
#pragma mark - TorChatAppDelegate - Properties

@synthesize window;



/*
** TorChatAppDelegate - Launch
*/
#pragma mark - TorChatAppDelegate - Launch

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Observe buddy select change
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddySelectChanged:) name:TCBuddiesControllerSelectChanged object:nil];

	// Observe buddy blocked change
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyBlockedChanged:) name:TCCocoaBuddyChangedBlockedNotification object:nil];
	
	// Start TorChat
	[[TCMainController sharedController] start];
}



/*
** TorChatAppDelegate - App
*/
#pragma mark - TorChatAppDelegate - App

- (IBAction)showPreferences:(id)sender
{
	[[TCPrefController sharedController] showWindow];
}



/*
** TorChatAppDelegate - Windows
*/
#pragma mark - TorChatAppDelegate - Windows

- (IBAction)showTransfers:(id)sender
{
	[[TCFilesController sharedController] showWindow:sender];
}

- (IBAction)showBuddies:(id)sender
{
	[[TCBuddiesController sharedController] showWindow:sender];
}

- (IBAction)showLogs:(id)sender
{
	[[TCLogsController sharedController] showWindow:sender];
}



/*
** TorChatAppDelegate - Buddies
*/
#pragma mark - TorChatAppDelegate - Buddies

- (IBAction)doBuddyShowInfo:(id)sender
{
	[TCBuddyInfoController showInfo];
}

- (IBAction)doBuddyAdd:(id)sender
{
	[[TCBuddiesController sharedController] doAdd:sender];
}

- (IBAction)doBuddyRemove:(id)sender
{
	[[TCBuddiesController sharedController] doRemove:sender];
}

- (IBAction)doBuddyChat:(id)sender
{
	[[TCBuddiesController sharedController] doChat:sender];
}

- (IBAction)doBuddySendFile:(id)sender
{
	[[TCBuddiesController sharedController] doSendFile:sender];
}

- (IBAction)doBuddyToggleBlocked:(id)sender
{
	[[TCBuddiesController sharedController] doToggleBlock:sender];
}

- (IBAction)doEditProfile:(id)sender
{
	[[TCBuddiesController sharedController] doEditProfile:sender];
}

- (void)buddySelectChanged:(NSNotification *)notice
{
	NSDictionary	*ui = [notice userInfo];
	id				buddy = [ui objectForKey:TCBuddiesControllerBuddyKey];
		
	if ([buddy isKindOfClass:[TCBuddy class]])
	{
		[_buddyShowMenu setTarget:self];
		[_buddyShowMenu setAction:@selector(doBuddyShowInfo:)];
		
		[_buddyDeleteMenu setTarget:self];
		[_buddyDeleteMenu setAction:@selector(doBuddyRemove:)];
		
		[_buddyChatMenu setTarget:self];
		[_buddyChatMenu setAction:@selector(doBuddyChat:)];
		
		[_buddyBlockMenu setTarget:self];
		[_buddyBlockMenu setAction:@selector(doBuddyToggleBlocked:)];
		
		if ([buddy blocked])
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_unblock_buddy", @"")];
		else
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_block_buddy", @"")];
		
		[_buddyFileMenu setTarget:self];
		[_buddyFileMenu setAction:@selector(doBuddySendFile:)];
	}
	else
	{
		[_buddyShowMenu setTarget:nil];
		[_buddyShowMenu setAction:NULL];
		
		[_buddyDeleteMenu setTarget:nil];
		[_buddyDeleteMenu setAction:NULL];
		
		[_buddyChatMenu setTarget:nil];
		[_buddyChatMenu setAction:NULL];
		
		[_buddyBlockMenu setTarget:nil];
		[_buddyBlockMenu setAction:NULL];
		[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_block_buddy", @"")];

		[_buddyFileMenu setTarget:nil];
		[_buddyFileMenu setAction:NULL];
	}
}

- (void)buddyBlockedChanged:(NSNotification *)notice
{
	NSDictionary	*ui = [notice userInfo];
	NSNumber		*blocked = [ui objectForKey:@"blocked"];
	NSString		*buddy = [(TCBuddy *)[notice object] address];
	NSString		*selected = [[[TCBuddiesController sharedController] selectedBuddy] address];
	
	if ([buddy isEqualToString:selected])
	{
		if ([blocked boolValue])
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_unblock_buddy", @"")];
		else
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_block_buddy", @"")];
	}
}

@end
