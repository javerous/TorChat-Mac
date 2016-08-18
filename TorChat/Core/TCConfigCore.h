/*
 *  TCConfigCore.h
 *
 *  Copyright 2016 Avérous Julien-Pierre
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

#import <Foundation/Foundation.h>


/*
** Forward
*/
#pragma mark - Forward

@class TCImage;



/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCConfigGetDefault,	// Value used when the item was never set
	TCConfigGetDefined,	// Value used when the item was set
	TCConfigGetReal		// Value to use in standard case (eg. defined / default automatic choise)
} TCConfigGet;



// -- Paths --
typedef enum
{
	TCConfigPathComponentReferral,		// Path used as referral.
	TCConfigPathComponentTorBinary,		// Path to the tor binary (and its dependancies) directory.
	TCConfigPathComponentTorData,		// Path to the tor data directory.
	TCConfigPathComponentTorIdentity,	// Path to tor hidden service (buddy identifier) - Obsolete: identity is now included directely in settings (selfPrivateKey). Kept only for importation.
	TCConfigPathComponentDownloads,		// Path to the downloads directory.
} TCConfigPathComponent;

typedef enum
{
	TCConfigPathTypeReferral,	// Path is relative to referral.
	TCConfigPathTypeStandard,	// Path is relative to standard OS X directories in ~.
	TCConfigPathTypeAbsolute,	// Path is absolute.
} TCConfigPathType;



/*
** TCConfigCore
*/
#pragma mark - TCConfigCore

@protocol TCConfigCore <NSObject>

// -- Tor --
@property NSString *torAddress;
@property uint16_t torPort;

// -- TorChat --
@property NSString *selfPrivateKey;
@property NSString *selfIdentifier;
@property uint16_t selfPort;

// -- Profile --
@property NSString	*profileName;
@property NSString	*profileText;
@property TCImage	*profileAvatar;

// -- Client --
- (NSString *)clientVersion:(TCConfigGet)get;
- (void)setClientVersion:(NSString *)version;

- (NSString *)clientName:(TCConfigGet)get;
- (void)setClientName:(NSString *)name;

// -- Buddies --
- (NSArray *)buddiesIdentifiers; // Array of buddy identifier.
- (void)addBuddyWithIdentifier:(NSString *)identifier alias:(NSString *)alias notes:(NSString *)notes;
- (void)removeBuddyWithIdentifier:(NSString *)identifier;

- (void)setBuddyAlias:(NSString *)alias forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyNotes:(NSString *)notes forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyLastName:(NSString *)lastName forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyLastText:(NSString *)lastText forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyLastAvatar:(TCImage *)lastAvatar forBuddyIdentifier:(NSString *)identifier;

- (NSString *)buddyAliasForBuddyIdentifier:(NSString *)identifier;
- (NSString *)buddyNotesForBuddyIdentifier:(NSString *)identifier;
- (NSString *)buddyLastNameForBuddyIdentifier:(NSString *)identifier;
- (NSString *)buddyLastTextForBuddyIdentifier:(NSString *)identifier;
- (TCImage *)buddyLastAvatarForBuddyIdentifier:(NSString *)identifier;

// -- Blocked --
- (NSArray *)blockedBuddies;
- (void)addBlockedBuddyWithIdentifier:(NSString *)identifier;
- (void)removeBlockedBuddyWithIdentifier:(NSString *)identifier;

// -- Paths --
- (void)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(NSString *)path;
- (NSString *)pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath;
- (TCConfigPathType)pathTypeForComponent:(TCConfigPathComponent)component;

- (id)addPathObserverForComponent:(TCConfigPathComponent)component queue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)removePathObserver:(id)observer;

// -- Synchronize --
- (BOOL)synchronize;

// -- Life --
- (void)close;

@end
