/*
 *  TCBuddy.m
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

#import <SMFoundation/SMFoundation.h>

#include <netdb.h>
#include <pwd.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>

#include <arpa/inet.h>

#import "TCBuddy.h"

#import "TCCoreManager.h"

#import "TCDebugLog.h"

#import "TCParser.h"
#import "TCImage.h"

#import "TCFileReceive.h"
#import "TCFileSend.h"

#import "NSArray+TCTools.h"
#import "NSData+TCTools.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TORCHAT_PORT	11009 // Should be in config file ?



/*
** Types
*/
#pragma mark - Types

// == SOCKS ==
// -- Structure representing a Socks connection request --
struct sockreq
{
	uint8_t		version;
	uint8_t		command;
	uint16_t	dstport;
	uint32_t	dstip;
	// A null terminated username goes here
};

// -- Structure representing a Socks connection request response --
struct sockrep
{
	uint8_t		version;
	uint8_t		result;
	uint16_t	ignore1;
	uint32_t	ignore2;
};

// -- Socks State --
typedef NS_ENUM(unsigned int, socks_state) {
	socks_nostate,
	socks_running,
	socks_finish,
};

// -- Socks trame type --
typedef NS_ENUM(unsigned int, socks_trame) {
	socks_v4_reply,
};



/*
** Global
*/
#pragma mark - Global

static char gQueueIdentityKey;
static char gLocalQueueContext;



/*
** TCFileInfo
*/
#pragma mark - TCFileInfo

@interface TCFileInfo ()
{
	TCFileSend		*_sender;
	TCFileReceive	*_receiver;
}

// -- Instance --
- (instancetype)initWithFileSend:(TCFileSend *)sender;
- (instancetype)initWithFileReceive:(TCFileReceive *)receiver;

@end



/*
** TCBuddy - Private
*/
#pragma mark - TCBuddy - Private

@interface TCBuddy () <TCParserCommand, TCParserDelegate, SMSocketDelegate>
{
	// > Core.
	__weak TCCoreManager *_coreManager;
	
	// > Config
	id <TCConfigCore>	_config;
	
	// > Parser
	TCParser			*_parser;
	
	// > Status
	int					_socksstate;
	BOOL				_running;
	BOOL				_ponged;
	
	NSString			*_pingRandom;
	BOOL				_pingHandled;
	
	BOOL				_blocked;
	
	// > Property
	NSString			*_alias;
	NSString			*_identifier;
	NSString			*_notes;
	NSString			*_random;
	
	TCStatus			_status;
	TCStatus			_cstatus;
	
	// > Dispatch
	dispatch_queue_t	_localQueue;
	
	dispatch_source_t	_pendingConnectTimer;
	dispatch_source_t	_keepAliveTimer;
	
	// > Socket
	SMSocket			*_inSocket;
	SMSocket			*_outSocket;
	
	// > Profile
	TCImage				*_profileAvatar;
	NSString			*_profileName;
	NSString			*_profileText;

	// > Peer
	NSString			*_peerClient;
	NSString			*_peerVersion;
	
	// > File session
	NSMutableDictionary	*_freceive;
	NSMutableDictionary	*_fsend;
	
	// > Messages
	NSMutableArray		*_messages;
	
	// > Observers
	NSHashTable			*_observers;
	dispatch_queue_t	_externalQueue;
}

@end



/*
** TCBuddy
*/
#pragma mark - TCBuddy

@implementation TCBuddy


/*
** TCBuddy - Instance
*/
#pragma mark - TCBuddy - Instance

+ (void)initialize
{
	[self registerInfoDescriptors];
}

- (instancetype)initWithCoreManager:(TCCoreManager *)core configuration:(id <TCConfigCore>)configuration identifier:(NSString *)identifier alias:(nullable NSString *)alias notes:(nullable NSString *)notes
{
	self = [super init];
	
	if (self)
	{
		NSAssert(core, @"core is nil");
		NSAssert(configuration, @"configuration is nil");
		NSAssert(identifier, @"identifier is nil");
		
		// Hold parameters.
		_coreManager = core;
		_config = configuration;
		
		_alias = alias;
		_identifier = identifier;
		_notes = notes;
		
		TCDebugLog(@"Buddy (%@) - New", _identifier);
		
		// Build queue
		_localQueue = dispatch_queue_create("com.torchat.core.buddy.local", DISPATCH_QUEUE_SERIAL);
		_externalQueue = dispatch_queue_create("com.torchat.core.buddy.external", DISPATCH_QUEUE_SERIAL);
		
		dispatch_queue_set_specific(_localQueue, &gQueueIdentityKey, &gLocalQueueContext, NULL);
		
		// Create containers.
		_fsend = [[NSMutableDictionary alloc] init];
		_freceive = [[NSMutableDictionary alloc] init];
		
		_messages = [[NSMutableArray alloc] init];

		_observers = [NSHashTable weakObjectsHashTable];
		
		// Create parser.
		_parser = [[TCParser alloc] initWithParsingResult:self];
		_parser.delegate = self;
		
		// Init status
		_socksstate = socks_nostate;
		_status = TCStatusOffline;
		
		// Init profiles
		_profileName = [_config buddyLastNameForBuddyIdentifier:_identifier];
		_profileText = [_config buddyLastTextForBuddyIdentifier:_identifier];
		_profileAvatar = [_config buddyLastAvatarForBuddyIdentifier:_identifier];
		
		// Init remotes
		_peerClient = @"";
		_peerVersion = @"";
		
		// Generate random
		char	rnd[101];
		char	charset[] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
		size_t	i;
		size_t	index;
				
		for (i = 0; i < sizeof(rnd) - 1; i++)
		{
			index = arc4random_uniform(sizeof(charset) - 1);
			rnd[i] = charset[index];
		}
		
		rnd[100] = '\0';
		
		_random = [[NSString alloc] initWithCString:rnd encoding:NSASCIIStringEncoding];
		
		TCDebugLog(@"Buddy (%@) - Random: %s", _identifier, rnd);
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCBuddy dealloc");
	
	[_outSocket setDelegate:nil];
	[_outSocket stop];
	
	[_inSocket setDelegate:nil];
	[_inSocket stop];
}


/*
** TCBuddy - Run
*/
#pragma mark - Run

- (void)start
{
	dispatch_async(_localQueue, ^{
		
		if (_running || _blocked)
			return;
		
		TCDebugLog(@"Buddy (%@) - Start", _identifier);
		
		_running = YES;

		[self _startConnection];
	});
}

- (void)stopWithCompletionHandler:(nullable dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	if (!handler)
		handler = ^{ };
	
	dispatch_group_async(group, _localQueue, ^{
		[self _stopChannel:TCBuddyChannelIn terminal:YES];
	});
	
	dispatch_group_notify(group, _externalQueue, handler);
}

- (void)_stopChannel:(TCBuddyChannel)channel terminal:(BOOL)terminal
{
	// > localQueue <
	
	if (!_running)
		return;
	
	// Stop keep-alive timer.
	if (_keepAliveTimer)
	{
		dispatch_source_cancel(_keepAliveTimer);
		_keepAliveTimer = nil;
	}
	
	// Stop pending timer.
	if (_pendingConnectTimer)
	{
		dispatch_source_cancel(_pendingConnectTimer);
		_pendingConnectTimer = nil;
	}
	
	// Stop channel.
	switch (channel)
	{
		case TCBuddyChannelIn:
		{
			// Stop in socket.
			if (_inSocket)
			{
				[_inSocket setDelegate:nil];
				[_inSocket stop];
				
				_inSocket = nil;
			}
			
			// Stop out socket (stopping in imply stopping out).
			if (_outSocket)
			{
				[_outSocket setDelegate:nil];
				[_outSocket stop];
				
				_outSocket = nil;
			}
			
			// Clean receive session.
			[_freceive removeAllObjects];
			
			// Clean send session.
			[_fsend removeAllObjects];
			
			// Reset status & flags.
			TCStatus lstatus = [self _status];
			
			_status = TCStatusOffline;
			_socksstate = socks_nostate;
			_ponged = NO;
			_pingRandom = nil;
			_pingHandled = NO;
			
			// Notify
			if (lstatus != [self _status])
				[self _notify:TCBuddyEventStatus context:@([self _status])];
			
			[self _notify:TCBuddyEventDisconnected];
			
			break;
		}
			
		case TCBuddyChannelOut:
		{
			if (_ponged)
			{
				[self _stopChannel:TCBuddyChannelIn terminal:terminal];
				return;
			}
			
			// Stop out socket.
			if (_outSocket)
			{
				[_outSocket setDelegate:nil];
				[_outSocket stop];
				
				_outSocket = nil;
			}
			
			// Reset socks stat.
			_socksstate = socks_nostate;
			
			break;
		}
	}
	
	// Handle terminal stop.
	if (terminal)
	{
		_running = NO;
	}
	else
	{
		// Reschedule.
		_pendingConnectTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
		
		dispatch_source_set_timer(_pendingConnectTimer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 1 * NSEC_PER_SEC);
		
		dispatch_source_set_event_handler(_pendingConnectTimer, ^{
			[self _startConnection];
		});
		
		dispatch_resume(_pendingConnectTimer);
	}
}

- (BOOL)isRunning
{
	__block BOOL result = false;
	
	dispatch_sync(_localQueue, ^{
		result = _running;
	});
	
	return result;
}

- (BOOL)isPonged
{
	__block BOOL result = false;
	
	dispatch_sync(_localQueue, ^{
		result = _ponged;
	});
	
	return result;
}



/*
** TCBuddy - Properties
*/
#pragma mark - Properties

- (nullable NSString *)alias
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = _alias;
	});
	
	return result;
}

