/*
 *  TCConnection.cpp
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

#import "TCConnection.h"

#import "TCCoreManager.h"

#import "TCDebugLog.h"
#import "TCParser.h"
#import "TCSocket.h"
#import "TCInfo.h"
#import "TCBuddy.h"



/*
** TCConnection - Private
*/
#pragma mark - TCConnection - Private

@interface TCConnection () <TCParserDelegate, TCParserCommand, TCSocketDelegate>
{
	// -- Vars --
	// > Running
	BOOL						_running;
    
	// > Socket
	int							_sockd;
	TCSocket					*_sock;
	
	// > Parser
	TCParser					*_parser;

	// > Queue
	dispatch_queue_t			_localQueue;
	
	// > Delegate
	dispatch_queue_t			_delegateQueue;
	__weak id <TCConnectionDelegate> _delegate;

	NSString					*_last_ping_address;
}

// -- Helpers --
- (void)error:(tccore_info)code info:(NSString *)info fatal:(BOOL)fatal;
- (void)error:(tccore_info)code info:(NSString *)info contextObj:(id)ctx fatal:(BOOL)fatal;
- (void)error:(tccore_info)code info:(NSString *)info contextInfo:(TCInfo *)serr fatal:(BOOL)fatal;

- (void)notify:(tccore_info)notice info:(NSString *)info;

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

- (id)initWithDelegate:(id <TCConnectionDelegate>)delegate andSocket:(int)sock
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
	TCDebugLog("TCConnection Destructor");
	
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
			_sock = [[TCSocket alloc] initWithSocket:_sockd];

			[_sock setDelegate:self];
			[_sock scheduleOperation:tcsocket_op_line withSize:1 andTag:0];
			
			// Notify
			[self notify:tccore_notify_client_started info:@"core_cnx_note_started"];
		}
	});
}

- (void)stop
{
	dispatch_async(_localQueue, ^{
		
		if (!_running)
			return;
		
		_running = false;
		
		// Clean socket
		if (_sock)
		{
			[_sock stop];
			_sock = nil;
		}
		
		// Clean socket descriptor
		_sockd = -1;
	});
}



/*
** TCConnection - TCParserDelegate & TCParserCommand
*/
#pragma mark - TCConnection - TCParserDelegate & TCParserCommand

- (void)parser:(TCParser *)parser parsedPingWithAddress:(NSString *)address random:(NSString *)random
{
	// > localQueue <

	// Reschedule a line read.
	[_sock scheduleOperation:tcsocket_op_line withSize:1 andTag:0];
	
	// Little security check to detect mass pings with faked host names over the same connection.
	if ([_last_ping_address length] != 0)
	{
		if ([address isEqualToString:_last_ping_address] == NO)
		{
			// DEBUG
			fprintf(stderr, "(1) Possible Attack: in-connection sent fake address '%s'\n", [address UTF8String]);
			fprintf(stderr, "(1) Will disconnect incoming connection from fake '%s'\n", [address UTF8String]);
			
			// Notify
			[self error:tccore_error_client_cmd_ping info:@"core_cnx_err_fake_ping" fatal:YES];
			
			return;
		}
	}
	else
		_last_ping_address = address;
	
	
	// Send info to delegate.
	id <TCConnectionDelegate> delegate = _delegate;
	
	if (!delegate)
		return;
	
	dispatch_async(_delegateQueue, ^{
		[delegate connection:self pingAddress:address withRandomToken:random];
	});
}

- (void)parser:(TCParser *)parser parsedPongWithRandom:(NSString *)random
{
	// > localQueue <
	
	id <TCConnectionDelegate>	delegate = _delegate;
	TCSocket					*sock = _sock;

	if (!delegate)
		return;
	
	_sock = nil;
	
	dispatch_async(_delegateQueue, ^{
		[delegate connection:self pongWithSocket:sock andRandomToken:random];
	});
}

