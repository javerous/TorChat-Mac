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

#include <netdb.h>
#include <pwd.h>

#include <sys/stat.h>
#include <sys/types.h>
#include <sys/socket.h>

@import SMFoundation;

#include <arpa/inet.h>

#import "TCBuddy.h"

#import "TCDebugLog.h"

#import "TCParser.h"
#import "TCImage.h"

#import "TCFileReceive.h"
#import "TCFileSend.h"

#import "NSArray+TCTools.h"
#import "NSData+TCTools.h"


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
typedef enum
{
	socks_nostate,
	socks_running,
	socks_finish,
} socks_state;

// -- Socks trame type --
typedef enum
{
	socks_v4_reply,
} socks_trame;



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
- (id)initWithFileSend:(TCFileSend *)sender;
- (id)initWithFileReceive:(TCFileReceive *)receiver;

@end



/*
** TCBuddy - Private
*/
#pragma mark - TCBuddy - Private

@interface TCBuddy () <TCParserCommand, TCParserDelegate, SMSocketDelegate>
{
	// > Config
	id <TCConfigCore>		_config;
	
	// > Parser
	TCParser			*_parser;
	
	// > Status
	int					_socksstate;
	BOOL				_running;
	BOOL				_ponged;
	BOOL				_pongSent;
	
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
	
	// > Socket
	SMSocket			*_inSocket;
	SMSocket			*_outSocket;
	