- (void)setAlias:(nullable NSString *)name
{
	dispatch_async(_localQueue, ^{
		
		// Set the new name in config
		[_config setBuddyAlias:name forBuddyIdentifier:_identifier];
		
		// Change the name internaly
		_alias = name;
		
		// Notidy of the change
		[self _notify:TCBuddyEventAlias context:name];
	});
}

- (nullable NSString *)notes
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = _notes;
	});
	
	return result;
}

- (void)setNotes:(nullable NSString *)notes
{
	dispatch_async(_localQueue, ^{
		
		// Set the new name in config
		[_config setBuddyNotes:notes forBuddyIdentifier:_identifier];
		
		// Change the name internaly
		_notes = notes;
		
		// Notify of the change
		[self _notify:TCBuddyEventNotes context:_notes];

	});
}

- (BOOL)blocked
{
	// Prevent dead-lock
	if (dispatch_get_specific(&gQueueIdentityKey) == &gLocalQueueContext)
	{
		return _blocked;
	}
	else
	{
		__block bool isblocked = false;
		
		dispatch_sync(_localQueue, ^{
			isblocked = _blocked;
		});
		
		return isblocked;
	}
}

- (void)setBlocked:(BOOL)blocked
{
	dispatch_async(_localQueue, ^{
		_blocked = blocked;
	});
}

- (TCStatus)status
{
	__block TCStatus res = TCStatusOffline;
	
	dispatch_sync(_localQueue, ^{
		
		if (_ponged)
			res = _status;
		else
			res = TCStatusOffline;
	});
	
	return res;
}

- (NSString *)identifier
{
	return _identifier;
}

- (NSString *)random
{
	return _random;
}


- (NSString *)peerClient
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = _peerClient;
	});
	
	return result;
}

- (NSString *)peerVersion
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = _peerVersion;
	});
	
	return result;
}

- (nullable NSString *)profileText
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = _profileText;
	});
	
	return result;
}

- (nullable TCImage *)profileAvatar
{
	__block TCImage *result;
	
	dispatch_sync(_localQueue, ^{
		result = _profileAvatar;
	});
	
	return result;
}

- (nullable NSString *)profileName
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = _profileName;
	});
	
	return result;
}

- (nullable NSString *)finalName
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		
		if (_alias.length > 0)
			result = _alias;
		else
			result = _profileName;
	});
	
	return result;
}



/*
** TCBuddy - Files Info
*/
#pragma mark - Files Info

- (nullable NSString *)fileNameForTransferUUID:(NSString *)uuid transferDirection:(TCBuddyFileTransferDirection)direction
{
	NSAssert(uuid, @"uuid is nil");
	
	__block NSString *res = nil;
	
	dispatch_sync(_localQueue, ^{
		
		if (direction == TCBuddyFileTransferDirectionSend)
		{
			TCFileSend *file = _fsend[uuid];
			
			if (file)
				res = file.fileName;
		}
		else if (direction == TCBuddyFileTransferDirectionReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
				res = file.fileName;
		}
	});
	
	return res;
}

- (nullable NSString *)filePathForTransferUUID:(NSString *)uuid transferDirection:(TCBuddyFileTransferDirection)direction
{
	NSAssert(uuid, @"uuid is nil");
	
	__block NSString *res = nil;
	
	dispatch_sync(_localQueue, ^{
		
		if (direction == TCBuddyFileTransferDirectionSend)
		{
			TCFileSend *file = _fsend[uuid];
			
			res = file.filePath;
		}
		else if (direction == TCBuddyFileTransferDirectionReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
				res = file.filePath;
		}
	});
	
	return res;
}

- (BOOL)transferStatForTransferUUID:(NSString *)uuid transferDirection:(TCBuddyFileTransferDirection)direction done:(uint64_t *)done total:(uint64_t *)total
{
	NSAssert(uuid, @"uuid is nil");
	
	__block BOOL		result = false;
	__block uint64_t	rdone = 0;
	__block uint64_t	rtotal = 0;
	
	dispatch_sync(_localQueue, ^{
		
		if (direction == TCBuddyFileTransferDirectionSend)
		{
			// Search the file send
			TCFileSend *file = _fsend[uuid];
			
			if (file)
			{
				rdone = [file validatedSize];
				rtotal = file.fileSize;
				
				result = true;
			}
		}
		else if (direction == TCBuddyFileTransferDirectionReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
			{
				rdone = [file receivedSize];
				rtotal = file.fileSize;
				
				result = true;
			}
		}
	});
	
	// Give values
	if (done)
		*done = rdone;
	
	if (total)
		*total = rtotal;
	
	// Return result
	return result;
}

