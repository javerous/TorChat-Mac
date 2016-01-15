/*
 *  TCBuddy.h
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

#import "TCConfig.h"


/*
** Globals
*/
#pragma mark - Globals

#define TCBuddyInfoDomain	@"TCBuddyInfoDomain"



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

// == Status ==
typedef enum
{
	TCStatusOffline,
	TCStatusAvailable,
	TCStatusAway,
	TCStatusXA,
} TCStatus;

// == Info Codes ==
typedef enum
{
	TCBuddyEventConnectedTor,
	TCBuddyEventConnectedBuddy,
	TCBuddyEventDisconnected,
	TCBuddyEventIdentified,
	
	TCBuddyEventStatus,				// context: NSNumber (TCStatus)
	TCBuddyEventMessage,			// context: NSString (<message>)
	TCBuddyEventAlias,				// context: NSString (<alias>)
	TCBuddyEventNotes,				// context: NSString (<notes>)
	TCBuddyEventVersion,			// context: NSString (<version>)
	TCBuddyEventClient,				// context: NSString (<client_name>)
	//TCBuddyEventBlocked,			// context: NSNumber (BOOL)
	
	TCBuddyEventFileSendStart,		// context: TCFileInfo
	TCBuddyEventFileSendRunning,	// context: TCFileInfo
	TCBuddyEventFileSendFinish,		// context: TCFileInfo
	TCBuddyEventFileSendStopped,	// context: TCFileInfo
	
	TCBuddyEventFileReceiveStart,	// context: TCFileInfo
	TCBuddyEventFileReceiveRunning,	// context: TCFileInfo
	TCBuddyEventFileReceiveFinish,	// context: TCFileInfo
	TCBuddyEventFileReceiveStopped,	// context: TCFileInfo
	
	TCBuddyEventProfileText,		// context: NSString (<text>)
	TCBuddyEventProfileName,		// context: NSString (<name>)
	TCBuddyEventProfileAvatar,		// context: TCImage
} TCBuddyEvent;

typedef enum
{
	TCBuddyErrorResolveTor,
	TCBuddyErrorConnectTor,
	
	TCBuddyErrorSocket,				// info: TCInfo (TCSocketInfoDomain)
	
	TCBuddyErrorSocks,				// context: NSNumber (<socks_error>)
	TCBuddyErrorSocksRequest,

	TCBuddyErrorMessageOffline,		// context: NSString (<message>)
	TCBuddyErrorMessageBlocked,		// context: NSString (<message>)
	
	TCBuddyErrorSendFile,			// context: NSString (<file_path>)
	TCBuddyErrorReceiveFile,
	TCBuddyErrorFileOffline,		// context: NSString (<file_path>)
	TCBuddyErrorFileBlocked,		// context: NSString (<file_path>)
	
	TCBuddyErrorParse				// info: TCInfo (TCSocketInfoDomain)
} TCBuddyError;

// == File ==
typedef enum
{
	TCBuddyFileReceive,
	TCBuddyFileSend
} TCBuddyFileWay;

// == Channel ==
typedef enum
{
	TCBuddyChannelOut,	// Connection initied by TCBuddy
	TCBuddyChannelIn,	// Connection received by TControlClient
} TCBuddyChannel;



/*
** TCBuddyObserver
*/
#pragma mark - TCBuddyObserver

@protocol TCBuddyObserver <NSObject>

- (void)buddy:(TCBuddy *)buddy information:(TCInfo *)info;

@end




/*
** TCBuddy
*/
#pragma mark - TCBuddy

@interface TCBuddy : NSObject

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

- (TCStatus)status;

- (NSString *)address;
- (NSString *)random;

// -- Files Info --
- (NSString *)fileNameForUUID:(NSString *)uuid andWay:(TCBuddyFileWay)way;
- (NSString *)filePathForUUID:(NSString *)uuid andWay:(TCBuddyFileWay)way;
- (BOOL)fileStatForUUID:(NSString *)uuid way:(TCBuddyFileWay)way done:(uint64_t *)done total:(uint64_t *)total;
- (void)fileCancelOfUUID:(NSString *)uuid way:(TCBuddyFileWay)way;

// -- Send Command --
- (void)sendStatus:(TCStatus)status;
- (void)sendAvatar:(TCImage *)avatar;
- (void)sendProfileName:(NSString *)name;
- (void)sendProfileText:(NSString *)text;
- (void)sendMessage:(NSString *)message;
- (void)sendFile:(NSString *)filepath;

// -- Action --
- (void)startHandshake:(NSString *)remoteRandom status:(TCStatus)status avatar:(TCImage *)avatar name:(NSString *)name text:(NSString *)text;
- (void)setInputConnection:(TCSocket *)sock;

// -- Content --
- (NSString *)peerClient;
- (NSString *)peerVersion;

- (NSString *)profileText;
- (TCImage *)profileAvatar;
- (NSString *)profileName;		// Current profile name

- (NSString *)lastProfileName;	// Last know profile name
- (NSString *)finalName;		// Best name representation (alias / profile name / last know profile name)

// -- Observers --
- (void)addObserver:(id <TCBuddyObserver>)observer;
- (void)removeObserver:(id <TCBuddyObserver>)observer;

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
