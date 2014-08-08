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
#import "TCBuddy.h"


/*
** Globals
*/
#pragma mark - Globals

#define TCCoreManagerInfoDomain	@"TCCoreManagerInfoDomain"



/*
** Forward
*/
#pragma mark - Forward

@class TCCoreManager;
@class TCImage;



/*
** Types
*/
#pragma mark - Types

// == Info Code ==
typedef enum
{
	// -- Notify --
	TCCoreNotifyStarted,
	TCCoreNotifyStopped,
	TCCoreNotifyStatus,
	
	TCCoreNotifyProfileAvatar,
	TCCoreNotifyProfileName,
	TCCoreNotifyProfileText,
	
	TCCoreNotifyBuddyNew,
	
	TCCoreNotifyClientNew,
	TCCoreNotifyClientStarted,
	TCCoreNotifyClientStopped,
	
	// -- Errors --
	TCCoreErrorServAccept,
	TCCoreErrorServAcceptAsync,
	
	TCCoreErrorSocket,
	TCCoreErrorSocketCreate,
	TCCoreErrorSocketOption,
	TCCoreErrorSocketBind,
	TCCoreErrorSocketListen,

	TCCoreErrorClientRead,
	TCCoreErrorClientReadClosed,
	TCCoreErrorClientReadFull,
	
	TCCoreErrorClientAlreadyPinged,
	TCCoreErrorClientMasquerade,
	TCCoreErrorClientAddBuddy,
	
	TCCoreErrorClientCmdUnknownCommand,
	
	TCCoreErrorClientCmdPing,
	TCCoreErrorClientCmdPong,
	TCCoreErrorClientCmdStatus,
	TCCoreErrorClientCmdVersion,
	TCCoreErrorClientCmdClient,
	TCCoreErrorClientCmdProfileText,
	TCCoreErrorClientCmdProfileName,
	TCCoreErrorClientCmdProfileAvatar,
	TCCoreErrorClientCmdProfileAvatarAlpha,
	TCCoreErrorClientCmdMessage,
	TCCoreErrorClientCmdAddMe,
	TCCoreErrorClientCmdRemoveMe,
	TCCoreErrorClientCmdFileName,
	TCCoreErrorClientCmdFileData,
	TCCoreErrorClientCmdFileDataOk,
	TCCoreErrorClientCmdFileDataError,
	TCCoreErrorClientCmdFileStopSending,
	TCCoreErrorClientCmdFileStopReceiving,
} TCCoreInfo;

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
- (void)setStatus:(TCStatus)status;
- (TCStatus)status;

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