- (void)cancelTransferForTransferUUID:(NSString *)uuid transferDirection:(TCBuddyFileTransferDirection)direction
{
	NSAssert(uuid, @"uuid is nil");
	
	dispatch_async(_localQueue, ^{
		
		if (direction == TCBuddyFileTransferDirectionSend)
		{
			// Search the file send
			TCFileSend *file = _fsend[uuid];
			
			if (file)
			{
				// Say to the remote peer to stop receiving data
				[self _sendFileStopReceiving:uuid];
				
				// Notify that we stop sending the file
				TCFileInfo *info = [[TCFileInfo alloc] initWithFileSend:file];
				
				[self _notify:TCBuddyEventFileSendStopped context:info];
				
				// Release file
				[_fsend removeObjectForKey:uuid];
			}
		}
		else if (direction == TCBuddyFileTransferDirectionReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
			{
				// Say to the remote peer to stop sending data
				[self _sendFileStopSending:uuid];
				
				// Notify that we stop sending the file
				TCFileInfo *info = [[TCFileInfo alloc] initWithFileReceive:file];

				[self _notify:TCBuddyEventFileReceiveStopped context:info];

				// Release file
				[_freceive removeObjectForKey:uuid];
			}
		}
	});
}



/*
** TCBuddy - Messages
*/
#pragma mark - Messages

- (NSArray *)popMessages
{
	__block NSArray *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _messages;
		_messages = [[NSMutableArray alloc] init];
	});
	
	return result;
}



/*
** TCBuddy - Send Command
*/
#pragma mark - Send Command

- (void)sendStatus:(TCStatus)status
{
	dispatch_async(_localQueue, ^{
		
		// Send status only if we are ponged
		if (_ponged && !_blocked)
			[self _sendStatus:status];
	});
}

- (void)sendAvatar:(nullable TCImage *)avatar
{
	if (!avatar)
		avatar = [[TCImage alloc] initWithWidth:64 height:64];
	
	dispatch_async(_localQueue, ^{
		
		if (_ponged && !_blocked)
			[self _sendAvatar:avatar];
	});
}

- (void)sendProfileName:(nullable NSString *)name
{
	if (!name)
		name = @"";
	
	dispatch_async(_localQueue, ^{
		
		if (_ponged && !_blocked)
			[self _sendProfileName:name];
	});
}

- (void)sendProfileText:(nullable NSString *)text
{
	if (!text)
		text = @"";
		
	dispatch_async(_localQueue, ^{
		
		if (_ponged && !_blocked)
			[self _sendProfileText:text];
	});
}

- (void)sendMessage:(NSString *)message completionHanndler:(void (^)(SMInfo *info))handler
{
	NSAssert(message, @"message is nil");
	
	dispatch_async(_localQueue, ^{
		
		SMInfo *err = nil;
		
		if (_blocked)
			err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:TCBuddyErrorMessageBlocked context:message];
		else
		{
			// Send Message only if we sent pong and we are ponged
			if (_ponged)
				[self _sendCommand:@"message" string:message channel:TCBuddyChannelOut];
			else
				err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:TCBuddyErrorMessageOffline context:message];
		}
		
		// Notify user.
		dispatch_async(_externalQueue, ^{
			handler(err);
		});
	});
}

- (void)sendFileAtPath:(NSString *)filepath
{
	NSAssert(filepath, @"filepath is nil");

	dispatch_async(_localQueue, ^{
		
		// Create a file to send.
		TCFileSend *file = [[TCFileSend alloc] initWithFilePath:filepath];
		
		if (!file)
		{
			[self _error:TCBuddyErrorSendFile context:filepath];
			return;
		}
		
		// Send file.
		[self _sendFile:file];
	});
}

- (void)sendFileWithData:(NSData *)data filename:(NSString *)filename
{
	NSAssert(data, @"data is nil");
	NSAssert(filename, @"filename is nil");

	dispatch_async(_localQueue, ^{
		
		// Create a virtual file to send.
		TCFileSend *file = [[TCFileSend alloc] initWithFileData:data fileName:filename];
		
		// Send file.
		[self _sendFile:file];
	});
}

- (void)_sendFile:(TCFileSend *)file
{
	// > localQueue <
	
	NSAssert(file, @"file is nil");
	
	// Don't send file if buddy is not ponged.
	if (!_ponged)
	{
		[self _error:TCBuddyErrorFileOffline context:file.fileName];
		return;
	}
	
	// Don't send file if buddy is blocked.
	if (_blocked)
	{
		[self _error:TCBuddyErrorFileBlocked context:file.fileName];
		return;
	}
	
	// Insert the new file session
	_fsend[file.uuid] = file;
	
	// Notify
	TCFileInfo *info = [[TCFileInfo alloc] initWithFileSend:file];
	
	[self _notify:TCBuddyEventFileSendStart context:info];
	
	// Start the file session
	[self _sendFileName:file];
	
	// Send the first block to start the send
	[self _sendFileData:file];
}



/*
** TCBuddy - Action
*/
#pragma mark - Action

- (void)handlePingWithRandomToken:(NSString *)remoteRandom
{
	NSAssert(remoteRandom, @"remoteRandom is nil");
	
	dispatch_async(_localQueue, ^{
		
		if (_blocked)
			return;
		
		_pingRandom = remoteRandom;
		
		[self _handlePendingPing];
	});
}

- (void)handlePongWithSocket:(SMSocket *)sock
{
	NSAssert(sock, @"sock is nil");

	dispatch_async(_localQueue, ^{
		
		if (_blocked)
		{
			[sock stop];
		}
		else
		{
			// Activate send message & send file commands
			_ponged = YES;
			
			// Use this incomming connection
			if (_inSocket)
			{
				_inSocket.delegate = nil;
				[_inSocket stop];
			}
			
			_inSocket = sock;
			_inSocket.delegate = self;
			
			[_inSocket setGlobalOperation:SMSocketOperationLine size:0 tag:0];
			
			// Notify that we are ready
			[self _notify:TCBuddyEventIdentified];
		}
	});
}



/*
** TCBuddy - Observers
*/
#pragma mark - Observers

- (void)addObserver:(id <TCBuddyObserver>)observer
{
	NSAssert(observer, @"observer is nil");
	
	dispatch_async(_localQueue, ^{
		[_observers addObject:observer];
	});
}

- (void)removeObserver:(id <TCBuddyObserver>)observer
{
	dispatch_async(_localQueue, ^{
		[_observers removeObject:observer];
	});
}



/*
** TCBuddy - SMSocketDelegate
*/
#pragma mark - SMSocketDelegate

- (void)socket:(SMSocket *)socket operationAvailable:(SMSocketOperation)operation tag:(NSUInteger)tag content:(id)content
{
	dispatch_async(_localQueue, ^{
		
		if (_blocked)
			return;
		
		if (operation == SMSocketOperationData)
		{
			// Get the reply
			NSData			*data = content;
			struct sockrep	*thisrep = (struct sockrep *)(data.bytes);
			
			// Check result
			switch (thisrep->result)
			{
				case 90: // Socks v4 protocol finish
				{
					_socksstate = socks_finish;
					
					[_outSocket setGlobalOperation:SMSocketOperationLine size:0 tag:0];
					
					// Notify connected.
					[self _notify:TCBuddyEventConnectedBuddy];
					
					// Proxy connected. Interract with remote.
					[self _connectedSocks];
					
					break;
				}
					
				case 91:
				case 92:
				case 93:
					[self _error:TCBuddyErrorSocks context:@(thisrep->result) info:nil channel:TCBuddyChannelOut];
					break;
				
				default:
					[self _error:TCBuddyErrorSocks context:nil info:nil channel:TCBuddyChannelOut];
					break;
			}
		}
		else if (operation == SMSocketOperationLine)
		{
			NSArray *lines = content;
			
			for (NSData *line in lines)
			{
				dispatch_async(_localQueue, ^{
					
					// Parse the line
					[_parser parseLine:line];
				});
			}
		}
	});
}

