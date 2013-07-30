/*
 *  TCCocoaBuddy.h
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

#import "TCBuddy.h"

#import "TCChatController.h"



/*
** Forward
*/
#pragma mark - Forward

@class TCCocoaBuddy;



/*
** Notifications
*/
#pragma mark - Notifications

#define TCCocoaBuddyChangedStatusNotification		@"TCCocoaBuddyChangedStatus"
#define TCCocoaBuddyChangedAvatarNotification		@"TCCocoaBuddyChangedAvatar"
#define TCCocoaBuddyChangedNameNotification			@"TCCocoaBuddyChangedName"
#define TCCocoaBuddyChangedTextNotification			@"TCCocoaBuddyChangedText"
#define TCCocoaBuddyChangedAliasNotification		@"TCCocoaBuddyChangedAlias"

#define TCCocoaBuddyChangedPeerVersionNotification	@"TCCocoaBuddyChangedPeerVersion"
#define TCCocoaBuddyChangedPeerClientNotification	@"TCCocoaBuddyChangedPeerClient"

#define	TCCocoaBuddyChangedBlockedNotification		@"TCCocoaBuddyChangedBlocked"



/*
** TCCocoaBuddy
*/
#pragma mark - TCCocoaBuddy

// == Class ==
@interface TCCocoaBuddy : NSObject <TCChatControllerDelegate>

// -- Constructor --
- (id)initWithBuddy:(TCBuddy *)buddy;

// -- Status --
- (tcbuddy_status)status;
- (NSString *)address;
- (BOOL)blocked;

- (NSString *)alias;
- (void)setAlias:(NSString *)alias;

- (NSString *)notes;
- (void)setNotes:(NSString *)notes;

- (NSImage *)localAvatar;
- (void)setLocalAvatar:(NSImage *)avatar;

// -- Profile --
- (NSImage *)profileAvatar;
- (NSString *)profileText;

- (NSString *)profileName;
- (NSString *)lastProfileName;
- (NSString *)finalName;

// -- Peer --
- (NSString *)peerVersion;
- (NSString *)peerClient;

// -- Actions --
- (void)startChatAndSelect:(BOOL)select;

// -- Handling --
- (void)yieldCore;

// -- File --
- (void)cancelFileUpload:(NSString *)uuid;
- (void)cancelFileDownload:(NSString *)uuid;

- (void)sendFile:(NSString *)fileName;

@end
