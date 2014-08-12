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
	// -- Events --
	TCCoreEventStarted,
	TCCoreEventStopped,
	TCCoreEventStatus,			// context: NSNumber (TCStatus)
	
	TCCoreEventProfileAvatar,	// context: TCImage
	TCCoreEventProfileName,		// context: NSString (<name>)
	TCCoreEventProfileText,		// context: NSString (<text>)
	
	TCCoreEventBuddyNew,		// context: TCBuddy
	
	TCCoreEventClientStarted,
	TCCoreEventClientStopped,
	
	// -- Errors --
	TCCoreErrorServAccept,
	TCCoreErrorServAcceptAsync,
	
	TCCoreErrorSocket,			// info: TCInfo (TCSocketInfoDomain)
	TCCoreErrorSocketCreate,
	TCCoreErrorSocketOption,
	TCCoreErrorSocketBind,
	TCCoreErrorSocketListen,

	TCCoreErrorClientAlreadyPinged,
	TCCoreErrorClientMasquerade,
	TCCoreErrorClientAddBuddy,
	
	TCCoreErrorClientCmdUnknownCommand,		// context: NSString (<parser_error>)
	
	TCCoreErrorClientCmdPing,				// context: NSString (<parser_error>)
	TCCoreErrorClientCmdPong,				// context: NSString (<parser_error>)
	TCCoreErrorClientCmdStatus,				// context: NSString (<parser_error>)
	TCCoreErrorClientCmdVersion,			// context: NSString (<parser_error>)
	TCCoreErrorClientCmdClient,				// context: NSString (<parser_error>)
	TCCoreErrorClientCmdProfileText,		// context: NSString (<parser_error>)
	TCCoreErrorClientCmdProfileName,		// context: NSString (<parser_error>)
	TCCoreErrorClientCmdProfileAvatar,		// context: NSString (<parser_error>)
	TCCoreErrorClientCmdProfileAvatarAlpha,	// context: NSString (<parser_error>)
	TCCoreErrorClientCmdMessage,			// context: NSString (<parser_error>)
	TCCoreErrorClientCmdAddMe,				// context: NSString (<parser_error>)
	TCCoreErrorClientCmdRemoveMe,			// context: NSString (<parser_error>)
	TCCoreErrorClientCmdFileName,			// context: NSString (<parser_error>)
	TCCoreErrorClientCmdFileData,			// context: NSString (<parser_error>)
	TCCoreErrorClientCmdFileDataOk,			// context: NSString (<parser_error>)
	TCCoreErrorClientCmdFileDataError,		// context: NSString (<parser_error>)
	TCCoreErrorClientCmdFileStopSending,	// context: NSString (<parser_error>)
	TCCoreErrorClientCmdFileStopReceiving,	// context: NSString (<parser_error>)
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
