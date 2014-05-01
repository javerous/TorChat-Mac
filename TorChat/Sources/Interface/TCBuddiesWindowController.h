/*
 *   TCBuddiesWindowController.h
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



#import <Cocoa/Cocoa.h>

#import "TCConfig.h"


/*
** Forward
*/
#pragma mark - Forward

@class TCCoreManager;
@class TCDropButton;
@class TCBuddy;



/*
** Notification
*/
#pragma mark - Notification

#define  TCBuddiesWindowControllerSelectChanged		@"TCBuddiesWindowControllerSelectChanged"
#define  TCBuddiesWindowControllerBuddyKey			@"buddy"

#define  TCBuddiesWindowControllerAvatarChanged		@"TCBuddiesWindowControllerAvatarChanged"
#define  TCBuddiesWindowControllerNameChanged		@"TCBuddiesWindowControllerNameChanged"
#define  TCBuddiesWindowControllerTextChanged		@"TCBuddiesWindowControllerTextChanged"

#define  TCBuddiesWindowControllerRemovedBuddy		@"TCBuddiesWindowControllerRemovedBuddy"


#define TCCocoaBuddyChangedStatusNotification		@"TCCocoaBuddyChangedStatus"
#define TCCocoaBuddyChangedAvatarNotification		@"TCCocoaBuddyChangedAvatar"
#define TCCocoaBuddyChangedNameNotification			@"TCCocoaBuddyChangedName"
#define TCCocoaBuddyChangedTextNotification			@"TCCocoaBuddyChangedText"
#define TCCocoaBuddyChangedAliasNotification		@"TCCocoaBuddyChangedAlias"

#define TCCocoaBuddyChangedPeerVersionNotification	@"TCCocoaBuddyChangedPeerVersion"
#define TCCocoaBuddyChangedPeerClientNotification	@"TCCocoaBuddyChangedPeerClient"

#define	TCCocoaBuddyChangedBlockedNotification		@"TCCocoaBuddyChangedBlocked"




/*
**  TCBuddiesWindowController
*/
#pragma mark -  TCBuddiesWindowController

@interface TCBuddiesWindowController : NSWindowController

// -- Singleton --
+ (TCBuddiesWindowController *)sharedController;

// -- IBAction --
- (IBAction)doRemove:(id)sender;
- (IBAction)doAdd:(id)sender;
- (IBAction)doChat:(id)sender;
- (IBAction)doSendFile:(id)sender;
- (IBAction)doToggleBlock:(id)sender;
- (IBAction)doEditProfile:(id)sender;

// -- Tools --
- (void)buddyStatusChanged;
- (void)startChatForBuddy:(TCBuddy *)buddy select:(BOOL)select;

- (TCBuddy *)selectedBuddy;

// -- Running --
- (void)stop;
- (void)startWithConfiguration:(id <TCConfig>)configuration;

// -- Blocked Buddies --
- (BOOL)addBlockedBuddy:(NSString *)address;
- (BOOL)removeBlockedBuddy:(NSString *)address;

@end
