/*
 *  TCConfig.h
 *
<<<<<<< HEAD
 *  Copyright 2014 Avérous Julien-Pierre
=======
 *  Copyright 2016 Avérous Julien-Pierre
>>>>>>> javerous/master
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


<<<<<<< HEAD

=======
>>>>>>> javerous/master
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
<<<<<<< HEAD
} TCConfigGet; // FIXME: use in all get_* functions
=======
} TCConfigGet;
>>>>>>> javerous/master

typedef enum
{
	TCConfigModeAdvanced,
	TCConfigModeBasic
} TCConfigMode;

<<<<<<< HEAD

=======
// -- Localization --
>>>>>>> javerous/master
typedef enum
{
	TCConfigStringItemMyselfBuddy,
} TCConfigStringItem;

<<<<<<< HEAD
typedef enum
{
	TConfigPathDomainReferal,	// Referal path.
	TConfigPathDomainTorBinary,	// Path to the tor binary (and its dependancies) directory.
	TConfigPathDomainTorData,	// Path to the tor data directory.
	TConfigPathDomainTorIdentity, // Path to tor hidden service (buddy address)
	TConfigPathDomainDownloads,	// Path to the downloads directory.
} TConfigPathDomain;

typedef enum
{
	TConfigPathPlaceReferal,	// Path is relative to referal.
	TConfigPathPlaceStandard,	// Path is relative to standard OS X directories in ~.
	TConfigPathPlaceAbsolute,	// Path is absolute.
} TConfigPathPlace;
=======
// -- Paths --
typedef enum
{
	TCConfigPathComponentReferal,		// Path used as referal.
	TCConfigPathComponentTorBinary,		// Path to the tor binary (and its dependancies) directory.
	TCConfigPathComponentTorData,		// Path to the tor data directory.
	TCConfigPathComponentTorIdentity,	// Path to tor hidden service (buddy address)
	TCConfigPathComponentDownloads,		// Path to the downloads directory.
} TCConfigPathComponent;

typedef enum
{
	TCConfigPathTypeReferal,		// Path is relative to referal.
	TCConfigPathTypeStandard,	// Path is relative to standard OS X directories in ~.
	TCConfigPathTypeAbsolute,	// Path is absolute.
} TCConfigPathType;
>>>>>>> javerous/master



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
<<<<<<< HEAD
- (NSString *)pathForDomain:(TConfigPathDomain)domain;
- (BOOL)setDomain:(TConfigPathDomain)domain place:(TConfigPathPlace)place subpath:(NSString *)subpath;
=======
- (BOOL)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(NSString *)path;
- (NSString *)pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath;
- (TCConfigPathType)pathTypeForComponent:(TCConfigPathComponent)component;

- (id)addPathObserverForComponent:(TCConfigPathComponent)component queue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block;
- (void)removePathObserver:(id)observer;
>>>>>>> javerous/master

// -- Strings --
- (NSString *)localizedString:(TCConfigStringItem)stringItem;

<<<<<<< HEAD
=======
// -- Synchronize --
- (void)synchronize;

>>>>>>> javerous/master
@end