- (void)socket:(SMSocket *)socket error:(SMInfo *)error
{
	dispatch_async(_localQueue, ^{
		if (socket == _inSocket)
			[self _error:TCBuddyErrorSocket context:nil info:error channel:TCBuddyChannelIn];
		else if (socket == _outSocket)
			[self _error:TCBuddyErrorSocket context:nil info:error channel:TCBuddyChannelOut];
	});
}

- (void)socketRunPendingWrite:(SMSocket *)socket
{
	dispatch_async(_localQueue, ^{
		[self _runPendingFileWrite];
	});
}


/*
** TCBuddy - TCParserDelegate & TCParserCommand
*/
#pragma mark - TCParserDelegate & TCParserCommand

- (void)parser:(TCParser *)parser parsedPingWithIdentifier:(NSString *)identifier random:(NSString *)random
{
	// not-implemented
}

- (void)parser:(TCParser *)parser parsedPongWithRandom:(NSString *)random
{
	// not-implemented
}

- (void)parser:(TCParser *)parser parsedStatus:(NSString *)status
{
	// > localQueue <
	
	if (_blocked)
		return;
	
	TCStatus nstatus = TCStatusOffline;
	
	if ([status isEqualToString:@"available"])
		nstatus = TCStatusAvailable;
	else if ([status isEqualToString:@"away"])
		nstatus = TCStatusAway;
	else if ([status isEqualToString:@"xa"])
		nstatus = TCStatusXA;
	
	// Notify that status changed.
	if (nstatus != _status)
	{
		_status = nstatus;
		[self _notify:TCBuddyEventStatus context:@([self _status])];
	}
}

- (void)parser:(TCParser *)parser parsedMessage:(NSString *)message
{
	// > localQueue <

	if (_blocked)
		return;
	
	if (message)
		[_messages addObject:message];
	
	// Notify it
	[self _notify:TCBuddyEventMessage context:message];
}

- (void)parser:(TCParser *)parser parsedVersion:(NSString *)version
{
	// > localQueue <

	if (_blocked)
		return;
	
	_peerVersion = version;
		
	// Notify it
	[self _notify:TCBuddyEventVersion context:version];
}

- (void)parser:(TCParser *)parser parsedClient:(NSString *)client
{
	// > localQueue <

	if (_blocked)
		return;
		
	_peerClient = client;
	
	// Notify it
	[self _notify:TCBuddyEventClient context:client];
}

- (void)parser:(TCParser *)parser parsedProfileText:(NSString *)text
{
	// > localQueue <

	if (_blocked)
		return;
	
	// Hold profile text.
	_profileText = text;
	
	// Store profile name.
	[_config setBuddyLastText:text forBuddyIdentifier:_identifier];
	
	// Notify it
	[self _notify:TCBuddyEventProfileText context:text];
}

- (void)parser:(TCParser *)parser parsedProfileName:(NSString *)name
{
	// > localQueue <
	if (_blocked)
		return;
	
	// Hold profile name.
	_profileName = name;
	
	// Store profile name.
	[_config setBuddyLastName:name forBuddyIdentifier:_identifier];
	
	// Notify it.
	[self _notify:TCBuddyEventProfileName context:name];
}

- (void)parser:(TCParser *)parser parsedProfileAvatar:(NSData *)bitmap
{
	// > localQueue <
	
	if (_blocked)
		return;
	
	// Hold & convert avatar.
	if (!_profileAvatar)
		_profileAvatar = [[TCImage alloc] initWithWidth:64 height:64];

	[_profileAvatar setBitmap:bitmap];
	
	// Store profile avatar.
	[_config setBuddyLastAvatar:_profileAvatar forBuddyIdentifier:_identifier];
	
	// Notify it.
	[self _notify:TCBuddyEventProfileAvatar context:_profileAvatar];
}

- (void)parser:(TCParser *)parser parsedProfileAvatarAlpha:(NSData *)bitmap
{
	// > localQueue <
	
	if (_blocked)
		return;

	if (!_profileAvatar)
		_profileAvatar = [[TCImage alloc] initWithWidth:64 height:64];

	[_profileAvatar setBitmapAlpha:bitmap];
}

- (void)parserParsedAddMe:(TCParser *)parser
{
	// > localQueue <

	/*
	 This must be sent after connection if you are (or want to be)
	 on the other's buddy list. Since a client can also connect for
	 the purpose of joining a chat room without automatically appearing
	 on the buddy list this message is needed.
	 */
	
	// -> I will not do this for this fork. In futur, perhaps.
}

- (void)parserparsedRemoveMe:(TCParser *)parser
{
	// > localQueue <

	/*
	 when receiving this message the buddy MUST be removed from
	 the buddy list (or somehow marked as removed) so that it will not
	 automatically add itself again and cause annoyance. When removing
	 a buddy first send this message before disconnecting or the other
	 client will never know about it and add itself again next time"""
	 */
	
	
	// -> I will not do this for this fork. In futur, perhaps.
}