	// > Command
	NSMutableArray		*_bufferedCommands;
	
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

// -- Send Low Command --
- (void)_sendPing;
- (void)_sendPong:(NSString *)random;
- (void)_sendVersion;
- (void)_sendClient;
- (void)_sendProfileName:(NSString *)name;
- (void)_sendProfileText:(NSString *)text;
- (void)_sendAvatar:(TCImage *)avatar;
- (void)_sendAddMe;
- (void)_sendRemoveMe;
- (void)_sendStatus:(TCStatus)status;
- (void)_sendMessage:(NSString *)message;
- (void)_sendFileName:(TCFileSend *)file;
- (void)_sendFileData:(TCFileSend *)file;
- (void)_sendFileDataOk:(NSString *)uuid start:(uint64_t)start;
- (void)_sendFileDataError:(NSString *)uuid start:(uint64_t)start;
- (void)_sendFileStopSending:(NSString *)uuid;
- (void)_sendFileStopReceiving:(NSString *)uuid;

// -- Send Command Data --
- (BOOL)_sendCommand:(NSString *)command channel:(TCBuddyChannel)channel; // TCBuddyChannelOut
- (BOOL)_sendCommand:(NSString *)command array:(NSArray *)data channel:(TCBuddyChannel)channel; // = TCBuddyChannelOut);
- (BOOL)_sendCommand:(NSString *)command data:(NSData *)data channel:(TCBuddyChannel)channel; // = TCBuddyChannelOut);
- (BOOL)_sendCommand:(NSString *)command string:(NSString *)data channel:(TCBuddyChannel)channel; // = TCBuddyChannelOut);
- (BOOL)_sendData:(NSData *)data channel:(TCBuddyChannel)channel; // = TCBuddyChannelOut);

// -- Network Helper --
- (void)_startSocks;
- (void)_connectedSocks;
- (void)_runPendingWrite;
- (void)_runPendingFileWrite;

// -- Helper --
- (void)_error:(TCBuddyError)code fatal:(BOOL)fatal;
- (void)_error:(TCBuddyError)code context:(id)ctx fatal:(BOOL)fatal;
- (void)_error:(TCBuddyError)code info:(SMInfo *)subInfo fatal:(BOOL)fatal;

- (void)_notify:(TCBuddyEvent)notice;
- (void)_notify:(TCBuddyEvent)notice context:(id)ctx;

- (void)_sendEvent:(SMInfo *)info;

- (NSNumber *)_status;

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

- (id)initWithConfiguration:(id <TCConfigCore>)configuration identifier:(NSString *)identifier alias:(NSString *)alias notes:(NSString *)notes
{
	self = [super init];
	
	if (self)
	{
		// Retain config
		_config = configuration;
		
		// Retain property
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
		
		_bufferedCommands = [[NSMutableArray alloc] init];
		
		_messages = [[NSMutableArray alloc] init];

		_observers = [NSHashTable weakObjectsHashTable];
		
		// Create parser.
		_parser = [[TCParser alloc] initWithParsingResult:self];
		[_parser setDelegate:self];
		
		// Init status
		_socksstate = socks_nostate;
		_status = TCStatusOffline;
		
		// Init profiles
		_profileName = [_config buddyLastNameForBuddyIdentifier:_identifier] ?: @"";
		_profileText = [_config buddyLastTextForBuddyIdentifier:_identifier] ?: @"";
		_profileAvatar = [_config buddyLastAvatarForBuddyIdentifier:_identifier];

		if (!_profileAvatar)
			_profileAvatar = [[TCImage alloc] initWithWidth:64 andHeight:64];
		
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
	
	// Clean out connections
	[_outSocket stop];

	// Clean in connexions
	[_inSocket stop];
}


/*
** TCBuddy - Run
*/
#pragma mark - Run

- (void)start
{
	dispatch_async(_localQueue, ^{
		
		if (_running)
			return;
		
		if (_blocked)
			return;
		
		TCDebugLog(@"Buddy (%@) - Start", _identifier);
		
		// -- Make a connection to Tor proxy --
		struct addrinfo	hints, *res, *res0;
		int				error;
		int				s;
		char			sport[50];
		
		memset(&hints, 0, sizeof(hints));
		
		snprintf(sport, sizeof(sport), "%i", [_config torPort]);
		
		// Configure the resolver
		hints.ai_family = PF_UNSPEC;
		hints.ai_socktype = SOCK_STREAM;
		
		// Try to resolve and connect to the given address
		error = getaddrinfo([[_config torAddress] UTF8String], sport, &hints, &res0);
		
		if (error)
		{
			[self _error:TCBuddyErrorResolveTor fatal:YES];
			return;
		}
		
		s = -1;
		
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
			[self _error:TCBuddyErrorConnectTor fatal:YES];

			return;
		}
		
		// Build a socket with this descriptor
		_outSocket = [[SMSocket alloc] initWithSocket:s];
		
		// Set ourself as delegate
		_outSocket.delegate = self;
		
		// Start SOCKS protocol
		[self _startSocks];
		
		// Set as running
		_running = YES;
		
		// Say that we are connected
		[self _notify:TCBuddyEventConnectedTor];
	});
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	if (!handler)
		handler = ^{ };
	
	dispatch_async(_localQueue, ^{
		
		if (_running)
		{
			TCStatus lstatus;
			
			// Realease out socket
			if (_outSocket)
			{
				[_outSocket stop];
				_outSocket = nil;
			}
			
			// Realease in socket
			if (_inSocket)
			{
				[_inSocket stop];
				_inSocket = nil;
			}
			
			// Clean receive session
			[_freceive removeAllObjects];
			
			// Clean send session
			[_fsend removeAllObjects];
			
			// Reset status
			lstatus = _status;
			_status = TCStatusOffline;
			
			_socksstate = socks_nostate;
			_ponged = false;
			_pongSent = false;
			_running = false;
			
			// Notify
			if (lstatus != TCStatusOffline)
				[self _notify:TCBuddyEventStatus context:[self _status]];
			
			[self _notify:TCBuddyEventDisconnected];
		}
		
		// Notify end.
		dispatch_async(_externalQueue, handler);
	});
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

- (void)keepAlive
{
	dispatch_async(_localQueue, ^{
		
		if (_blocked)
			return;
		
		if (!_running)
			[self start];
		else
		{
			if (_pongSent && _ponged)
				[self _sendStatus:_cstatus];
		}
	});
}



/*
** TCBuddy - Properties
*/
#pragma mark - Properties

- (NSString *)alias
{
	__block NSString *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _alias;
	});
	
	return result;
}

- (void)setAlias:(NSString *)name
{
	if (!name)
		return;
		
	dispatch_async(_localQueue, ^{
		
		// Set the new name in config
		[_config setBuddyAlias:name forBuddyIdentifier:_identifier];
		
		// Change the name internaly
		_alias = name;
		
		// Notidy of the change
		[self _notify:TCBuddyEventAlias context:name];
	});
}

- (NSString *)notes
{
	__block NSString *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _notes;
	});
	
	return result;
}

- (void)setNotes:(NSString *)notes
{
	if (!notes)
		return;
		
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
		
		if (_pongSent && _ponged)
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
	__block NSString * result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _peerClient;
	});
	
	return result;
}

- (NSString *)peerVersion
{
	__block NSString * result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _peerVersion;
	});
	
	return result;
}

