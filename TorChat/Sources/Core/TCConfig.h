/*
 *  TCConfig.h
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
	tc_config_get_default,	// Value used when the item was never set
	tc_config_get_defined,	// Value used when the item was set
	tc_config_get_real		// Value to use in standard case (eg. defined / default automatic choise)
} tc_config_get; // FIXME: use in all get_* functions

typedef enum
{
	tc_config_advanced,
	tc_config_basic
} tc_config_mode;

typedef enum
{
	tc_config_title_address = 0,
	tc_config_title_name	= 1
} tc_config_title;



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

- (NSString *)torPath;
- (void)setTorPath:(NSString *)path;

- (NSString *)torDataPath;
- (void)setTorDataPath:(NSString *)path;

// -- TorChat --
- (NSString *)selfAddress;
- (void)setSelfAddress:(NSString *)address;

- (uint16_t)clientPort;
- (void)setClientPort:(uint16_t)port;

- (NSString *)downloadFolder;
- (void)setDownloadFolder:(NSString *)folder;

// -- Mode --
- (tc_config_mode)mode;
- (void)setMode:(tc_config_mode)mode;

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

// -- UI --
- (tc_config_title)modeTitle;
- (void)setModeTitle:(tc_config_title)mode;

// -- Client --
- (NSString *)clientVersion:(tc_config_get)get;
- (void)setClientVersion:(NSString *)version;

- (NSString *)clientName:(tc_config_get)get;
- (void)setClientName:(NSString *)name;

// -- Tools --
- (NSString *)realPath:(NSString *)path;

// -- Localization --
- (NSString *)localized:(NSString *)key;

@end