- (void)parser:(TCParser *)parser parsedFileNameWithUUIDD:(NSString *)uuid fileSize:(NSString *)fileSize blockSize:(NSString *)blockSize fileName:(NSString *)filename
{
	// Check if we are blocked
	if (_blocked)
		return;
	
	// Quick check
	NSString *sfilename_1 = [filename stringByReplacingOccurrencesOfString:@".." withString:@"_"];
	NSString *sfilename_2 = [sfilename_1 stringByReplacingOccurrencesOfString:@"/" withString:@"_"];
	
	// Get the download folder
	NSString *downPath = [[_config pathForComponent:TCConfigPathComponentDownloads fullPath:YES] stringByAppendingPathComponent:_identifier];
	
	[[NSFileManager defaultManager] createDirectoryAtPath:downPath withIntermediateDirectories:YES attributes:nil error:nil];
	
	if ([downPath.lastPathComponent isEqualToString:@"Downloads"])
		[[NSData data] writeToFile:[downPath stringByAppendingPathComponent:@".localized"] atomically:NO];
	
	// Parse values
	uint64_t		ifsize = strtoull([fileSize cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
	uint64_t		ibsize = strtoull([blockSize cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
	TCFileReceive	*file;
	
	// Build a receiver instance
	file = [[TCFileReceive alloc] initWithUUID:uuid folder:downPath fileName:sfilename_2 fileSize:ifsize blockSiz:ibsize];
	
	if (!file)
	{
		[self _error:TCBuddyErrorReceiveFile];
		return;
	}
	
	// Add it to the list
	_freceive[file.uuid] = file;
		
	TCFileInfo *info = [[TCFileInfo alloc] initWithFileReceive:file];
		
	[self _notify:TCBuddyEventFileReceiveStart context:info];
}

- (void)parser:(TCParser *)parser parsedFileDataWithUUID:(NSString *)uuid start:(NSString *)start hash:(NSString *)hash data:(NSData *)data
{
	// > localQueue <
	
	/*
	 TorChat protocol is based on text token protocol ("filedata", "filedata_ok", space separator, etc.).
	 TorChat Python use text function for this text protocol ("join", "split", "replace", etc.)
	 
	 If TorChat is well designed, the protocol _underlayer_ is not. Indeed, raw file data are sent
	 without encoding in this text protocol.
	 
	 When TorChat (Python) ask Python to do some text work on this data (like "replace"), Python try to
	 interpret them as UTF8 string before doing the job. On some rare case, when data contain a sequence
	 looking like UTF8 sequence but invalid, this interpretation fail and raise an un-handled exception.
	 */
	
	// Check if we are blocked
	if (_blocked)
		return;
	
	// Manage file chunk
	TCFileReceive *file = _freceive[uuid];
		
	if (file)
	{
		uint64_t offset = strtoull([start cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
		
		if ([file writeChunk:data.bytes chunkSize:data.length hash:hash offset:&offset])
		{
			// Send that this chunk is okay
			[self _sendFileDataOk:uuid start:offset];
			
			// Notify of the new chunk
			TCFileInfo *info = [[TCFileInfo alloc] initWithFileReceive:file];
			
			[self _notify:TCBuddyEventFileReceiveRunning context:info];
			
			// Do nothing if we are no more to send
			if ([file isFinished])
			{
				// Notify that we have finished
				[self _notify:TCBuddyEventFileReceiveFinish context:info];

				// Release file
				[_freceive removeObjectForKey:uuid];
			}
		}
		else
		{
			[self _sendFileDataError:uuid start:offset];
		}
	}
	else
	{
		[self _sendFileStopSending:uuid];
	}
}

- (void)parser:(TCParser *)parser parsedFileDataOkWithUUID:(NSString *)uuid start:(NSString *)start
{
	// > localQueue <

	// Check if we are blocked
	if (_blocked)
		return;

	TCFileSend *file = _fsend[uuid];
	
	if (file)
	{
		uint64_t offset = strtoull([start cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
		
		// Inform that this offset was validated
		[file setValidatedOffset:offset];
		
		// Notice the advancing
		TCFileInfo *info = [[TCFileInfo alloc] initWithFileSend:file];
				
		[self _notify:TCBuddyEventFileSendRunning context:info];

		// Do nothing if we are no more to send
		if ([file isFinished])
		{
			// Notify
			[self _notify:TCBuddyEventFileSendFinish context:info];

			// Release the file
			[_fsend removeObjectForKey:uuid];
		}
		else
			[self _runPendingFileWrite];

	}
	else
	{
		[self _sendFileStopReceiving:uuid];
	}

}

- (void)parser:(TCParser *)parser parsedFileDataErrorWithUUID:(NSString *)uuid start:(NSString *)start
{
	// > localQueue <
	
	// Check if we are blocked
	if (_blocked)
		return;

	// Manage file chunk
	TCFileSend *file = _fsend[uuid];
		
	if (file)
	{
		uint64_t offset = strtoull([start cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
		
		// Set the position where we should re-send
		[file setNextChunkOffset:offset];
		
		// Try resending.
		[self _runPendingFileWrite];
	}
	else
	{
		[self _sendFileStopReceiving:uuid];
	}
}

- (void)parser:(TCParser *)parser parsedFileStopSendingWithUUID:(NSString *)uuid
{
	// > localQueue <

	// Check if we are blocked
	if (_blocked)
		return;
		
	// Get file session.
	TCFileSend *file = _fsend[uuid];
	
	if (!file)
		return;
	
	// Notify that we stop sending the file
	TCFileInfo *info = [[TCFileInfo alloc] initWithFileSend:file];
		
	[self _notify:TCBuddyEventFileSendStopped context:info];
		
	// Release file
	[_fsend removeObjectForKey:uuid];
}

- (void)parser:(TCParser *)parser parsedFileStopReceivingWithUUID:(NSString *)uuid
{
	// > localQueue <
	
	// Check if we are blocked
	if (_blocked)
		return;
	
	// Manage file chunk
	TCFileReceive *file = _freceive[uuid];
	
	if (!file)
		return;
	
	// Notify that we stop receiving the file
	TCFileInfo *info = [[TCFileInfo alloc] initWithFileReceive:file];

	[self _notify:TCBuddyEventFileReceiveStopped context:info];
	
	// Release file
	[_freceive removeObjectForKey:uuid];
}

- (void)parser:(TCParser *)parser errorWithErrorCode:(TCParserError)error errorInformation:(NSString *)information
{
	if (_blocked)
		return;
	
	// Don't get parse error on blocked buddy (prevent spam, etc.)
	SMInfo *info = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:error context:information];
		
	[self _error:TCBuddyErrorParse info:info];
}




/*
** TCBuddy - Send Low Command
*/
#pragma mark - Send Low Command

- (void)_sendPing:(NSString *)identifier random:(NSString *)random
{
	// > localQueue <
	
	NSAssert(identifier, @"identifier is nil");
	NSAssert(random, @"random is nil");

	NSMutableArray *items = [[NSMutableArray alloc] init];
	
	[items addObject:identifier];
	[items addObject:random];

	[self _sendCommand:@"ping" array:items channel:TCBuddyChannelOut];
}

- (void)_sendPong:(NSString *)random
{
	// > localQueue <
	
	if (random.length == 0)
		return;
	
	[self _sendCommand:@"pong" string:random channel:TCBuddyChannelOut];
}

- (void)_sendVersion:(NSString *)version
{
	// > localQueue <
	
	NSAssert(version, @"version is nil");

	[self _sendCommand:@"version" string:version channel:TCBuddyChannelOut];
}

- (void)_sendClient:(NSString *)client
{
	// > localQueue <
	
	NSAssert(client, @"client is nil");

	[self _sendCommand:@"client" string:client channel:TCBuddyChannelOut];
}

- (void)_sendProfileName:(NSString *)name
{
	// > localQueue <
	
	NSAssert(name, @"name is nil");

	[self _sendCommand:@"profile_name" string:name channel:TCBuddyChannelOut];
}

- (void)_sendProfileText:(NSString *)text
{
	// > localQueue <
	
	NSAssert(text, @"text is nil");
	
	[self _sendCommand:@"profile_text" string:text channel:TCBuddyChannelOut];
}

- (void)_sendAvatar:(TCImage *)avatar
{
	// > localQueue <
	
	NSAssert(avatar, @"avatar is nil");

	if ([avatar bitmapAlpha])
	{
		NSData *data = [avatar bitmapAlpha];
		
		if (data)
			[self _sendCommand:@"profile_avatar_alpha" data:data channel:TCBuddyChannelOut];
	}
	
	if ([avatar bitmap])
	{
		NSData *data = [avatar bitmap];

		[self _sendCommand:@"profile_avatar" data:data channel:TCBuddyChannelOut];
	}
	else
		[self _sendCommand:@"profile_avatar" channel:TCBuddyChannelOut];
}

- (void)_sendAddMe
{
	// > localQueue <
	
	[self _sendCommand:@"add_me" channel:TCBuddyChannelOut];
}

- (void)_sendRemoveMe
{
	// not-implemented
}

- (void)_sendStatus:(TCStatus)status
{
	// > localQueue <
	
	_cstatus = status;
	
	switch (status)
	{
		case TCStatusOffline:
			return;
			
		case TCStatusAvailable:
			[self _sendCommand:@"status" string:@"available" channel:TCBuddyChannelOut];
			break;
			
		case TCStatusAway:
			[self _sendCommand:@"status" string:@"away" channel:TCBuddyChannelOut];
			break;
			
		case TCStatusXA:
			[self _sendCommand:@"status" string:@"xa" channel:TCBuddyChannelOut];
			break;
	}
}

- (void)_sendMessage:(NSString *)message
{
	// > localQueue <

	[self _sendCommand:@"message" string:message channel:TCBuddyChannelOut];
}

- (void)_sendFileName:(TCFileSend *)file
{
	// > localQueue <
	
	NSAssert(file, @"file is nil");
	
	NSMutableArray *items = [[NSMutableArray alloc] init];
		
	// Add the uuid
	[items addObject:file.uuid];
	
	// Add the file size
	[items addObject:[NSString stringWithFormat:@"%llu", file.fileSize]];
	
	// Add the block size
	[items addObject:[NSString stringWithFormat:@"%u", file.blockSize]];
	
	// Add the filename
	[items addObject:file.fileName];

	// Send the command
	[self _sendCommand:@"filename" array:items channel:TCBuddyChannelIn];
}

- (void)_sendFileData:(TCFileSend *)file
{
	// > localQueue <
	
	NSAssert(file, @"file is nil");
	
	if ([file readSize] >= file.fileSize)
		return;
	
	uint8_t		*chunk = malloc(file.blockSize);
	uint64_t	chunksz = 0;
	uint64_t	offset = 0;
	NSString	*md5;
	
	// Read chunk of data.
	md5 = [file readChunk:chunk chunkSize:&chunksz fileOffset:&offset];
	
	if (!md5)
	{
		free(chunk);
		return;
	}

	// Build command.
	NSMutableArray *items = [[NSMutableArray alloc] init];
	
	// > Add UUID
	[items addObject:file.uuid];
	
	// > Add the offset
	[items addObject:[NSString stringWithFormat:@"%llu", offset]];

	// > Add the MD5
	[items addObject:md5];

	// > Add the data
	[items addObject:[[NSData alloc] initWithBytesNoCopy:chunk length:(NSUInteger)chunksz freeWhenDone:YES]];
	
	// Send the command
	[self _sendCommand:@"filedata" array:items channel:TCBuddyChannelIn];
}

- (void)_sendFileDataOk:(NSString *)uuid start:(uint64_t)start
{
	// > localQueue <
	
	// Build command.

	NSMutableArray *items = [[NSMutableArray alloc] init];
	
	// > Add UUID
	[items addObject:uuid];
	
	// > Add the offset
	[items addObject:[NSString stringWithFormat:@"%llu", start]];
	
	// Send the command
	[self _sendCommand:@"filedata_ok" array:items channel:TCBuddyChannelOut];
}

- (void)_sendFileDataError:(NSString *)uuid start:(uint64_t)start
{
	// > localQueue <
		
	// Build command.
	NSMutableArray *items = [[NSMutableArray alloc] init];
	
	// > Add UUID
	[items addObject:uuid];
	
	// Add the offset
	[items addObject:[NSString stringWithFormat:@"%llu", start]];
	
	// Send the command
	[self _sendCommand:@"filedata_error" array:items channel:TCBuddyChannelOut];
}

- (void)_sendFileStopSending:(NSString *)uuid
{
	// > localQueue <
	
	[self _sendCommand:@"file_stop_sending" string:uuid channel:TCBuddyChannelOut];
}

- (void)_sendFileStopReceiving:(NSString *)uuid
{
	// > localQueue <
	
	[self _sendCommand:@"file_stop_receiving" string:uuid channel:TCBuddyChannelOut];
}



/*
** TCBuddy - Send Command Data
*/
#pragma mark - Send Command Data

- (BOOL)_sendCommand:(NSString *)command channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	return [self _sendCommand:command data:nil channel:channel];
}

- (BOOL)_sendCommand:(NSString *)command array:(NSArray *)data channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	// Render data.
	NSData *rdata = nil;
	
	if (data)
	{
		rdata = [data joinWithCStr:" "];
		
		if (!rdata)
			return NO;
	}
	
	// Send the command
	return [self _sendCommand:command data:rdata channel:channel];
}

- (BOOL)_sendCommand:(NSString *)command string:(NSString *)data channel:(TCBuddyChannel)channel
{
	return [self _sendCommand:command data:[data dataUsingEncoding:NSUTF8StringEncoding] channel:channel];
}

- (BOOL)_sendCommand:(NSString *)command data:(nullable NSData *)data channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	NSAssert(command, @"command is nil");
	
	if (_socksstate != socks_finish)
		return NO;
	
	// -- Build the command line --
	NSMutableData	*part = [[NSMutableData alloc] init];
	NSData			*commandData = [command dataUsingEncoding:NSASCIIStringEncoding];
	
	if (!commandData)
		return NO;
	
	[part appendData:commandData];
	
	if (data.length > 0)
	{
		[part appendBytes:" " length:1];
		[part appendData:(NSData *)data];
	}
	
	// Escape protocol special chars
	[part replaceCStr:"\\" withCStr:"\\/"];
	[part replaceCStr:"\n" withCStr:"\\n"];
	

	// Add end line.
	[part appendBytes:"\n" length:1];
	
	// Send the command.
	[self _sendData:part channel:channel];
	
	return YES;
}

- (BOOL)_sendData:(NSData *)data channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	return [self _sendBytes:data.bytes length:data.length channel:channel];
}

- (BOOL)_sendBytes:(const void *)bytes length:(NSUInteger)length channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	NSAssert(bytes, @"bytes is NULL");
	NSAssert(length > 0, @"length is zero");
	
	if (channel == TCBuddyChannelIn && _inSocket)
		[_inSocket sendBytes:bytes size:length copy:YES];
	else if (channel == TCBuddyChannelOut && _outSocket)
		[_outSocket sendBytes:bytes size:length copy:YES];
	else
		return NO;
	
	return YES;
}



/*
** TCBuddy - Network Helper
*/
#pragma mark - Network Helper

- (void)_startConnection
{
	// > localQueue <
	
	if (_running == NO)
		return;
	
	// Make a connection to Tor proxy.
	struct addrinfo	hints, *res, *res0;
	int				error;
	int				s = -1;
	char			sport[50];
	
	memset(&hints, 0, sizeof(hints));
	
	snprintf(sport, sizeof(sport), "%i", [_config torPort]);
	
	// > Configure the resolver
	hints.ai_family = PF_UNSPEC;
	hints.ai_socktype = SOCK_STREAM;
	
	// > Try to resolve and connect to the given address
	error = getaddrinfo(_config.torAddress.UTF8String, sport, &hints, &res0);
	
	if (error)
	{
		[self _error:TCBuddyErrorResolveTor context:nil info:nil channel:TCBuddyChannelOut];
		return;
	}
	
	for (res = res0; res; res = res->ai_next)
	{
		if ((s = socket(res->ai_family, res->ai_socktype, res->ai_protocol)) < 0)
			continue;
		
		if (connect(s, res->ai_addr, res->ai_addrlen) < 0)
		{
			close(s);
			s = -1;
			
			continue;
		}
		
		break;
	}
	
	freeaddrinfo(res0);
	
	if (s < 0)
	{
		[self _error:TCBuddyErrorConnectTor context:nil info:nil channel:TCBuddyChannelOut];
		return;
	}
	
	// > Build a socket with this descriptor
	_outSocket = [[SMSocket alloc] initWithSocket:s];
	
	// > Set ourself as delegate
	_outSocket.delegate = self;
	
	// Send SOCKS 4a request.
	const char			*user = "torchat";
	struct sockreq		*thisreq;
	char				*buffer;
	size_t				datalen;
	
	// > Get the target connexion informations
	NSString	*host = [_identifier stringByAppendingString:@".onion"];
	const char	*c_host = host.UTF8String;
	
	// > Check data size
	datalen = sizeof(struct sockreq) + strlen(user) + 1;
	datalen += strlen(c_host) + 1;
	
	buffer = (char *)malloc(datalen);
	thisreq = (struct sockreq *)buffer;
	
	// > Create the request
	thisreq->version = 4;
	thisreq->command = 1;
	thisreq->dstport = htons(TORCHAT_PORT);
	thisreq->dstip = htonl(0x00000042); // Socks v4a
	
	// > Copy the username
	strcpy((char *)thisreq + sizeof(struct sockreq), user);
	
	// > Socks v4a : set the host name if we cant resolve it
	char *pos = (char *)thisreq + sizeof(struct sockreq);
	
	pos += strlen(user) + 1;
	strcpy(pos, c_host);
	
	// > Set the next input operation
	[_outSocket scheduleOperation:SMSocketOperationData size:sizeof(struct sockrep) tag:socks_v4_reply];
	
	// > Send the request
	if ([self _sendBytes:buffer length:datalen channel:TCBuddyChannelOut])
		_socksstate = socks_running;
	else
		[self _error:TCBuddyErrorSocksRequest context:nil info:nil channel:TCBuddyChannelOut];
	
	free(buffer);
	
	// Notify.
	[self _notify:TCBuddyEventConnectedTor];
}

- (void)_connectedSocks
{
	// > localQueue <
	
	// Send ping.
	NSString *selfIdentifier = _config.selfIdentifier;

	if (selfIdentifier && _random)
		[self _sendPing:selfIdentifier random:_random];
	
	// Handle received ping, if we received one.
	[self _handlePendingPing];

	// Install keep-alive.
	if (_keepAliveTimer)
		dispatch_source_cancel(_keepAliveTimer);

	_keepAliveTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);

	dispatch_source_set_timer(_keepAliveTimer, DISPATCH_TIME_NOW, 120 * NSEC_PER_SEC, 12 * NSEC_PER_SEC);
	
	dispatch_source_set_event_handler(_keepAliveTimer, ^{
		if (_blocked == NO && _running && _ponged)
			[self _sendStatus:_cstatus];
	});
	
	dispatch_resume(_keepAliveTimer);
}

- (void)_runPendingWrite
{
	// > localQueue <
	
	// Try to send pending files send
	[self _runPendingFileWrite];
}

- (void)_runPendingFileWrite
{
	// > localQueue <
	
	// Send a block of each send file session
	for (NSString *uuid in _fsend)
	{
		TCFileSend *file = _fsend[uuid];
		
		if (([file readSize] - [file validatedSize]) >= 16 * file.blockSize)
			continue;
		
		[self _sendFileData:file];
	}
}


- (void)_handlePendingPing
{
	// > localQueue <
	
	if (_pingRandom == nil || _pingHandled || _socksstate != socks_finish)
		return;
	
	TCCoreManager *coreManager = _coreManager;
	
	if (!coreManager)
		return;
	
	_pingHandled = YES;

	// Pong.
	[self _sendPong:_pingRandom];
	
	// Torchat info.
	[self _sendClient:([_config clientName:TCConfigGetReal] ?: @"")];
	[self _sendVersion:([_config clientVersion:TCConfigGetReal] ?: @"")];
	
	// Profile.
	// > Name.
	NSString *profileName = coreManager.profileName;
	
	if (profileName)
		[self _sendProfileName:profileName];
	
	// > Text.
	NSString *profileText = coreManager.profileText;

	if (profileText)
		[self _sendProfileText:profileText];

	// > Avatar
	TCImage *img = coreManager.profileAvatar;

	if (img)
		[self _sendAvatar:img];
	
	// Add me.
	[self _sendAddMe];
	
	// Status.
	[self _sendStatus:coreManager.status];
}



/*
** TCBuddy - Helpers
*/
#pragma mark - Helpers

- (void)_error:(TCBuddyError)code context:(nullable id)context info:(nullable SMInfo *)info channel:(TCBuddyChannel)channel
{
	// > localQueue <

	// Notify error.
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code context:context info:info];
	
	[self _sendEvent:err];
	
	// Stop the channel.
	[self _stopChannel:channel terminal:NO];
}

- (void)_error:(TCBuddyError)code
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code];
	
	[self _sendEvent:err];
}