- (NSString *)profileText
{
	__block NSString * result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _profileText;
	});
	
	return result;
}

- (TCImage *)profileAvatar
{
	__block id result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _profileAvatar;
	});
	
	return result;
}

- (NSString *)profileName
{
	__block NSString * result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _profileName;
	});
	
	return result;
}

- (NSString *)finalName
{
	__block NSString *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		
		if ([_alias length] > 0)
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

- (NSString *)fileNameForUUID:(NSString *)uuid andWay:(TCBuddyFileWay)way
{
	if (!uuid)
		return nil;
	
	__block NSString *res = nil;
	
	dispatch_sync(_localQueue, ^{
		
		if (way == TCBuddyFileSend)
		{
			TCFileSend *file = _fsend[uuid];
			
			if (file)
				res = [file fileName];
		}
		else if (way == TCBuddyFileReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
				res = [file fileName];
		}
	});
	
	return res;
}

- (NSString *)filePathForUUID:(NSString *)uuid andWay:(TCBuddyFileWay)way
{
	if (!uuid)
		return nil;
	
	__block NSString *res = nil;
	
	dispatch_sync(_localQueue, ^{
		
		if (way == TCBuddyFileSend)
		{
			TCFileSend *file = _fsend[uuid];
			
			res = [file filePath];
		}
		else if (way == TCBuddyFileReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
				res = [file filePath];
		}
	});
	
	return res;
}

- (BOOL)fileStatForUUID:(NSString *)uuid way:(TCBuddyFileWay)way done:(uint64_t *)done total:(uint64_t *)total
{
	if (!uuid)
		return NO;
	
	__block BOOL		result = false;
	__block uint64_t	rdone = 0;
	__block uint64_t	rtotal = 0;
	
	dispatch_sync(_localQueue, ^{
		
		if (way == TCBuddyFileSend)
		{
			// Search the file send
			TCFileSend *file = _fsend[uuid];
			
			if (file)
			{
				rdone = [file validatedSize];
				rtotal = [file fileSize];
				
				result = true;
			}
		}
		else if (way == TCBuddyFileReceive)
		{
			TCFileReceive *file = _freceive[uuid];
			
			if (file)
			{
				rdone = [file receivedSize];
				rtotal = [file fileSize];
				
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

- (void)fileCancelOfUUID:(NSString *)uuid way:(TCBuddyFileWay)way
{
	if (!uuid)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (way == TCBuddyFileSend)
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
		else if (way == TCBuddyFileReceive)
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
		if (_pongSent && !_blocked)
			[self _sendStatus:status];
	});
}

- (void)sendAvatar:(TCImage *)avatar
{
	if (!avatar)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (_pongSent && _ponged && !_blocked)
			[self _sendAvatar:avatar];
	});
}

- (void)sendProfileName:(NSString *)name
{
	if (!name)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (_pongSent && _ponged && !_blocked)
			[self _sendProfileName:name];
	});
}

- (void)sendProfileText:(NSString *)text
{
	if (!text)
		return;
		
	dispatch_async(_localQueue, ^{
		
		if (_pongSent && _ponged && !_blocked)
			[self _sendProfileText:text];
	});
}

