/*
 *  TorChatAppDelegate.m
 *
 *  Copyright 2014 Avérous Julien-Pierre
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
#import "TCBuddiesWindowController.h"
#import "TCFilesWindowController.h"
#import "TCBuddyInfoWindowController.h"
#import "TCLogsWindowController.h"
#import "TCPreferencesWindowController.h"
#import "TCChatWindowController.h"

#import "TCBuddy.h"




/*
** TorChatAppDelegate - Private
*/
#pragma mark - TorChatAppDelegate - Private

@interface TorChatAppDelegate ()

@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyShowMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyDeleteMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyChatMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyBlockMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyFileMenu;


- (IBAction)showPreferences:(id)sender;

- (IBAction)showTransfers:(id)sender;
- (IBAction)showBuddies:(id)sender;
- (IBAction)showLogs:(id)sender;
- (IBAction)showMessages:(id)sender;

- (IBAction)doBuddyShowInfo:(id)sender;
- (IBAction)doBuddyAdd:(id)sender;
- (IBAction)doBuddyRemove:(id)sender;
- (IBAction)doBuddyChat:(id)sender;
- (IBAction)doBuddyToggleBlocked:(id)sender;
- (IBAction)doBuddySendFile:(id)sender;

- (IBAction)doEditProfile:(id)sender;

@end



/*
** TorChatAppDelegate
*/
#pragma mark - TorChatAppDelegate

@implementation TorChatAppDelegate


/*
** TorChatAppDelegate - Launch
*/
#pragma mark - TorChatAppDelegate - Launch

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	/*
	[[TCFilesWindowController sharedController] startFileTransfert:@"8888888" withFilePath:@"/" buddyAddress:@"xxxxx" buddyName:@"Truc" transfertWay:tcfile_download fileSize:1024];
	[[TCFilesWindowController sharedController] startFileTransfert:@"8888888" withFilePath:@"/" buddyAddress:@"xxxxx" buddyName:@"Truc" transfertWay:tcfile_upload fileSize:1024];

	return;
	*/
	
	/*
	[[TCChatWindowController sharedController] startChatWithIdentifier:@"xx" name:@"Tutu" localAvatar:nil remoteAvatar:nil context:nil delegate:nil];
	[[TCChatWindowController sharedController] startChatWithIdentifier:@"yy" name:@"Toto" localAvatar:nil remoteAvatar:nil context:nil delegate:nil];

	[[TCChatWindowController sharedController] receiveMessage:@"Ceci est un test" forIdentifier:@"yy"];
	[[TCChatWindowController sharedController] receiveMessage:@"Ceci est un test" forIdentifier:@"yy"];

	return;
	*/
	
	// Observe buddy select change
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddySelectChanged:) name:TCBuddiesWindowControllerSelectChanged object:nil];

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
	[[TCPreferencesWindowController sharedController] showWindow:nil];
}



/*
** TorChatAppDelegate - Windows
*/
#pragma mark - TorChatAppDelegate - Windows

- (IBAction)showTransfers:(id)sender
{
	[[TCFilesWindowController sharedController] showWindow:sender];
}

- (IBAction)showBuddies:(id)sender
{
	[[TCBuddiesWindowController sharedController] showWindow:sender];
}

- (IBAction)showLogs:(id)sender
{
	[[TCLogsWindowController sharedController] showWindow:sender];
}

- (IBAction)showMessages:(id)sender
{
	[[TCChatWindowController sharedController] showWindow:sender];
}



/*
** TorChatAppDelegate - Buddies
*/
#pragma mark - TorChatAppDelegate - Buddies

- (IBAction)doBuddyShowInfo:(id)sender
{
	[TCBuddyInfoWindowController showInfo];
}

- (IBAction)doBuddyAdd:(id)sender
{
	[[TCBuddiesWindowController sharedController] doAdd:sender];
}

- (IBAction)doBuddyRemove:(id)sender
{
	[[TCBuddiesWindowController sharedController] doRemove:sender];
}

- (IBAction)doBuddyChat:(id)sender
{
	[[TCBuddiesWindowController sharedController] doChat:sender];
}

- (IBAction)doBuddySendFile:(id)sender
{
	[[TCBuddiesWindowController sharedController] doSendFile:sender];
}

- (IBAction)doBuddyToggleBlocked:(id)sender
{
	[[TCBuddiesWindowController sharedController] doToggleBlock:sender];
}

- (IBAction)doEditProfile:(id)sender
{
	[[TCBuddiesWindowController sharedController] doEditProfile:sender];
}

- (void)buddySelectChanged:(NSNotification *)notice
{
	NSDictionary	*ui = [notice userInfo];
	id				buddy = [ui objectForKey: TCBuddiesWindowControllerBuddyKey];
		
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
	NSString		*selected = [[[TCBuddiesWindowController sharedController] selectedBuddy] address];
	
	if ([buddy isEqualToString:selected])
	{
		if ([blocked boolValue])
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_unblock_buddy", @"")];
		else
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_block_buddy", @"")];
	}
}

@end