- (void)_error:(TCBuddyError)code context:(nullable id)ctx
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code context:ctx];

	[self _sendEvent:err];
}

- (void)_error:(TCBuddyError)code info:(SMInfo *)subInfo
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code info:subInfo];
	
	[self _sendEvent:err];
}

- (void)_notify:(TCBuddyEvent)notice
{
	// > localQueue <
	
	SMInfo *ifo = [SMInfo infoOfKind:SMInfoInfo domain:TCBuddyInfoDomain code:notice];
	
	[self _sendEvent:ifo];
}

- (void)_notify:(TCBuddyEvent)notice context:(nullable id)ctx
{
	// > localQueue <
	
	SMInfo *ifo = [SMInfo infoOfKind:SMInfoInfo domain:TCBuddyInfoDomain code:notice context:ctx];
	
	[self _sendEvent:ifo];
}

- (void)_sendEvent:(SMInfo *)info
{
	// > localQueue <
	
	NSAssert(info, @"info is nil");
	
	for (id <TCBuddyObserver> observer in _observers)
	{
		dispatch_async(_externalQueue, ^{
			[observer buddy:self information:info];
		});
	}
}

- (TCStatus)_status
{
	// > localQueue <
	
	TCStatus res;
	
	if (_ponged)
		res = _status;
	else
		res = TCStatusOffline;
	
	return res;
}