- (void)sendMessage:(NSString *)message completionHanndler:(void (^)(SMInfo *info))handler
{
	if (!message)
		return;
		
	dispatch_async(_localQueue, ^{
		
		SMInfo *err = nil;
		
		if (_blocked)
			err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:TCBuddyErrorMessageBlocked context:message];
		else
		{
			// Send Message only if we sent pong and we are ponged
			if (_pongSent && _ponged)
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

- (void)sendFile:(NSString *)filepath
{
	if (!filepath)
		return;
	
	dispatch_async(_localQueue, ^{
		
		// Send file only if we sent pong and we are ponged
		if (_pongSent && _ponged)
		{
			if (!_blocked)
			{
				TCFileSend *file;
				
				// Try to open the file for send
				file = [[TCFileSend alloc] initWithFilePath:filepath];
				
				if (!file)
				{
					[self _error:TCBuddyErrorSendFile context:filepath fatal:NO];
					return;
				}
				
				// Insert the new file session
				_fsend[[file uuid]] = file;
				
				// Notify
				TCFileInfo *info = [[TCFileInfo alloc] initWithFileSend:file];
				
				[self _notify:TCBuddyEventFileSendStart context:info];
				
				// Start the file session
				[self _sendFileName:file];
				
				// Send the first block to start the send
				[self _sendFileData:file];
			}
			else
			[self _error:TCBuddyErrorFileBlocked context:filepath fatal:NO];

		}
		else
		{
			[self _error:TCBuddyErrorFileOffline context:filepath fatal:NO];
		}
	});
}



/*
** TCBuddy - Action
*/
#pragma mark - Action

- (void)startHandshake:(NSString *)remoteRandom status:(TCStatus)status avatar:(TCImage *)avatar name:(NSString *)name text:(NSString *)text
{
	if (!remoteRandom || !name || !text)
		return;
		
	dispatch_async(_localQueue, ^{
		
		if (_blocked)
			return;
		
		[self _sendPong:remoteRandom];
		[self _sendClient];
		[self _sendVersion];
		[self _sendProfileName:name];
		[self _sendProfileText:text];
		[self _sendAvatar:avatar];
		[self _sendAddMe];
		[self _sendStatus:status];
		
		_pongSent = YES;
	});
}

- (void)setInputConnection:(SMSocket *)sock
{
	if (!sock)
		return;
	
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
			
			[_inSocket setGlobalOperation:SMSocketOperationLine withSize:0 andTag:0];
			
			// Notify that we are ready
			if (_ponged && _pongSent)
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
	if (!observer)
		return;
	
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
			struct sockrep	*thisrep = (struct sockrep *)([data bytes]);
			
			// Check result
			switch (thisrep->result)
			{
				case 90: // Socks v4 protocol finish
				{
					_socksstate = socks_finish;
					
					[_outSocket setGlobalOperation:SMSocketOperationLine withSize:0 andTag:0];
					
					// Notify
					[self _notify:TCBuddyEventConnectedBuddy];
					
					// We are connected, do things
					[self _connectedSocks];
					
					break;
				}
					
				case 91:
				case 92:
				case 93:
					[self _error:TCBuddyErrorSocks context:@(thisrep->result) fatal:YES];
					break;

				default:
					[self _error:TCBuddyErrorSocks fatal:YES];
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
		
		// Fallback error
		[self _error:TCBuddyErrorSocket info:error fatal:YES];
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
	
	if (nstatus != _status)
	{
		_status = nstatus;
		
		// Notify that status changed
		[self _notify:TCBuddyEventStatus context:[self _status]];
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
	
	if ([[downPath lastPathComponent] isEqualToString:@"Downloads"])
		[[NSData data] writeToFile:[downPath stringByAppendingPathComponent:@".localized"] atomically:NO];
	
	// Parse values
	uint64_t		ifsize = strtoull([fileSize cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
	uint64_t		ibsize = strtoull([blockSize cStringUsingEncoding:NSASCIIStringEncoding], NULL, 10);
	TCFileReceive	*file;
	
	// Build a receiver instance
	file = [[TCFileReceive alloc] initWithUUID:uuid folder:downPath fileName:sfilename_2 fileSize:ifsize blockSiz:ibsize];
	
	if (!file)
	{
		[self _error:TCBuddyErrorReceiveFile fatal:NO];
		return;
	}
	
	// Add it to the list
	_freceive[[file uuid]] = file;
		
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
		
		if ([file writeChunk:[data bytes] chunkSize:[data length] hash:hash offset:&offset])
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

- (void)parser:(TCParser *)parser errorWithCode:(TCParserError)error andInformation:(NSString *)information
{
	if (_blocked)
		return;
	
	// Don't get parse error on blocked buddy (prevent spam, etc.)
	SMInfo *info = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:error context:information];
		
	[self _error:TCBuddyErrorParse info:info fatal:NO];
}




/*
** TCBuddy - Send Low Command
*/
#pragma mark - Send Low Command

- (void)_sendPing
{
	// > localQueue <
	
	NSMutableArray *items = [[NSMutableArray alloc] init];
	
	[items addObject:[_config selfIdentifier]];
	[items addObject:_random];

	[self _sendCommand:@"ping" array:items channel:TCBuddyChannelOut];
}

- (void)_sendPong:(NSString *)random
{
	// > localQueue <
	
	if ([random length] == 0)
		return;
	
	[self _sendCommand:@"pong" string:random channel:TCBuddyChannelOut];
}

- (void)_sendVersion
{
	// > localQueue <
	
	[self _sendCommand:@"version" string:[_config clientVersion:TCConfigGetReal] channel:TCBuddyChannelOut];
}

- (void)_sendClient
{
	// > localQueue <
		
	[self _sendCommand:@"client" string:[_config clientName:TCConfigGetReal] channel:TCBuddyChannelOut];
}

- (void)_sendProfileName:(NSString *)name
{
	// > localQueue <
	
	if (!name)
		return;

	[self _sendCommand:@"profile_name" string:name channel:TCBuddyChannelOut];
}

- (void)_sendProfileText:(NSString *)text
{
	// > localQueue <
	
	if (!text)
		return;
	
	[self _sendCommand:@"profile_text" string:text channel:TCBuddyChannelOut];
}

- (void)_sendAvatar:(TCImage *)avatar
{
	// > localQueue <
	
	if (!avatar)
		return;
	
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
	
	if (!file)
		return;
	
	NSMutableArray *items = [[NSMutableArray alloc] init];
		
	// Add the uuid
	[items addObject:[file uuid]];
	
	// Add the file size
	[items addObject:[NSString stringWithFormat:@"%llu", [file fileSize]]];
	
	// Add the block size
	[items addObject:[NSString stringWithFormat:@"%u", [file blockSize]]];
	
	// Add the filename
	[items addObject:[file fileName]];

	// Send the command
	[self _sendCommand:@"filename" array:items channel:TCBuddyChannelIn];
}

- (void)_sendFileData:(TCFileSend *)file
{
	// > localQueue <
	
	if (!file || [file readSize] >= [file fileSize])
		return;
	
	uint8_t		*chunk = malloc([file blockSize]);
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
	[items addObject:[file uuid]];
	
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

- (BOOL)_sendCommand:(NSString *)command data:(NSData *)data channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	if (!command)
		return NO;
	
	// -- Build the command line --
	NSMutableData *part = [[NSMutableData alloc] init];
	
	[part appendData:[command dataUsingEncoding:NSASCIIStringEncoding]];
	
	if ([data length] > 0)
	{
		[part appendBytes:" " length:1];
		[part appendData:data];
	}
	
	// Escape protocol special chars
	[part replaceCStr:"\\" withCStr:"\\/"];
	[part replaceCStr:"\n" withCStr:"\\n"];
	

	// Add end line.
	[part appendBytes:"\n" length:1];
	
	// -- Buffer or send the command --
	if (_socksstate != socks_finish)
	{
		[_bufferedCommands addObject:part];
		
		if (!_running)
			[self start];
	}
	else
	{
		[self _sendData:part channel:channel];
	}
	
	return YES;
}

- (BOOL)_sendData:(NSData *)data channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	return [self _sendBytes:[data bytes] length:[data length] channel:channel];
}

- (BOOL)_sendBytes:(const void *)bytes length:(NSUInteger)length channel:(TCBuddyChannel)channel
{
	// > localQueue <
	
	if (!bytes || length == 0)
		return NO;
	
	if (channel == TCBuddyChannelIn && _inSocket)
		[_inSocket sendBytes:bytes ofSize:length copy:YES];
	else if (channel == TCBuddyChannelOut && _outSocket)
		[_outSocket sendBytes:bytes ofSize:length copy:YES];
	else
		return NO;
	
	return YES;
}



/*
** TCBuddy - Network Helper
*/
#pragma mark - Network Helper

- (void)_startSocks
{
	// > localQueue <
	
	const char			*user = "torchat";
	struct sockreq		*thisreq;
	char				*buffer;
	size_t				datalen;
	
	// Get the target connexion informations
	NSString	*host = [_identifier stringByAppendingString:@".onion"];
	const char	*c_host = [host UTF8String];
	
	// Check data size
	datalen = sizeof(struct sockreq) + strlen(user) + 1;
	datalen += strlen(c_host) + 1;
	
	buffer = (char *)malloc(datalen);
	thisreq = (struct sockreq *)buffer;
	
	// Create the request
	thisreq->version = 4;
	thisreq->command = 1;
	thisreq->dstport = htons(TORCHAT_PORT);
	thisreq->dstip = htonl(0x00000042); // Socks v4a
	
	// Copy the username
	strcpy((char *)thisreq + sizeof(struct sockreq), user);
	
	// Socks v4a : set the host name if we cant resolve it
	char *pos = (char *)thisreq + sizeof(struct sockreq);
	
	pos += strlen(user) + 1;
	strcpy(pos, c_host);
	
	// Set the next input operation
	[_outSocket scheduleOperation:SMSocketOperationData withSize:sizeof(struct sockrep) andTag:socks_v4_reply];
	
	// Send the request
	if ([self _sendBytes:buffer length:datalen channel:TCBuddyChannelOut])
		_socksstate = socks_running;
	else
		[self _error:TCBuddyErrorSocksRequest fatal:true];
	
	free(buffer);
}

- (void)_connectedSocks
{
	// > localQueue <
	
	// -- Send ping --
	[self _sendPing];
	
	// -- Send buffered commands --
	for (NSData *command in _bufferedCommands)
	{
		[self _sendData:command channel:TCBuddyChannelOut];
	}
	
	[_bufferedCommands removeAllObjects];
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
		
		if (([file readSize] - [file validatedSize]) >= 16 * [file blockSize])
			continue;
		
		[self _sendFileData:file];
	}
}



/*
** TCBuddy - Helpers
*/
#pragma mark - Helpers

- (void)_error:(TCBuddyError)code fatal:(BOOL)fatal
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code];
	
	[self _sendEvent:err];
	
	// Fatal -> stop
	if (fatal)
		[self stopWithCompletionHandler:nil];
}

- (void)_error:(TCBuddyError)code context:(id)ctx fatal:(BOOL)fatal
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code context:ctx];

	[self _sendEvent:err];
	
	// Fatal -> stop
	if (fatal)
		[self stopWithCompletionHandler:nil];
}

- (void)_error:(TCBuddyError)code info:(SMInfo *)subInfo fatal:(BOOL)fatal
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCBuddyInfoDomain code:code info:subInfo];
	
	[self _sendEvent:err];
	
	// Fatal -> stop
	if (fatal)
		[self stopWithCompletionHandler:nil];
}

