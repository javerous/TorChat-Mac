/*
 *  TorChatAppDelegate.h
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



/*
** TorChatAppDelegate
*/
#pragma mark - TorChatAppDelegate

@interface TorChatAppDelegate : NSObject <NSApplicationDelegate>
{
	NSWindow				*window;
	
	IBOutlet NSMenuItem		*buddyShowMenu;
	IBOutlet NSMenuItem		*buddyDeleteMenu;
	IBOutlet NSMenuItem		*buddyChatMenu;
	IBOutlet NSMenuItem		*buddyBlockMenu;
	IBOutlet NSMenuItem		*buddyFileMenu;
}

@property (assign) IBOutlet NSWindow *window;

- (IBAction)showPreferences:(id)sender;

- (IBAction)showTransfers:(id)sender;
- (IBAction)showBuddies:(id)sender;
- (IBAction)showLogs:(id)sender;

- (IBAction)doBuddyShowInfo:(id)sender;
- (IBAction)doBuddyAdd:(id)sender;
- (IBAction)doBuddyRemove:(id)sender;
- (IBAction)doBuddyChat:(id)sender;
- (IBAction)doBuddyToggleBlocked:(id)sender;
- (IBAction)doBuddySendFile:(id)sender;

- (IBAction)doEditProfile:(id)sender;

@end