/*
** TCBuddy - Infos
*/
#pragma mark - TCBuddy - Infos

+ (void)registerInfoDescriptors
{
	NSMutableDictionary *descriptors = [[NSMutableDictionary alloc] init];
	
	// == TCBuddyInfoDomain ==
	descriptors[TCBuddyInfoDomain] = ^ NSDictionary * (SMInfoKind kind, int code) {
		
		switch (kind)
		{
			case SMInfoInfo:
			{
				switch ((TCBuddyEvent)code)
				{
					case TCBuddyEventConnectedTor:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventConnectedTor",
							SMInfoTextKey : @"core_bd_event_tor_connected",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventConnectedBuddy:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventConnectedBuddy",
							SMInfoTextKey : @"core_bd_event_connected",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventDisconnected:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventDisconnected",
							SMInfoTextKey : @"core_bd_event_stopped",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventIdentified:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventIdentified",
							SMInfoTextKey : @"core_bd_event_identified",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventStatus:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventStatus",
							SMInfoDynTextKey : ^ NSString *(NSNumber *context) {
									 
								NSString *status = @"-";
									 
								switch (context.intValue)
								{
									case TCStatusOffline:	status = NSLocalizedString(@"bd_status_offline", @""); break;
									case TCStatusAvailable: status = NSLocalizedString(@"bd_status_available", @""); break;
									case TCStatusAway:		status = NSLocalizedString(@"bd_status_away", @""); break;
									case TCStatusXA:		status = NSLocalizedString(@"bd_status_xa", @""); break;
								}
									 
								return [NSString stringWithFormat:NSLocalizedString(@"core_bd_event_status_changed", @""), status];
							},
							SMInfoLocalizableKey : @NO,
						};
					}
						
					case TCBuddyEventMessage:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventMessage",
							SMInfoTextKey : @"core_bd_event_new_message",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventAlias:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventAlias",
							SMInfoTextKey : @"core_bd_event_alias_changed",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventNotes:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventNotes",
							SMInfoTextKey : @"core_bd_event_notes_changed",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventVersion:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventVersion",
							SMInfoTextKey : @"core_bd_event_new_version",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventClient:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventClient",
							SMInfoTextKey : @"core_bd_event_new_client",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileSendStart:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileSendStart",
							SMInfoTextKey : @"core_bd_event_file_send_start",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileSendRunning:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileSendRunning",
							SMInfoTextKey : @"core_bd_event_file_chunk_send",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileSendFinish:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileSendFinish",
							SMInfoTextKey : @"core_bd_event_file_send_finish",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileSendStopped:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileSendStopped",
							SMInfoTextKey : @"core_bd_event_file_send_canceled",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileReceiveStart:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileReceiveStart",
							SMInfoTextKey : @"core_bd_event_file_receive_start",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileReceiveRunning:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileReceiveRunning",
							SMInfoTextKey : @"core_bd_event_file_chunk_receive",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileReceiveFinish:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileReceiveFinish",
							SMInfoTextKey : @"core_bd_event_file_receive_finish",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventFileReceiveStopped:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventFileReceiveStopped",
							SMInfoTextKey : @"core_bd_event_file_receive_stopped",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventProfileText:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventProfileText",
							SMInfoTextKey : @"core_bd_event_new_profile_text",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventProfileName:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventProfileName",
							SMInfoTextKey : @"core_bd_event_new_profile_name",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyEventProfileAvatar:
					{
						return @{
							SMInfoNameKey : @"TCBuddyEventProfileAvatar",
							SMInfoTextKey : @"core_bd_event_new_profile_avatar",
							SMInfoLocalizableKey : @YES,
						};
					}
				}
				break;
			}
				
			case SMInfoWarning:
			{
				break;
			}
				
			case SMInfoError:
			{
				switch ((TCBuddyError)code)
				{
					case TCBuddyErrorResolveTor:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorResolveTor",
							SMInfoTextKey : @"core_bd_error_tor_resolve",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorConnectTor:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorConnectTor",
							SMInfoTextKey : @"core_bd_error_tor_connect",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorSocket:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorSocket",
							SMInfoTextKey : @"core_bd_error_socket",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorSocks:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorSocks",
							SMInfoDynTextKey : ^ NSString *(NSNumber *context) {
								
								if (context.intValue == 91)
									return @"core_bd_error_socks_91";
								else if (context.intValue == 92)
									return @"core_bd_error_socks_92";
								else if (context.intValue == 93)
									return @"core_bd_error_socks_93";
								else
									return @"core_bd_error_socks_unknown";
							},
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorSocksRequest:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorSocksRequest",
							SMInfoTextKey : @"core_bd_error_socks_request",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorMessageOffline:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorMessageOffline",
							SMInfoTextKey : @"core_bd_error_message_offline",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorMessageBlocked:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorMessageBlocked",
							SMInfoTextKey : @"core_bd_error_message_blocked",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorSendFile:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorSendFile",
							SMInfoTextKey : @"core_bd_error_filesend",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorReceiveFile:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorReceiveFile",
							SMInfoTextKey : @"core_bd_error_filereceive",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorFileOffline:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorFileOffline",
							SMInfoTextKey : @"core_bd_error_file_offline",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorFileBlocked:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorFileBlocked",
							SMInfoTextKey : @"core_bd_error_file_blocked",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCBuddyErrorParse:
					{
						return @{
							SMInfoNameKey : @"TCBuddyErrorParse",
						};
					}
				}
				break;
			}
		}
		
		return nil;
	};
	
	[SMInfo registerDomainsDescriptors:descriptors localizer:^NSString * _Nonnull(NSString * _Nonnull token) {
		return NSLocalizedString(token, @"");
	}];
}

