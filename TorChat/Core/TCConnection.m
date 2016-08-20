/*
 *  TCConnection.m
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

#import "TCConnection.h"

#import "TCCoreManager.h"

#import "TCDebugLog.h"
#import "TCParser.h"
#import "TCBuddy.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCConnection - Private
*/
#pragma mark - TCConnection - Private

@interface TCConnection () <TCParserDelegate, TCParserCommand, SMSocketDelegate>
{
	// -- Vars --
	// > Running
	BOOL _running;
    
	// > Socket
	int			_sockd;
	SMSocket	*_sock;
	
	// > Parser
	TCParser *_parser;

	// > Queue
	dispatch_queue_t _localQueue;
	
	// > Delegate
	dispatch_queue_t				_delegateQueue;
	__weak id <TCConnectionDelegate> _delegate;

	NSString *_lastPingIdentifier;
}

// -- Helpers --
- (void)error:(TCCoreError)code fatal:(BOOL)fatal;
- (void)error:(TCCoreError)code context:(id)ctx fatal:(BOOL)fatal;
- (void)error:(TCCoreError)code info:(SMInfo *)subInfo fatal:(BOOL)fatal;

- (void)notify:(TCCoreEvent)notice;

@end



/*
** TCConnection
*/
#pragma mark - TCConnection

@implementation TCConnection


/*
** TCConnection - Instance
*/
#pragma mark - TCConnection - Instance

+ (void)initialize
{
	[self registerInfoDescriptors];
}

