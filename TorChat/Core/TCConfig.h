/*
 *  TCConfig.h
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
** Defines
*/
#pragma mark - Defines

#define TCConfigBuddyAddress	@"address"
#define TCConfigBuddyAlias		@"alias"
#define TCConfigBuddyNotes		@"notes"

#define TCConfigBuddyLastName	@"lname"
#define TCConfigBuddyLastText	@"ltext"
#define TCConfigBuddyLastAvatar	@"lavatar"



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

typedef enum
{
	TCConfigModeAdvanced,
	TCConfigModeBasic
} TCConfigMode;

// -- Localization --
typedef enum
{
	TCConfigStringItemMyselfBuddy,
} TCConfigStringItem;

// -- Paths --
typedef enum
{
	TConfigPathComponentReferal,		// Path used as referal.
	TConfigPathComponentTorBinary,		// Path to the tor binary (and its dependancies) directory.
	TConfigPathComponentTorData,		// Path to the tor data directory.
	TConfigPathComponentTorIdentity,	// Path to tor hidden service (buddy address)
	TConfigPathComponentDownloads,		// Path to the downloads directory.
} TConfigPathComponent;

typedef enum
{
	TConfigPathTypeReferal,		// Path is relative to referal.
	TConfigPathTypeStandard,	// Path is relative to standard OS X directories in ~.
	TConfigPathTypeAbsolute,	// Path is absolute.
} TConfigPathType;



/*
** TCConfig
*/
#pragma mark - TCConfig

@protocol TCConfig <NSObject>

// -- Tor --
- (NSString *)torAddress;
- (void)setTorAddress:(NSString *)address;

- (uint16_t)torPort;
- (void)setTorPort:(uint16_t) port;

// -- TorChat --
- (NSString *)selfAddress;
- (void)setSelfAddress:(NSString *)address;

- (uint16_t)clientPort;
- (void)setClientPort:(uint16_t)port;

// -- Mode --
- (TCConfigMode)mode;
- (void)setMode:(TCConfigMode)mode;

// -- Profile --
- (NSString *)profileName;
- (void)setProfileName:(NSString *)name;

- (NSString *)profileText;
- (void)setProfileText:(NSString *)text;

- (TCImage *)profileAvatar;
- (void)setProfileAvatar:(TCImage *)picture;

// -- Buddies --
- (NSArray *)buddies; // Array of dictionary.
- (void)addBuddy:(NSString *)address alias:(NSString *)alias notes:(NSString *)notes;
- (BOOL)removeBuddy:(NSString *)address;

- (void)setBuddy:(NSString *)address alias:(NSString *)alias;
- (void)setBuddy:(NSString *)address notes:(NSString *)notes;
- (void)setBuddy:(NSString *)address lastProfileName:(NSString *)lastName;
- (void)setBuddy:(NSString *)address lastProfileText:(NSString *)lastText;
- (void)setBuddy:(NSString *)address lastProfileAvatar:(TCImage *)lastAvatar;

- (NSString *)getBuddyAlias:(NSString *)address;
- (NSString *)getBuddyNotes:(NSString *)address;
- (NSString *)getBuddyLastProfileName:(NSString *)address;
- (NSString *)getBuddyLastProfileText:(NSString *)address;
- (TCImage *)getBuddyLastProfileAvatar:(NSString *)address;

// -- Blocked --
- (NSArray *)blockedBuddies;
- (BOOL)addBlockedBuddy:(NSString *)address;
- (BOOL)removeBlockedBuddy:(NSString *)address;

// -- Client --
- (NSString *)clientVersion:(TCConfigGet)get;
- (void)setClientVersion:(NSString *)version;

- (NSString *)clientName:(TCConfigGet)get;
- (void)setClientName:(NSString *)name;

// -- Paths --
- (BOOL)setPathForComponent:(TConfigPathComponent)component pathType:(TConfigPathType)pathType path:(NSString *)path;
- (NSString *)pathForComponent:(TConfigPathComponent)component fullPath:(BOOL)fullPath;
- (TConfigPathType)pathTypeForComponent:(TConfigPathComponent)component;

- (id)addPathObserverForComponent:(TConfigPathComponent)component queue:(dispatch_queue_t)queue usingBlock:(void (^)(NSString *previousPath, NSString *newPath))block;
- (void)removePathObserver:(id)observer;

// -- Strings --
- (NSString *)localizedString:(TCConfigStringItem)stringItem;

// -- Synchronize --
- (void)synchronize;

@end
