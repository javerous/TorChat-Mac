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

#import "TCConfigCore.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Globals
*/
#pragma mark - Globals

#define TCBuddyInfoDomain	@"TCBuddyInfoDomain"



/*
** Forward
*/
#pragma mark - Forward

@class TCCoreManager;
@class TCBuddy;
@class TCImage;

@class SMSocket;
@class SMInfo;



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
	
	TCBuddyErrorSocket,				// info: SMInfo (SMSocketInfoDomain)
	
	TCBuddyErrorSocks,				// context: NSNumber (<socks_error>)
	TCBuddyErrorSocksRequest,

	TCBuddyErrorMessageOffline,		// context: NSString (<message>)
	TCBuddyErrorMessageBlocked,		// context: NSString (<message>)
	
	TCBuddyErrorSendFile,			// context: NSString (<file_path>)
	TCBuddyErrorReceiveFile,
	TCBuddyErrorFileOffline,		// context: NSString (<file_path>)
	TCBuddyErrorFileBlocked,		// context: NSString (<file_path>)
	
	TCBuddyErrorParse				// info: SMInfo (SMSocketInfoDomain)
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

- (void)buddy:(TCBuddy *)buddy information:(SMInfo *)info;

@end




/*
** TCBuddy
*/
#pragma mark - TCBuddy

@interface TCBuddy : NSObject

// -- Instance --
- (instancetype)initWithCoreManager:(TCCoreManager *)core configuration:(id <TCConfigCore>)configuration identifier:(NSString *)identifier alias:(nullable NSString *)alias notes:(nullable NSString *)notes;

// -- Run --
- (void)start;
- (void)stopWithCompletionHandler:(nullable dispatch_block_t)handler;

- (BOOL)isRunning;
- (BOOL)isPonged;

// -- Properties --
@property (nullable, strong, atomic) NSString	*alias;
@property (nullable, strong, atomic) NSString	*notes;

@property (assign, atomic) BOOL blocked;

@property (assign, readonly) TCStatus	status;

@property (strong, readonly) NSString	*identifier;
@property (strong, readonly) NSString	*random;

@property (strong, readonly) NSString	*peerClient;
@property (strong, readonly) NSString	*peerVersion;

@property (nullable, strong, readonly) NSString	*profileText;
@property (nullable, strong, readonly) TCImage	*profileAvatar;
@property (nullable, strong, readonly) NSString	*profileName;
@property (nullable, strong, readonly) NSString	*finalName; // Best name representation (alias / profile name)

// -- Files Info --
- (nullable NSString *)fileNameForUUID:(NSString *)uuid way:(TCBuddyFileWay)way;
- (nullable NSString *)filePathForUUID:(NSString *)uuid way:(TCBuddyFileWay)way;
- (BOOL)fileStatForUUID:(NSString *)uuid way:(TCBuddyFileWay)way done:(uint64_t *)done total:(uint64_t *)total;
- (void)fileCancelOfUUID:(NSString *)uuid way:(TCBuddyFileWay)way;

// -- Messages --
- (NSArray *)popMessages;

// -- Send Command --
- (void)sendStatus:(TCStatus)status;
- (void)sendAvatar:(nullable TCImage *)avatar;
- (void)sendProfileName:(nullable NSString *)name;
- (void)sendProfileText:(nullable NSString *)text;
- (void)sendMessage:(NSString *)message completionHanndler:(void (^)(SMInfo *info))handler;
- (void)sendFile:(NSString *)filepath;

// -- Action --
- (void)handlePingWithRandomToken:(NSString *)remoteRandom;
- (void)handlePongWithSocket:(SMSocket *)sock;

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


NS_ASSUME_NONNULL_END
