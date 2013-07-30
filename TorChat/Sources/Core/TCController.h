/*
 *  TCController.h
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


#import <Foundation/Foundation.h>

#import "TCInfo.h"
#import "TCConfig.h"


/*
** Forward
*/
#pragma mark - Forward

@class TCController;
@class TCControlClient;

@class TCImage;
@class TCBuddy;



/*
** Types
*/
#pragma mark - Types

// == Controller Status ==
typedef enum
{
	tccontroller_available,
	tccontroller_away,
	tccontroller_xa
} tccontroller_status;

// == Info Code ==
typedef enum
{
	// -- Notify --
	tcctrl_notify_started,
	tcctrl_notify_stoped,
	tcctrl_notify_status,
	
	tcctrl_notify_profile_avatar,
	tcctrl_notify_profile_name,
	tcctrl_notify_profile_text,
	
	tcctrl_notify_buddy_new,
	
	tcctrl_notify_client_new,
	tcctrl_notify_client_started,
	tcctrl_notify_client_stoped,
	
	// -- Errors --
	tcctrl_error_serv_socket,
	tcctrl_error_serv_accept,
	
	tcctrl_error_socket,
	
	tcctrl_error_client_read,
	tcctrl_error_client_read_closed,
	tcctrl_error_client_read_full,
	
	tcctrl_error_client_unknown_command,
	
	tcctrl_error_client_cmd_ping,
	tcctrl_error_client_cmd_pong,
	tcctrl_error_client_cmd_status,
	tcctrl_error_client_cmd_version,
	tcctrl_error_client_cmd_client,
	tcctrl_error_client_cmd_profile_text,
	tcctrl_error_client_cmd_profile_name,
	tcctrl_error_client_cmd_profile_avatar,
	tcctrl_error_client_cmd_profile_avatar_alpha,
	tcctrl_error_client_cmd_message,
	tcctrl_error_client_cmd_addme,
	tcctrl_error_client_cmd_removeme,
	tcctrl_error_client_cmd_filename,
	tcctrl_error_client_cmd_filedata,
	tcctrl_error_client_cmd_filedataok,
	tcctrl_error_client_cmd_filedataerror,
	tcctrl_error_client_cmd_filestopsending,
	tcctrl_error_client_cmd_filestopreceiving,
} tcctrl_info;

// -- Delegate --
@protocol TCControllerDelegate <NSObject>

- (void)torchatController:(TCController *)controller information:(const TCInfo *)info;

@end




/*
** TCController
*/
#pragma mark - TCController

@interface TCController : NSObject

// -- Properties --
@property (weak, atomic) id <TCControllerDelegate> delegate;

// -- Instance --
- (id)initWithConfiguration:(id <TCConfig>)config;

// -- Life --
- (void)start;
- (void)stop;

// -- Status --
- (void)setStatus:(tccontroller_status)status;
- (tccontroller_status)status;

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

// -- TCControlClient --
- (void)cc_error:(TCControlClient *)client info:(TCInfo *)info;
- (void)cc_notify:(TCControlClient *)client info:(TCInfo *)info;

@end
