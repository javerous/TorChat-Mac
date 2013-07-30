/*
 *  TCControlClient.cpp
 *
 *  Copyright 2012 Avérous Julien-Pierre
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

#import "TCControlClient.h"

#import "TCController.h"

#import "TCParser.h"
#import "TCSocket.h"

#import "TCObject.h"
#import "TCInfo.h"
#import "TCBuddy.h"
#import "TCString.h"


/*
** TCControlClient - Private
*/
#pragma mark - TCControlClient - Private

@interface TCControlClient () <TCParserDelegate, TCParserCommand, TCSocketDelegate>
{
	// -- Vars --
	// > Running
	BOOL					_running;
    
	// > Socket
	int						_sockd;
	TCSocket				*_sock;
	
	// > Parser
	TCParser				*_parser;
	
	// > Controller
	__weak TCController		*_ctrl;
	
	// > Config
	id <TCConfig>			_config;
	
	// > Queue
	dispatch_queue_t		_localQueue;
	
	NSString				*_last_ping_address;
}

// -- Helpers --
- (void)_error:(tcctrl_info)code info:(NSString *)info fatal:(BOOL)fatal;
- (void)_error:(tcctrl_info)code info:(NSString *)info contextObj:(TCObject *)ctx fatal:(BOOL)fatal;
- (void)_error:(tcctrl_info)code info:(NSString *)info contextInfo:(TCInfo *)serr fatal:(BOOL)fatal;

- (void)_notify:(tcctrl_info)notice info:(NSString *)info;

- (BOOL)_isBlocked:(NSString *)address;

@end




/*
** TCControlClient
*/
#pragma mark - TCControlClient

@implementation TCControlClient


/*
** TCControlClient - Instance
*/
#pragma mark - TCControlClient - Instance

