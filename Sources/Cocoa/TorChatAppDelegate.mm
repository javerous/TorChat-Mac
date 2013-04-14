/*
 *  TorChatAppDelegate.mm
 *
 *  Copyright 2011 Avérous Julien-Pierre
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

#import "TCCocoaBuddy.h"
#include <string>



/*
** TorChatAppDelegate
*/
#pragma mark -
#pragma mark TorChatAppDelegate

@implementation TorChatAppDelegate


/*
** TorChatAppDelegate - Properties
*/
#pragma mark -
#pragma mark TorChatAppDelegate - Properties

@synthesize window;



/*
** TorChatAppDelegate - Launch
*/
#pragma mark -
#pragma mark TorChatAppDelegate - Launch

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Observe buddy select change
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddySelectChanged:) name:TCBuddiesControllerSelectChanged object:nil];
	
	// Start TorChat
	[[TCMainController sharedController] start];
}



/*
** TorChatAppDelegate - App
*/
#pragma mark -
#pragma mark TorChatAppDelegate - App

- (IBAction)showPreferences:(id)sender
{
	[[TCPrefController sharedController] showWindow];
}



/*
** TorChatAppDelegate - Windows
*/
#pragma mark -
#pragma mark TorChatAppDelegate - Windows

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
#pragma mark -
#pragma mark TorChatAppDelegate - Buddies

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

- (IBAction)doEditProfile:(id)sender
{
	[[TCBuddiesController sharedController] doEditProfile:sender];
}

- (void)buddySelectChanged:(NSNotification *)notice
{
	NSDictionary	*ui = [notice userInfo];
	id				buddy = [ui objectForKey:TCBuddiesControllerBuddyKey];
		
	if ([buddy isKindOfClass:[TCCocoaBuddy class]])
	{
		[buddyShowMenu setTarget:self];
		[buddyShowMenu setAction:@selector(doBuddyShowInfo:)];
		
		[buddyDeleteMenu setTarget:self];
		[buddyDeleteMenu setAction:@selector(doBuddyRemove:)];
		
		[buddyChatMenu setTarget:self];
		[buddyChatMenu setAction:@selector(doBuddyChat:)];
		
		[buddyFileMenu setTarget:self];
		[buddyFileMenu setAction:@selector(doBuddySendFile:)];
	}
	else
	{
		[buddyShowMenu setTarget:nil];
		[buddyShowMenu setAction:NULL];
		
		[buddyDeleteMenu setTarget:nil];
		[buddyDeleteMenu setAction:NULL];
		
		[buddyChatMenu setTarget:nil];
		[buddyChatMenu setAction:NULL];
		
		[buddyFileMenu setTarget:nil];
		[buddyFileMenu setAction:NULL];
	}
}

@end