- (void)_notify:(TCBuddyEvent)notice
{
	// > localQueue <
	
	SMInfo *ifo = [SMInfo infoOfKind:SMInfoInfo domain:TCBuddyInfoDomain code:notice];
	
	[self _sendEvent:ifo];
}

- (void)_notify:(TCBuddyEvent)notice context:(id)ctx
{
	// > localQueue <
	
	SMInfo *ifo = [SMInfo infoOfKind:SMInfoInfo domain:TCBuddyInfoDomain code:notice context:ctx];
	
	[self _sendEvent:ifo];
}

- (void)_sendEvent:(SMInfo *)info
{
	// > localQueue <
	
	if (!info)
		return;
	
	for (id <TCBuddyObserver> observer in _observers)
	{
		dispatch_async(_externalQueue, ^{
			[observer buddy:self information:info];
		});
	}
}

- (NSNumber *)_status
{
	// > localQueue <
	
	TCStatus res;
	
	if (_pongSent && _ponged)
		res = _status;
	else
		res = TCStatusOffline;
	
	return @(res);
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
									 
								switch ([context intValue])
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
								
								if ([context intValue] == 91)
									return @"core_bd_error_socks_91";
								else if ([context intValue] == 92)
									return @"core_bd_error_socks_92";
								else if ([context intValue] == 93)
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

- (id)initWithFileSend:(TCFileSend *)sender
{
	if (!sender)
		return nil;
	
	self = [super init];
	
	if (self)
	{
		_sender = sender;
	}
	
	return self;
}

- (id)initWithFileReceive:(TCFileReceive *)receiver
{
	if (!receiver)
		return nil;
	
	self = [super init];
	
	if (self)
	{
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
	if (_receiver)
		return [_receiver uuid];
	
	if (_sender)
		return [_sender uuid];
	
	return @"";
}

- (uint64_t)fileSizeCompleted
{
	if (_receiver)
		return [_receiver receivedSize];
	
	if (_sender)
		return [_sender validatedSize];
	
	return 0;
}

- (uint64_t)fileSizeTotal
{
	if (_receiver)
		return [_receiver fileSize];
	
	if (_sender)
		return [_sender fileSize];
	
	return 0;
}

- (NSString *)fileName
{
	if (_receiver)
		return [_receiver fileName];
	
	if (_sender)
		return [_sender fileName];
	
	return @"";
}

- (NSString *)filePath
{
	if (_receiver)
		return [_receiver filePath];
	
	if (_sender)
		return [_sender filePath];
	
	return @"";
}

@end