- (id)initWithConfiguration:(id <TCConfig>)configuration andSocket:(int)sock
{
	self = [super init];
	
	if (self)
	{
		// Hold config
		_config = configuration;
		
		// Build queue
		_localQueue = dispatch_queue_create("com.torchat.core.controllclient.local", DISPATCH_QUEUE_SERIAL);
		
		// Init vars
		_running = false;
		
		// Hold socket
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
	TCDebugLog("TCControlClient Destructor");
	
	_ctrl = nil;
	_config = nil;
	
	if (_sock)
		[_sock stop];
}


/*
** TCControlClient - Life
*/
#pragma mark - TCControlClient - Life

- (void)startWithController:(TCController *)controller
{
	if (!controller)
		return;
	
	dispatch_async(_localQueue, ^{
		
		if (!_running && _sockd > 0)
		{
			_ctrl = controller;
			_running = YES;
			
			// Build a socket
			_sock = [[TCSocket alloc] initWithSocket:_sockd];

			[_sock setDelegate:self];
			[_sock scheduleOperation:tcsocket_op_line withSize:1 andTag:0];
			
			// Notify
			[self _notify:tcctrl_notify_client_started info:@"core_cctrl_note_started"];
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
		
		// Notify
		[self _notify:tcctrl_notify_client_stoped info:@"core_cctrl_note_stoped"];
		
		// Remove ref to controller.
		_ctrl = nil;
	});
}



/*
** TCControlClient - TCParserDelegate & TCParserCommand
*/
#pragma mark - TCControlClient - TCParserDelegate & TCParserCommand

- (void)parser:(TCParser *)parser parsedPingWithAddress:(NSString *)address random:(NSString *)random
{
	// > mainQueue (same as parser caller) <
	
	TCBuddy *abuddy = NULL;
	
	// Reschedule a line read
	[_sock scheduleOperation:tcsocket_op_line withSize:1 andTag:0];
	
	// Check blocked list
	TCController *ctrl = _ctrl;
	
	abuddy = [ctrl buddyWithAddress:address];
	
	if ([abuddy blocked])
		return;
	
	// first a little security check to detect mass pings
	// with faked host names over the same connection
	
	if ([_last_ping_address length] != 0)
	{
		if ([address isEqualToString:_last_ping_address] == NO)
		{
			// DEBUG
			fprintf(stderr, "(1) Possible Attack: in-connection sent fake address '%s'\n", [address UTF8String]);
			fprintf(stderr, "(1) Will disconnect incoming connection from fake '%s'\n", [address UTF8String]);
			
			// Notify
			[self _error:tcctrl_error_client_cmd_ping info:@"core_cctrl_err_fake_ping" fatal:YES];
			
			return;
		}
	}
	else
		_last_ping_address = address;
	
	
	// another check for faked pings: we search all our already
	// *connected* buddies and if there is one with the same address
	// but another incoming connection then this one must be a fake.
	
	if (ctrl)
		abuddy = [ctrl buddyWithAddress:address];
	
	if ([abuddy isPonged])
	{
		[self _error:tcctrl_error_client_cmd_ping info:@"core_cctrl_err_already_pinged" fatal:YES];
		return;
	}
	
	
	// if someone is pinging us with our own address and the
	// random value is not from us, then someone is definitely
	// trying to fake and we can close.
	
	if ([address isEqualToString:[_config selfAddress]] && abuddy && [[abuddy random] isEqualToString:random])
	{
		[self _error:tcctrl_error_client_cmd_ping info:@"core_cctrl_err_masquerade" fatal:YES];
		return;
	}
	
	
	// if the buddy don't exist, add it on the buddy list
	if (!abuddy)
	{
		if (ctrl)
			[ctrl addBuddy:[_config localized:@"core_cctrl_new_buddy"] address:address];
		
		abuddy = [ctrl buddyWithAddress:address];
		
		if (!abuddy)
		{
			[self _error:tcctrl_error_client_cmd_ping info:@"core_cctrl_err_add_buddy" fatal:YES];
			return;
		}
	}
	
	
	// ping messages must be answered with pong messages
	// the pong must contain the same random string as the ping.
	[abuddy startHandshake:random status:[ctrl status] avatar:[ctrl profileAvatar] name:[ctrl profileName] text:[ctrl profileText]];
}

- (void)parser:(TCParser *)parser parsedPongWithRandom:(NSString *)random
{
	TCBuddy			*buddy = NULL;
	TCController	*ctrl = _ctrl;
	
	if (ctrl)
		buddy = [ctrl buddyWithRandom:random];
	
	if (buddy)
	{
		// Check blocked list
		if ([buddy blocked])
		{
			// Stop buddy
			[buddy stop];
			
			// Stop socket
			[_sock stop];
			_sock = nil;
		}
		else
		{
			// Give the baby to buddy
			[buddy setInputConnection:_sock];
			
			// Unhandle socket
			_sock = nil;
		}
	}
	else
		[self _error:tcctrl_error_client_cmd_pong info:@"core_cctrl_err_pong" fatal:YES];
}

- (void)parser:(TCParser *)parser errorWithCode:(tcrec_error)error andInformation:(NSString *)information
{
	tcctrl_info nerr = tcctrl_error_client_unknown_command;
	
	// Convert parser error to controller errors
	switch (error)
	{
		case tcrec_unknown_command:
			nerr = tcctrl_error_client_unknown_command;
			break;
			
		case tcrec_cmd_ping:
			nerr = tcctrl_error_client_cmd_ping;
			break;
			
		case tcrec_cmd_pong:
			nerr = tcctrl_error_client_cmd_pong;
			break;
			
		case tcrec_cmd_status:
			nerr = tcctrl_error_client_cmd_status;
			break;
			
		case tcrec_cmd_version:
			nerr = tcctrl_error_client_cmd_version;
			break;
			
		case tcrec_cmd_client:
			nerr = tcctrl_error_client_cmd_client;
			break;
			
		case tcrec_cmd_profile_text:
			nerr = tcctrl_error_client_cmd_profile_text;
			break;
			
		case tcrec_cmd_profile_name:
			nerr = tcctrl_error_client_cmd_profile_name;
			break;
			
		case tcrec_cmd_profile_avatar:
			nerr = tcctrl_error_client_cmd_profile_avatar;
			break;
			
		case tcrec_cmd_profile_avatar_alpha:
			nerr = tcctrl_error_client_cmd_profile_avatar_alpha;
			break;
			
		case tcrec_cmd_message:
			nerr = tcctrl_error_client_cmd_message;
			break;
			
		case tcrec_cmd_addme:
			nerr = tcctrl_error_client_cmd_addme;
			break;
			
		case tcrec_cmd_removeme:
			nerr = tcctrl_error_client_cmd_removeme;
			break;
			
		case tcrec_cmd_filename:
			nerr = tcctrl_error_client_cmd_filename;
			break;
			
		case tcrec_cmd_filedata:
			nerr = tcctrl_error_client_cmd_filedata;
			break;
			
		case tcrec_cmd_filedataok:
			nerr = tcctrl_error_client_cmd_filedataok;
			break;
			
		case tcrec_cmd_filedataerror:
			nerr = tcctrl_error_client_cmd_filedataerror;
			break;
			
		case tcrec_cmd_filestopsending:
			nerr = tcctrl_error_client_cmd_filestopsending;
			break;
			
		case tcrec_cmd_filestopreceiving:
			nerr = tcctrl_error_client_cmd_filestopreceiving;
			break;
	}
	
	// Parse error is fatal
	[self _error:nerr info:information fatal:YES];
}



/*
** TCControlClient - TCSocketDelegate
*/
#pragma mark - TCControlClient - TCSocketDelegate

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
	// Localize the info
	error->setInfo([[_config localized:@(error->info().c_str())] UTF8String]);
	
	// Fallback Error
	[self _error:tcctrl_error_socket info:@"core_cctrl_err_socket" contextInfo:error fatal:YES];
}



/*
** TCControlClient - Helpers
*/
#pragma mark - TCControlClient - Helpers

- (void)_error:(tcctrl_info)code info:(NSString *)info fatal:(BOOL)fatal
{
	// > localQueue <

	TCController	*ctrl = _ctrl;
	TCInfo			*err = new TCInfo(tcinfo_error, code, [[_config localized:info] UTF8String]);
	
#warning Use delegate for this, no ?
	if (ctrl)
		[ctrl cc_error:self info:err];
	
	err->release();
	
	if (fatal)
		[self stop];
}

- (void)_error:(tcctrl_info)code info:(NSString *)info contextObj:(TCObject *)ctx fatal:(BOOL)fatal
{
	// > localQueue <

	TCController	*ctrl = _ctrl;
	TCInfo			*err = new TCInfo(tcinfo_error, code, [[_config localized:info] UTF8String], ctx);
	
#warning Use delegate for this, no ?
	if (ctrl)
		[ctrl cc_error:self info:err];
	
	err->release();
	
	if (fatal)
		[self stop];
}

- (void)_error:(tcctrl_info)code info:(NSString *)info contextInfo:(TCInfo *)serr fatal:(BOOL)fatal
{
	// > localQueue <

	TCController	*ctrl = _ctrl;
	TCInfo			*err = new TCInfo(tcinfo_error, code, [[_config localized:info] UTF8String], serr);
	
#warning Use delegate for this, no ?
	if (ctrl)
		[ctrl cc_error:self info:err];
	
	err->release();
	
	if (fatal)
		[self stop];
}

- (void)_notify:(tcctrl_info)notice info:(NSString *)info
{
	// > localQueue <
	
	TCController	*ctrl = _ctrl;
	TCInfo			*ifo = new TCInfo(tcinfo_info, notice, [[_config localized:info] UTF8String]);
	
#warning Use delegate for this, no ?
	if (ctrl)
		[ctrl cc_notify:self info:ifo];
	
	ifo->release();
}

- (BOOL)_isBlocked:(NSString *)address
{
	// > localQueue <
	
	if (!_config)
		return false;
	
	NSArray	*blocked = [_config blockedBuddies];

	return ([blocked indexOfObject:address] != NSNotFound);
}

@end