- (void)parser:(TCParser *)parser errorWithCode:(tcrec_error)error andInformation:(NSString *)information
{
	tccore_info nerr = tccore_error_client_unknown_command;
	
	// Convert parser error to controller errors
	switch (error)
	{
		case tcrec_unknown_command:
			nerr = tccore_error_client_unknown_command;
			break;
			
		case tcrec_cmd_ping:
			nerr = tccore_error_client_cmd_ping;
			break;
			
		case tcrec_cmd_pong:
			nerr = tccore_error_client_cmd_pong;
			break;
			
		case tcrec_cmd_status:
			nerr = tccore_error_client_cmd_status;
			break;
			
		case tcrec_cmd_version:
			nerr = tccore_error_client_cmd_version;
			break;
			
		case tcrec_cmd_client:
			nerr = tccore_error_client_cmd_client;
			break;
			
		case tcrec_cmd_profile_text:
			nerr = tccore_error_client_cmd_profile_text;
			break;
			
		case tcrec_cmd_profile_name:
			nerr = tccore_error_client_cmd_profile_name;
			break;
			
		case tcrec_cmd_profile_avatar:
			nerr = tccore_error_client_cmd_profile_avatar;
			break;
			
		case tcrec_cmd_profile_avatar_alpha:
			nerr = tccore_error_client_cmd_profile_avatar_alpha;
			break;
			
		case tcrec_cmd_message:
			nerr = tccore_error_client_cmd_message;
			break;
			
		case tcrec_cmd_addme:
			nerr = tccore_error_client_cmd_addme;
			break;
			
		case tcrec_cmd_removeme:
			nerr = tccore_error_client_cmd_removeme;
			break;
			
		case tcrec_cmd_filename:
			nerr = tccore_error_client_cmd_filename;
			break;
			
		case tcrec_cmd_filedata:
			nerr = tccore_error_client_cmd_filedata;
			break;
			
		case tcrec_cmd_filedataok:
			nerr = tccore_error_client_cmd_filedataok;
			break;
			
		case tcrec_cmd_filedataerror:
			nerr = tccore_error_client_cmd_filedataerror;
			break;
			
		case tcrec_cmd_filestopsending:
			nerr = tccore_error_client_cmd_filestopsending;
			break;
			
		case tcrec_cmd_filestopreceiving:
			nerr = tccore_error_client_cmd_filestopreceiving;
			break;
	}
	
	// Parse error is fatal
	[self error:nerr info:information fatal:YES];
}



/*
** TCConnection - TCSocketDelegate
*/
#pragma mark - TCConnection - TCSocketDelegate

- (void)socket:(TCSocket *)socket operationAvailable:(tcsocket_operation)operation tag:(NSUInteger)tag content:(id)content
{
	if (operation == tcsocket_op_line)
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

- (void)socket:(TCSocket *)socket error:(TCInfo *)error
{
	// Fallback Error
	[self error:tccore_error_socket info:@"core_cnx_err_socket" contextInfo:error fatal:YES];
}



/*
** TCConnection - Helpers
*/
#pragma mark - TCConnection - Helpers

- (void)error:(tccore_info)code info:(NSString *)info fatal:(BOOL)fatal
{
	id <TCConnectionDelegate> delegate = _delegate;
	
	if (delegate)
		[delegate connection:self information:[TCInfo infoOfKind:tcinfo_error infoCode:code infoString:info]];
		
	if (fatal)
		[self stop];
}

- (void)error:(tccore_info)code info:(NSString *)info contextObj:(id)ctx fatal:(BOOL)fatal
{
	id <TCConnectionDelegate> delegate = _delegate;
	
	if (delegate)
		[delegate connection:self information:[TCInfo infoOfKind:tcinfo_error infoCode:code infoString:info context:ctx]];

	if (fatal)
		[self stop];
}

- (void)error:(tccore_info)code info:(NSString *)info contextInfo:(TCInfo *)serr fatal:(BOOL)fatal
{
	id <TCConnectionDelegate> delegate = _delegate;

	if (delegate)
		[delegate connection:self information:[TCInfo infoOfKind:tcinfo_error infoCode:code infoString:info info:serr]];
	
	if (fatal)
		[self stop];
}

- (void)notify:(tccore_info)notice info:(NSString *)info
{
	id <TCConnectionDelegate> delegate = _delegate;

	if (delegate)
		[delegate connection:self information:[TCInfo infoOfKind:tcinfo_info infoCode:notice infoString:info]];
}

@end
