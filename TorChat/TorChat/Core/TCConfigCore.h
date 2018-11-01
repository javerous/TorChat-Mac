/*
 *  TCConfigCore.h
 *
 *  Copyright 2018 Avérous Julien-Pierre
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


NS_ASSUME_NONNULL_BEGIN


/*
** Forward
*/
#pragma mark - Forward

@class TCImage;



/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, TCConfigGet) {
	TCConfigGetDefault,	// Value used when the item was never set
	TCConfigGetDefined,	// Value used when the item was set
	TCConfigGetReal		// Value to use in standard case (eg. defined / default automatic choise)
};



// -- Paths --
typedef NS_ENUM(unsigned int, TCConfigPathComponent) {
	TCConfigPathComponentReferral,		// Path used as referral.
	TCConfigPathComponentTorBinary,		// Path to the tor binary (and its dependancies) directory.
	TCConfigPathComponentTorData,		// Path to the tor data directory.
	TCConfigPathComponentTorIdentity,	// Path to tor hidden service (buddy identifier) - Obsolete: identity is now included directely in settings (selfPrivateKey). Kept only for importation.
	TCConfigPathComponentDownloads,		// Path to the downloads directory.
};

typedef NS_ENUM(unsigned int, TCConfigPathType) {
	TCConfigPathTypeReferral,	// Path is relative to referral.
	TCConfigPathTypeStandard,	// Path is relative to standard OS X directories in ~.
	TCConfigPathTypeAbsolute,	// Path is absolute.
};



/*
** TCConfigCore
*/
#pragma mark - TCConfigCore

@protocol TCConfigCore <NSObject>

// -- Tor --
@property (atomic)	NSString *torAddress;
@property (atomic)	uint16_t torPort;

// -- TorChat --
@property (nullable, atomic)	NSString *selfPrivateKey;
@property (nullable, atomic)	NSString *selfIdentifier;
@property (atomic)				uint16_t selfPort;

// -- Profile --
@property (nullable, atomic) NSString	*profileName;
@property (nullable, atomic) NSString	*profileText;
@property (nullable, atomic) TCImage	*profileAvatar;

// -- Client --
- (nullable NSString *)clientVersion:(TCConfigGet)get;
- (void)setClientVersion:(nullable NSString *)version;

- (nullable NSString *)clientName:(TCConfigGet)get;
- (void)setClientName:(nullable NSString *)name;

// -- Buddies --
@property (atomic, readonly, copy) NSArray * buddiesIdentifiers; // Array of buddy identifier.

- (void)addBuddyWithIdentifier:(NSString *)identifier alias:(nullable NSString *)alias notes:(nullable NSString *)notes;
- (void)removeBuddyWithIdentifier:(NSString *)identifier;

- (void)setBuddyAlias:(nullable NSString *)alias forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyNotes:(nullable NSString *)notes forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyLastName:(nullable NSString *)lastName forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyLastText:(nullable NSString *)lastText forBuddyIdentifier:(NSString *)identifier;
- (void)setBuddyLastAvatar:(nullable TCImage *)lastAvatar forBuddyIdentifier:(NSString *)identifier;

- (nullable NSString *)buddyAliasForBuddyIdentifier:(NSString *)identifier;
- (nullable NSString *)buddyNotesForBuddyIdentifier:(NSString *)identifier;
- (nullable NSString *)buddyLastNameForBuddyIdentifier:(NSString *)identifier;
- (nullable NSString *)buddyLastTextForBuddyIdentifier:(NSString *)identifier;
- (nullable TCImage *)buddyLastAvatarForBuddyIdentifier:(NSString *)identifier;

// -- Blocked --
@property (atomic, readonly, copy) NSArray *blockedBuddies;

- (void)addBlockedBuddyWithIdentifier:(NSString *)identifier;
- (void)removeBlockedBuddyWithIdentifier:(NSString *)identifier;

// -- Paths --
- (void)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(nullable NSString *)path;
- (nullable NSString *)pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath;
- (TCConfigPathType)pathTypeForComponent:(TCConfigPathComponent)component;

- (id)addPathObserverForComponent:(TCConfigPathComponent)component queue:(nullable dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)removePathObserver:(id)observer;

// -- Synchronize --
- (BOOL)synchronize;

// -- Life --
- (void)close;

@end


NS_ASSUME_NONNULL_END
