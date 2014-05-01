/*
 *  TCBuddy.h
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

#import "TCConfig.h"
#import "TCConstants.h"


/*
** Forward
*/
#pragma mark - Forward

@class TCBuddy;
@class TCSocket;
@class TCInfo;
@class TCImage;



/*
** Types
*/
#pragma mark - Types

// == Info Codes ==
typedef enum
{
	// -- Notify --
	tcbuddy_notify_connected_tor,
	tcbuddy_notify_connected_buddy,
	tcbuddy_notify_disconnected,
	tcbuddy_notify_identified,
	
	tcbuddy_notify_status,
	tcbuddy_notify_message,
	tcbuddy_notify_alias,
	tcbuddy_notify_notes,
	tcbuddy_notify_version,
	tcbuddy_notify_client,
	tcbuddy_notify_blocked,
	
	tcbuddy_notify_file_send_start,
	tcbuddy_notify_file_send_running,
	tcbuddy_notify_file_send_finish,
	tcbuddy_notify_file_send_stoped,
	
	tcbuddy_notify_file_receive_start,
	tcbuddy_notify_file_receive_running,
	tcbuddy_notify_file_receive_finish,
	tcbuddy_notify_file_receive_stoped,
	
	tcbuddy_notify_profile_text,
	tcbuddy_notify_profile_name,
	tcbuddy_notify_profile_avatar,
	
	
	// -- Error --
	tcbuddy_error_resolve_tor,
	tcbuddy_error_connect_tor,
	
	tcbuddy_error_socket,
	
	tcbuddy_error_socks,
	
	tcbuddy_error_too_messages,
	tcbuddy_error_message_offline,
	tcbuddy_error_message_blocked,
	
	tcbuddy_error_send_file,
	tcbuddy_error_receive_file,
	tcbuddy_error_file_offline,
	tcbuddy_error_file_blocked,
	
	tcbuddy_error_parse
} tcbuddy_info;

// == File ==
typedef enum
{
	tcbuddy_file_receive,
	tcbuddy_file_send
} tcbuddy_file_way;

// == Channel ==
typedef enum
{
	tcbuddy_channel_out,	// Connection initied by TCBuddy
	tcbuddy_channel_in,		// Connection received by TControlClient
} tcbuddy_channel;



/*
** TCBuddyDelegate
*/
#pragma mark - TCBuddyDelegate

@protocol TCBuddyDelegate <NSObject>

- (void)buddy:(TCBuddy *)buddy event:(const TCInfo *)info;

@end




/*
** TCBuddy
*/
#pragma mark - TCBuddy

@interface TCBuddy : NSObject

// -- Properties --
@property (weak, atomic) id <TCBuddyDelegate> delegate;

// -- Instance --
- (id)initWithConfiguration:(id <TCConfig>)configuration alias:(NSString *)alias address:(NSString *)address notes:(NSString *)notes;

// -- Run --
- (void)start;
- (void)stop;

- (BOOL)isRunning;
- (BOOL)isPonged;
- (void)keepAlive;

// -- Accessors --
- (NSString *)alias;
- (void)setAlias:(NSString *)name;

- (NSString *)notes;
- (void)setNotes:(NSString *)notes;

- (BOOL)blocked;
- (void)setBlocked:(BOOL)blocked;

- (tcstatus)status;

- (NSString *)address;
- (NSString *)random;

// -- Files Info --
- (NSString *)fileNameForUUID:(NSString *)uuid andWay:(tcbuddy_file_way)way;
- (NSString *)filePathForUUID:(NSString *)uuid andWay:(tcbuddy_file_way)way;
- (BOOL)fileStatForUUID:(NSString *)uuid way:(tcbuddy_file_way)way done:(uint64_t *)done total:(uint64_t *)total;
- (void)fileCancelOfUUID:(NSString *)uuid way:(tcbuddy_file_way)way;

// -- Send Command --
- (void)sendStatus:(tcstatus)status;
- (void)sendAvatar:(TCImage *)avatar;
- (void)sendProfileName:(NSString *)name;
- (void)sendProfileText:(NSString *)text;
- (void)sendMessage:(NSString *)message;
- (void)sendFile:(NSString *)filepath;

// -- Action --
- (void)startHandshake:(NSString *)remoteRandom status:(tcstatus)status avatar:(TCImage *)avatar name:(NSString *)name text:(NSString *)text;
- (void)setInputConnection:(TCSocket *)sock;

// -- Content --
- (NSString *)peerClient;
- (NSString *)peerVersion;

- (NSString *)profileText;
- (TCImage *)profileAvatar;
- (NSString *)profileName;		// Current profile name

- (NSString *)lastProfileName;	// Last know profile name
- (NSString *)finalName;		// Best name representation (alias / profile name / last know profile name)

@end



/*
** TCFileInfo
*/
#pragma mark - TCFileInfo

@interface TCFileInfo : NSObject

- (NSString *)uuid;

- (uint64_t)fileSizeCompleted;
- (uint64_t)fileSizeTotal;

- (NSString *)fileName;
- (NSString *)filePath;

@end
