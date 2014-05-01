/*
 *  TCCoreManager.h
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

#import "TCInfo.h"
#import "TCConfig.h"
#import "TCConstants.h"


/*
** Forward
*/
#pragma mark - Forward

@class TCCoreManager;

@class TCImage;
@class TCBuddy;



/*
** Types
*/
#pragma mark - Types

// == Info Code ==
typedef enum
{
	// -- Notify --
	tccore_notify_started,
	tccore_notify_stoped,
	tccore_notify_status,
	
	tccore_notify_profile_avatar,
	tccore_notify_profile_name,
	tccore_notify_profile_text,
	
	tccore_notify_buddy_new,
	
	tccore_notify_client_new,
	tccore_notify_client_started,
	tccore_notify_client_stoped,
	
	// -- Errors --
	tccore_error_serv_socket,
	tccore_error_serv_accept,
	
	tccore_error_socket,
	
	tccore_error_client_read,
	tccore_error_client_read_closed,
	tccore_error_client_read_full,
	
	tccore_error_client_unknown_command,
	
	tccore_error_client_cmd_ping,
	tccore_error_client_cmd_pong,
	tccore_error_client_cmd_status,
	tccore_error_client_cmd_version,
	tccore_error_client_cmd_client,
	tccore_error_client_cmd_profile_text,
	tccore_error_client_cmd_profile_name,
	tccore_error_client_cmd_profile_avatar,
	tccore_error_client_cmd_profile_avatar_alpha,
	tccore_error_client_cmd_message,
	tccore_error_client_cmd_addme,
	tccore_error_client_cmd_removeme,
	tccore_error_client_cmd_filename,
	tccore_error_client_cmd_filedata,
	tccore_error_client_cmd_filedataok,
	tccore_error_client_cmd_filedataerror,
	tccore_error_client_cmd_filestopsending,
	tccore_error_client_cmd_filestopreceiving,
} tccore_info;

// -- Delegate --
@protocol TCCoreManagerDelegate <NSObject>

- (void)torchatManager:(TCCoreManager *)manager information:(TCInfo *)info;

@end




/*
** TCCoreManager
*/
#pragma mark - TCCoreManager

@interface TCCoreManager : NSObject

// -- Properties --
@property (weak, atomic) id <TCCoreManagerDelegate> delegate;

// -- Instance --
- (id)initWithConfiguration:(id <TCConfig>)config;

// -- Life --
- (void)start;
- (void)stop;

// -- Status --
- (void)setStatus:(tcstatus)status;
- (tcstatus)status;

// -- Profile --
- (void)setProfileAvatar:(TCImage *)avatar;
- (TCImage *)profileAvatar;

- (void)setProfileName:(NSString *)name;
- (NSString *)profileName;

- (void)setProfileText:(NSString *)text;
- (NSString *)profileText;

// -- Buddies --
- (void)addBuddy:(NSString *)name address:(NSString *)address;
- (void)addBuddy:(NSString *)name address:(NSString *)address comment:(NSString *)comment;
- (void)removeBuddy:(NSString *)address;
- (TCBuddy *)buddyWithAddress:(NSString *)address;
- (TCBuddy *)buddyWithRandom:(NSString *)random;

// -- Blocked Buddies --
- (BOOL)addBlockedBuddy:(NSString *)address;
- (BOOL)removeBlockedBuddy:(NSString *)address;

@end