@end



/*
** TCFileInfo
*/
#pragma mark - TCFileInfo

@implementation TCFileInfo


/*
** TCFileInfo - Instance
*/
#pragma mark - TCFileInfo - Instance

- (instancetype)initWithFileSend:(TCFileSend *)sender
{
	self = [super init];
	
	if (self)
	{
		NSAssert(sender, @"sender is nil");
		
		_sender = sender;
	}
	
	return self;
}

- (instancetype)initWithFileReceive:(TCFileReceive *)receiver
{
	self = [super init];
	
	if (self)
	{
		NSAssert(receiver, @"receiver is nil");

		_receiver = receiver;
	}
	
	return self;
}


/*
** TCFileInfo - Properties
*/
#pragma mark - TCFileInfo - Properties

- (NSString *)uuid
{
	NSAssert(_receiver || _sender, @"need a receiver or a sender");
	
	if (_receiver)
		return _receiver.uuid;
	
	if (_sender)
		return _sender.uuid;
	
	return nil;
}

- (uint64_t)fileSizeCompleted
{
	NSAssert(_receiver || _sender, @"need a receiver or a sender");

	if (_receiver)
		return [_receiver receivedSize];
	
	if (_sender)
		return [_sender validatedSize];
	
	return 0;
}

- (uint64_t)fileSizeTotal
{
	NSAssert(_receiver || _sender, @"need a receiver or a sender");

	if (_receiver)
		return _receiver.fileSize;
	
	if (_sender)
		return _sender.fileSize;
	
	return 0;
}

- (NSString *)fileName
{
	NSAssert(_receiver || _sender, @"need a receiver or a sender");

	if (_receiver)
		return _receiver.fileName;
	
	if (_sender)
		return _sender.fileName;
	
	return nil;
}

- (nullable NSString *)filePath
{
	NSAssert(_receiver || _sender, @"need a receiver or a sender");

	if (_receiver)
		return _receiver.filePath;
	
	if (_sender)
		return _sender.filePath;
	
	return nil;
}

@end


NS_ASSUME_NONNULL_END