- (instancetype)initWithDelegate:(id <TCConnectionDelegate>)delegate andSocket:(int)sock
{
	self = [super init];
	
	if (self)
	{
		// Hold delegate.
		_delegate = delegate;
		
		// Build queue.
		_localQueue = dispatch_queue_create("com.torchat.core.controllclient.local", DISPATCH_QUEUE_SERIAL);
		_delegateQueue = dispatch_queue_create("com.torchat.core.controllclient.delegate", DISPATCH_QUEUE_SERIAL);
		
		// Init vars.
		_running = false;
		
		// Hold socket.
		_sockd = sock;
		_sock = NULL;
		
		// Create parser.
		_parser = [[TCParser alloc] initWithParsingResult:self];
		
		[_parser setDelegate:self];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCConnection dealloc");
	
	if (_sock)
		[_sock stop];
}


/*
** TCConnection - Life
*/
#pragma mark - TCConnection - Life

- (void)start
{
	dispatch_async(_localQueue, ^{
		
		if (!_running && _sockd > 0)
		{
			_running = YES;
			
			// Build a socket
			_sock = [[SMSocket alloc] initWithSocket:_sockd];

			[_sock setDelegate:self];
			[_sock scheduleOperation:SMSocketOperationLine withSize:1 andTag:0];
			
			// Notify
			[self notify:TCCoreEventClientStarted];
		}
	});
}

- (void)stopWithCompletionHandler:(nullable dispatch_block_t)handler
{
	if (!handler)
		handler = ^{ };
	
	dispatch_async(_localQueue, ^{
		
		if (!_running)
		{
			handler();
			return;
		}
		
		_running = false;
		
		// Clean socket
		if (_sock)
		{
			[_sock stop];
			_sock = nil;
		}
		
		// Clean socket descriptor
		_sockd = -1;
		
		// Notify.
		handler();
	});
}



/*
** TCConnection - TCParserDelegate & TCParserCommand
*/
#pragma mark - TCConnection - TCParserDelegate & TCParserCommand

- (void)parser:(TCParser *)parser parsedPingWithIdentifier:(NSString *)identifier random:(NSString *)random
{
	// > localQueue <

	// Reschedule a line read.
	[_sock scheduleOperation:SMSocketOperationLine withSize:1 andTag:0];
	
	// Little security check to detect mass pings with faked host names over the same connection.
	if ([_lastPingIdentifier length] != 0)
	{
		if ([identifier isEqualToString:_lastPingIdentifier] == NO)
		{
			// DEBUG
			fprintf(stderr, "(1) Possible Attack: in-connection sent fake identifier '%s'\n", [identifier UTF8String]);
			fprintf(stderr, "(1) Will disconnect incoming connection from fake '%s'\n", [identifier UTF8String]);
			
			// Notify
			[self error:TCCoreErrorClientCmdPing fatal:YES];
			
			return;
		}
	}
	else
		_lastPingIdentifier = identifier;
	
	
	// Send info to delegate.
	id <TCConnectionDelegate> delegate = _delegate;
	
	if (!delegate)
		return;
	
	dispatch_async(_delegateQueue, ^{
		[delegate connection:self receivedPingWithBuddyIdentifier:identifier randomToken:random];
	});
}

- (void)parser:(TCParser *)parser parsedPongWithRandom:(NSString *)random
{
	// > localQueue <
	
	id <TCConnectionDelegate>	delegate = _delegate;
	SMSocket					*sock = _sock;

	if (!delegate)
		return;
	
	_sock = nil;
	
	dispatch_async(_delegateQueue, ^{
		[delegate connection:self receivedPongOnSocket:sock randomToken:random];
	});
}

- (void)parser:(TCParser *)parser errorWithCode:(TCParserError)error andInformation:(NSString *)information
{
	TCCoreError nerr = TCCoreErrorClientCmdUnknownCommand;
	
	// Convert parser error to controller errors
	switch (error)
	{
		case TCParserErrorUnknownCommand:
			nerr = TCCoreErrorClientCmdUnknownCommand;
			break;
			
		case TCParserErrorCmdPing:
			nerr = TCCoreErrorClientCmdPing;
			break;
			
		case TCParserErrorCmdPong:
			nerr = TCCoreErrorClientCmdPong;
			break;
			
		case TCParserErrorCmdStatus:
			nerr = TCCoreErrorClientCmdStatus;
			break;
			
		case TCParserErrorCmdVersion:
			nerr = TCCoreErrorClientCmdVersion;
			break;
			
		case TCParserErrorCmdClient:
			nerr = TCCoreErrorClientCmdClient;
			break;
			
		case TCParserErrorCmdProfileText:
			nerr = TCCoreErrorClientCmdProfileText;
			break;
			
		case TCParserErrorCmdProfileName:
			nerr = TCCoreErrorClientCmdProfileName;
			break;
			
		case TCParserErrorCmdProfileAvatar:
			nerr = TCCoreErrorClientCmdProfileAvatar;
			break;
			
		case TCParserErrorCmdProfileAvatarAlpha:
			nerr = TCCoreErrorClientCmdProfileAvatarAlpha;
			break;
			
		case TCParserErrorCmdMessage:
			nerr = TCCoreErrorClientCmdMessage;
			break;
			
		case TCParserErrorCmdAddMe:
			nerr = TCCoreErrorClientCmdAddMe;
			break;
			
		case TCParserErrorCmdRemoveMe:
			nerr = TCCoreErrorClientCmdRemoveMe;
			break;
			
		case TCParserErrorCmdFileName:
			nerr = TCCoreErrorClientCmdFileName;
			break;
			
		case TCParserErrorCmdFileData:
			nerr = TCCoreErrorClientCmdFileData;
			break;
			
		case TCParserErrorCmdFileDataOk:
			nerr = TCCoreErrorClientCmdFileDataOk;
			break;
			
		case TCParserErrorCmdFileDataError:
			nerr = TCCoreErrorClientCmdFileDataError;
			break;
			
		case TCParserErrorCmdFileStopSending:
			nerr = TCCoreErrorClientCmdFileStopSending;
			break;
			
		case TCParserErrorCmdFileStopReceiving:
			nerr = TCCoreErrorClientCmdFileStopReceiving;
			break;
	}
	
	// Parse error is fatal
	[self error:nerr context:information fatal:YES];
}



/*
** TCConnection - SMSocketDelegate
*/
#pragma mark - TCConnection - SMSocketDelegate

- (void)socket:(SMSocket *)socket operationAvailable:(SMSocketOperation)operation tag:(NSUInteger)tag content:(id)content
{
	if (operation == SMSocketOperationLine)
	{
		NSArray *lines = content;
		
		for (NSData *line in lines)
		{
			dispatch_async(_localQueue, ^{
				[_parser parseLine:line];
			});
		}
	}
}

- (void)socket:(SMSocket *)socket error:(SMInfo *)error
{
	// Fallback Error
	[self error:TCCoreErrorSocket info:error fatal:YES];
}



/*
** TCConnection - Helpers
*/
#pragma mark - TCConnection - Helpers

- (void)error:(TCCoreError)code fatal:(BOOL)fatal
{
	id <TCConnectionDelegate> delegate = _delegate;
	
	if (delegate)
		[delegate connection:self information:[SMInfo infoOfKind:SMInfoError domain:TCConnectionInfoDomain code:code]];
		
	if (fatal)
		[self stopWithCompletionHandler:nil];
}

- (void)error:(TCCoreError)code context:(id)ctx fatal:(BOOL)fatal
{
	id <TCConnectionDelegate> delegate = _delegate;
	
	if (delegate)
		[delegate connection:self information:[SMInfo infoOfKind:SMInfoError domain:TCConnectionInfoDomain code:code context:ctx]];

	if (fatal)
		[self stopWithCompletionHandler:nil];
}

- (void)error:(TCCoreError)code info:(SMInfo *)subInfo fatal:(BOOL)fatal
{
	id <TCConnectionDelegate> delegate = _delegate;

	if (delegate)
		[delegate connection:self information:[SMInfo infoOfKind:SMInfoError domain:TCConnectionInfoDomain code:code info:subInfo]];
	
	if (fatal)
		[self stopWithCompletionHandler:nil];
}

- (void)notify:(TCCoreEvent)notice
{
	id <TCConnectionDelegate> delegate = _delegate;

	if (delegate)
		[delegate connection:self information:[SMInfo infoOfKind:SMInfoInfo domain:TCConnectionInfoDomain code:notice]];
}



/*
** TCConnection - Infos
*/
#pragma mark - TCConnection - Infos

+ (void)registerInfoDescriptors
{
	NSMutableDictionary *descriptors = [[NSMutableDictionary alloc] init];
	
	// == TCConnectionInfoDomain ==
	descriptors[TCConnectionInfoDomain] = ^ NSDictionary * (SMInfoKind kind, int code) {
		
		switch (kind)
		{
			case SMInfoInfo:
			{
				if (code == TCCoreEventClientStarted)
				{
					return @{
						SMInfoNameKey : @"TCCoreEventClientStarted",
						SMInfoTextKey : @"core_cnx_event_started",
						SMInfoLocalizableKey : @YES,
					};
				}
				else if (code == TCCoreEventClientStopped)
				{
					return @{
						SMInfoNameKey : @"TCCoreEventClientStopped",
						SMInfoTextKey : @"core_cnx_event_stopped",
						SMInfoLocalizableKey : @YES,
					};
				}
				
				break;
			}
			
			case SMInfoWarning:
			{
				break;
			}
				
			case SMInfoError:
			{
				if (code == TCCoreErrorSocket)
				{
					return @{
						SMInfoNameKey : @"TCCoreErrorSocket",
						SMInfoTextKey : @"core_cnx_error_socket",
						SMInfoLocalizableKey : @YES,
					};
				}
				else if (code == TCCoreErrorClientCmdPing)
				{
					return @{
						SMInfoNameKey : @"TCCoreErrorClientCmdPing",
						SMInfoTextKey : @"core_cnx_error_fake_ping",
						SMInfoLocalizableKey : @YES,
					};
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


NS_ASSUME_NONNULL_END
