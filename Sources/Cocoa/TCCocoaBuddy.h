/*
 *  TCCocoaBuddy.h
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



#import <Cocoa/Cocoa.h>

#include "TCBuddy.h"

#import "TCChatController.h"



/*
** Forward
*/
#pragma mark -
#pragma mark Forward

@class TCCocoaBuddy;



/*
** Notifications
*/
#pragma mark -
#pragma mark Notifications

#define TCCocoaBuddyChangedStatusNotification		@"TCCocoaBuddyChangedStatus"
#define TCCocoaBuddyChangedAvatarNotification		@"TCCocoaBuddyChangedAvatar"
#define TCCocoaBuddyChangedNameNotification			@"TCCocoaBuddyChangedName"
#define TCCocoaBuddyChangedTextNotification			@"TCCocoaBuddyChangedText"
#define TCCocoaBuddyChangedAliasNotification		@"TCCocoaBuddyChangedAlias"

#define TCCocoaBuddyChangedPeerVersionNotification	@"TCCocoaBuddyChangedPeerVersion"
#define TCCocoaBuddyChangedPeerClientNotification	@"TCCocoaBuddyChangedPeerClient"



/*
** TCCocoaBuddy
*/
#pragma mark -
#pragma mark TCCocoaBuddy

// == Class ==
@interface TCCocoaBuddy : NSObject <TCChatControllerDelegate>
{
@private
    TCBuddy						*buddy;
	TCChatController			*chat;
	
	dispatch_queue_t			mainQueue;
	dispatch_queue_t			noticeQueue;
		
	tcbuddy_status				_status;
	NSImage						*_profileAvatar;
	NSString					*_profileName;
	NSString					*_profileText;
	
	NSString					*_peerVersion;
	NSString					*_peerClient;
	
	NSImage						*_cpavatar;
}

// -- Constructor --
- (id)initWithBuddy:(TCBuddy *)buddy;

// -- Status --
- (tcbuddy_status)status;
- (NSString *)alias;
- (NSString *)address;
- (NSString *)notes;

- (void)setAlias:(NSString *)alias;
- (void)setNotes:(NSString *)notes;

- (void)setControllerAvatar:(NSImage *)avatar;

// -- Profile --
- (NSImage *)profileAvatar;
- (NSString *)profileName;
- (NSString *)profileText;

// -- Peer --
- (NSString *)peerVersion;
- (NSString *)peerClient;


// -- Actions --
- (void)openChatWindow;

// -- Handling --
- (void)yieldCore;

// -- File --
- (void)cancelFileUpload:(NSString *)uuid;
- (void)cancelFileDownload:(NSString *)uuid;

- (void)sendFile:(NSString *)fileName;

@end
