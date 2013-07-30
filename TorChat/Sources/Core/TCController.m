/*
 *  TCContoller.h
 *
 *  Copyright 2013 Avérous Julien-Pierre
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#import "TCController.h"

#import "TCConfig.h"
#import "TCImage.h"

#import "TCControlClient.h"
#import "TCBuddy.h"
#import "TCBuddy.h"
#import "TCTools.h"



/*
** TCController
*/
#pragma mark - TCController

@interface TCController ()
{
	// -- Vars --
	// > Main Queue
	dispatch_queue_t		_localQueue;
	
	// > Timer
	dispatch_source_t		_timer;
	
	// > Accept Socket
	dispatch_queue_t		_socketQueue;
	dispatch_source_t		_socketAccept;
	int						_sock;
	
	// > Buddies
	BOOL					_buddiesLoaded;
	NSMutableArray			*_buddies;
	
	// > Config
	id <TCConfig>			_config;
	
	// > Clients
	NSMutableArray			*_clients;
	
	// > Status
	bool					_running;
	tccontroller_status		_mstatus;
	
	// > Delegate
	dispatch_queue_t		_delegateQueue;
	
	// > Profile
	TCImage					*_profileAvatar;
	NSString				*_profileName;
	NSString				*_profileText;
}

// -- Helpers --
- (void)_addClient:(int)sock;
- (void)_checkBlocked:(TCBuddy *)buddy;

- (void)_error:(tcctrl_info)code info:(NSString *)info fatal:(BOOL)fatal;
- (void)_error:(tcctrl_info)code info:(NSString *)info context:(id)ctx fatal:(BOOL)fatal;

- (void)_notify:(tcctrl_info)notice info:(NSString *)info;
- (void)_notify:(tcctrl_info)notice info:(NSString *)info context:(id)ctx;

- (void)_sendEvent:(TCInfo *)info;

@end



/*
** TCController
*/
#pragma mark - TCController

@implementation TCController


/*
** TCController - Instance
*/
#pragma mark - TCController - Instance

- (id)initWithConfiguration:(id <TCConfig>)config
{
	self = [super init];
	
	if (self)
	{
		config = _config;
		
		// Init vars
		_mstatus = tccontroller_available;

		// Get profile avatar
		_profileAvatar = [config profileAvatar];
		
		if (!_profileAvatar)
			_profileAvatar = [[TCImage alloc] initWithWidth:64 andHeight:64];
		
		// Get profile name & text
		_profileName = [config profileName];
		_profileText = [config profileText];
		
		// Alloc queue
		_localQueue = dispatch_queue_create("com.torchat.core.controller.local", DISPATCH_QUEUE_SERIAL);
		_socketQueue = dispatch_queue_create("com.torchat.core.controller.socket", DISPATCH_QUEUE_SERIAL);
		_delegateQueue = dispatch_queue_create("com.torchat.core.controller.delegate", DISPATCH_QUEUE_SERIAL);
		
		// Containers.
		_clients = [[NSMutableArray alloc] init];
		_buddies = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog("TCController Destructor");
	
	// Close client
	for (TCControlClient *client in _clients)
		[client stop];

	// Stop buddies
	for (TCBuddy *buddy in _buddies)
		[buddy stop];
}



/*
** TCController - Life
*/
#pragma mark - TCController - Life

- (void)start
{
	dispatch_async(_localQueue, ^{
		
		if (_running)
			return;
		
		if (!_buddiesLoaded)
		{
			NSArray *sbuddies = [_config buddies];
			size_t	i, cnt;
			
			//  -- Parse buddies --
			cnt = [sbuddies count];
			
			for (i = 0; i < cnt; i++)
			{
				NSDictionary	*item = sbuddies[i];
				TCBuddy			*buddy = [[TCBuddy alloc] initWithConfiguration:_config alias:item[TCConfigBuddyAlias] address:item[TCConfigBuddyAddress] notes:item[TCConfigBuddyNotes]];
								
				// Check blocked status
				[self _checkBlocked:buddy];
				
				// Add to list
				[_buddies addObject:buddy];
				
				// Notify
				[self _notify:tcctrl_notify_buddy_new info:@"core_ctrl_note_new_buddy" context:buddy];
			}
			
			// -- Check that we are on the buddy list --
			BOOL		found = NO;
			NSString	*selfAddress = [_config selfAddress];
			
			
			for (TCBuddy	*buddy in _buddies)
			{
				if ([[buddy address] isEqualToString:selfAddress])
				{
					found = true;
					break;
				}
			}
			
			if (!found)
				[self addBuddy:[_config localized:@"core_ctrl_myself"] address:selfAddress];
			
			// -- Buddy are loaded --
			_buddiesLoaded = true;
		}
		
		// -- Start command server --
		struct sockaddr_in	my_addr;
		int					yes = 1;
		
		// > Configure the port and address
		my_addr.sin_family = AF_INET;
		my_addr.sin_port = htons([_config clientPort]);
		my_addr.sin_addr.s_addr = INADDR_ANY;
		memset(&(my_addr.sin_zero), '\0', 8);
		
		// > Instanciate the listening socket
		if ((_sock = socket(AF_INET, SOCK_STREAM, 0)) == -1)
		{
			[self _error:tcctrl_error_serv_socket info:@"core_ctrl_err_socket" fatal:YES];
			return;
		}
		
		// > Reuse the port
		if (setsockopt(_sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1)
		{
			[self _error:tcctrl_error_serv_socket info:@"core_ctrl_err_setsockopt" fatal:YES];
			return;
		}
		
		// > Bind the socket to the configuration perviously set
		if (bind(_sock, (struct sockaddr *)&my_addr, sizeof(struct sockaddr)) == -1)
		{
			[self _error:tcctrl_error_serv_socket info:@"core_ctrl_err_bind" fatal:YES];
			return;
		}
		
		// > Set the socket as a listening socket
		if (listen(_sock, 10) == -1)
		{
			[self _error:tcctrl_error_serv_socket info:@"core_ctrl_err_listen" fatal:YES];
			return;
		}
		
		// > Build a source
		_socketAccept = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)_sock, 0, _socketQueue);
		
		// > Set the read handler
		dispatch_source_set_event_handler(_socketAccept, ^{
			
			unsigned int		sin_size = sizeof(struct sockaddr);
			struct sockaddr_in	their_addr;
			int					csock;
			
			csock = accept(_sock, (struct sockaddr *)&their_addr, &sin_size);
			
			if (csock == -1)
			{
				dispatch_async(_localQueue, ^{
					[self _error:tcctrl_error_serv_accept info:@"core_ctrl_err_accept" fatal:YES];
				});
			}
			else
			{
				// Make the client async
				if (!doAsyncSocket(csock))
				{
					dispatch_async(_localQueue, ^{
						[self _error:tcctrl_error_serv_accept info:@"core_ctrl_err_async" fatal:YES];
					});
					
					return;
				}
				
				// Add it later
				dispatch_async(_socketQueue, ^{
					[self _addClient:csock];
				});
			}
		});
		
		// > Set the cancel handler
		dispatch_source_set_cancel_handler(_socketAccept, ^{
			close(_sock);
			_sock = -1;
		});
		
		dispatch_resume(_socketAccept);
		
		
		// -- Build a timer to keep alive buddies (start or sendStatus) --
		_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
		
		// Each 120s
		dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 120000000000L, 0);
		dispatch_source_set_event_handler(_timer, ^{
			
			// Do nothing if not running
			if (!_running || !_buddiesLoaded)
				return;
			
			// (Re)start buddy (start do nothing if already started)
			for (TCBuddy *buddy in _buddies)
				[buddy keepAlive];
			
		});
		dispatch_resume(_timer);
		
		// -- Start buddies --
		for (TCBuddy *buddy in _buddies)
			[buddy start];
		
		// Give the status
		[self setStatus:_mstatus];
		
		// Notify
		[self _notify:tcctrl_notify_started info:@"core_ctrl_note_started"];
		
		// We are running !
		_running = YES;
	});
}

- (void)stop
{
	dispatch_async(_localQueue, ^{
		
		// Check if we are running
		if (!_running)
			return;
		
		// Cancel the socket
		dispatch_source_cancel(_socketAccept);
		
		// Cancel the timer
		if (_timer)
			dispatch_source_cancel(_timer);
		
		_socketAccept = nil;
		
		// Stop & release clients
		for (TCControlClient *client in _clients)
			[client stop];
		
		[_clients removeAllObjects];
		
		// Stop buddies
		for (TCBuddy *buddy in _buddies)
			[buddy stop];
		
		// Notify
		[self _notify:tcctrl_notify_stoped info:@"core_ctrl_note_stoped"];
		
		_running = false;
	});
}

// -- Status --
- (void)setStatus:(tccontroller_status)status
{
	// Give the status
	dispatch_async(_localQueue, ^{
		
		// Notify
		if (status != _mstatus)
			[self _notify:tcctrl_notify_status info:@"" context:@(status)];
		
		// Hold internal status
		_mstatus = status;
		
		// Run the controller if needed, else send status
		if (!_running)
			[self start];
		else
		{
			// Give this status to buddy list
			for (TCBuddy *buddy in _buddies)
				[buddy sendStatus:status];
		}
	});
}

- (tccontroller_status)status
{
	__block tccontroller_status result = tccontroller_available;
	
	dispatch_sync(_localQueue, ^{
		result = _mstatus;
	});
	
	return result;
}

// -- Profile --
- (void)setProfileAvatar:(TCImage *)avatar
{
	if (!avatar)
		return;
	
	// Set the avatar
	dispatch_async(_localQueue, ^{
		
		_profileAvatar = avatar;
		
		// Store avatar
		[_config setProfileAvatar:_profileAvatar];
		
		// Give this avatar to buddy list
		for (TCBuddy *buddy in _buddies)
			[buddy sendAvatar:_profileAvatar];
		
		// Notify
		[self _notify:tcctrl_notify_profile_avatar info:@"core_ctrl_note_profile_avatar" context:_profileAvatar];
	});
}

- (TCImage *)profileAvatar
{
	__block TCImage *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		
		if (_profileAvatar)
			result = [_profileAvatar copy];
	});
	
	return result;
}


- (void)setProfileName:(NSString *)name
{
	if (!name)
		return;
	
	// Set the avatar
	dispatch_async(_localQueue, ^{
		
		// Hold the name
		_profileName = name;
		
		// Store the name
		[_config setProfileName:name];
		
		// Give this name to buddy list
		for (TCBuddy *buddy in _buddies)
			[buddy sendProfileName:_profileName];
		
		// Notify
		[self _notify:tcctrl_notify_profile_name info:@"core_ctrl_note_profile_name" context:_profileName];
	});
}

- (NSString *)profileName
{
	__block NSString *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _profileName;
	});
	
	return result;
}

- (void)setProfileText:(NSString *)text
{
	if (!text)
		return;
	
	// Set the avatar
	dispatch_async(_localQueue, ^{
		
		// Hold the text
		_profileText = text;
		
		// Store the text
		[_config setProfileText:text];
		
		// Give this text to buddy list
		for (TCBuddy *buddy in _buddies)
			[buddy sendProfileText:_profileText];

		// Notify
		[self _notify:tcctrl_notify_profile_text info:@"core_ctrl_note_profile_name" context:_profileText];
	});
}

- (NSString *)profileText
{
	__block NSString *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		result = _profileText;
	});
	
	return result;
}

// -- Buddies --
- (void)addBuddy:(NSString *)name address:(NSString *)address
{
	[self addBuddy:name address:address comment:@""];
}

- (void)addBuddy:(NSString *)name address:(NSString *)address comment:(NSString *)comment
{
	if (!address)
		return;
	
	if (!name)
		name = @"";
	
	if (!comment)
		comment = @"";
	
	TCBuddy *buddy = [[TCBuddy alloc] initWithConfiguration:_config alias:name address:address notes:comment];
	
    dispatch_async(_localQueue, ^{
        
		// Check blocked status
		[self _checkBlocked:buddy];
		
        // Add to the buddy list
		[_buddies addObject:buddy];
		
		// Notify
		[self _notify:tcctrl_notify_buddy_new info:@"core_ctrl_note_new_buddy" context:buddy];
		
        // Start it
		[buddy start];
		
		// Save to config
		[_config addBuddy:address alias:name notes:comment];
    });
}

- (void)removeBuddy:(NSString *)address
{
	if (!address)
		return;
	
	dispatch_async(_localQueue, ^{
		
		NSUInteger	i, cnt = [_buddies count];
		
		// Search the buddy
		for (i = 0; i < cnt; i++)
		{
			TCBuddy *buddy = _buddies[i];
			
			if ([[buddy address] isEqualToString:address])
			{
				// Stop and release
				[buddy stop];
				
				[_buddies removeObjectAtIndex:i];
				
				// Save to config
				[_config removeBuddy:address];
				
				break;
			}
		}
	});
}

- (TCBuddy *)buddyWithAddress:(NSString *)address
{
	if (!address)
		return nil;
	
    __block TCBuddy *result = NULL;
	
	dispatch_sync(_localQueue, ^{
        
		for (TCBuddy *buddy in _buddies)
		{
			if ([[buddy address] isEqualToString:address])
			{
				result = buddy;
				break;
			}
        }
    });
	
    return result;
}

- (TCBuddy *)buddyWithRandom:(NSString *)random
{
	if (!random)
		return nil;
	
    __block TCBuddy *result = NULL;
	
	dispatch_sync(_localQueue, ^{
		
		for (TCBuddy *buddy in _buddies)
		{
			if ([[buddy random] isEqualToString:random])
            {
                result = buddy;
                break;
            }
        }
    });
    
    return result;
}

// -- Blocked Buddies --
- (BOOL)addBlockedBuddy:(NSString *)address
{
	__block BOOL result = false;
	
	dispatch_sync(_localQueue, ^{
		
		// Add the address to the configuration
		if ([_config addBlockedBuddy:address] == YES)
			result = YES;
	});
	
	// Mark the buddy as blocked
	if (result)
	{
		TCBuddy *buddy = [self buddyWithAddress:address];
		
		[buddy setBlocked:YES];
	}
	
	return result;
}

- (BOOL)removeBlockedBuddy:(NSString *)address
{
	__block BOOL result = false;
	
	dispatch_sync(_localQueue, ^{
		
		// Remove the address from the configuration
		if ([_config removeBlockedBuddy:address] == YES)
			result = YES;
	});
	
	// Mark the buddy as un-blocked
	if (result)
	{
		TCBuddy *buddy = [self buddyWithAddress:address];
		
		[buddy setBlocked:NO];
	}
	
	return result;
}

// -- TCControlClient --
- (void)cc_error:(TCControlClient *)client info:(TCInfo *)info
{
#warning Why not a delegate ?
	if (!client || !info)
		return;
	
	// Give the error
	dispatch_async(_localQueue, ^{
		[self _sendEvent:info];
	});
	
	// Remove the client
	dispatch_async(_socketQueue, ^{
		
		NSUInteger i, cnt = [_clients count];
		
		for (i = 0; i < cnt; i++)
		{
			TCControlClient *item = _clients[i];
			
			if (item == client)
			{
				[_clients removeObjectAtIndex:i];
				
				[item stop];
				break;
			}
		}
	});
}

- (void)cc_notify:(TCControlClient *)client info:(TCInfo *)info
{
#warning Why not a delegate ?

	if (!client || !info)
		return;
	
	dispatch_async(_localQueue, ^{
		[self _sendEvent:info];
	});
}

// -- Helpers --
- (void)_addClient:(int)csock
{
	// > socketQueue <
	
	TCControlClient *client = [[TCControlClient alloc] initWithConfiguration:_config andSocket:csock];
	
	[_clients addObject:client];
	
	[client startWithController:self];
}

- (void)_checkBlocked:(TCBuddy *)buddy
{
	// > localQueue <
	
	if (!_config)
		return;
	
	// XXX not thread safe
	NSArray	*blocked = [_config blockedBuddies];
	size_t	i, cnt = [blocked count];
	
	[buddy setBlocked:NO];
	
	// Search
	for (i = 0; i < cnt; i++)
	{
		NSString *address = blocked[i];
		
		if ([address isEqualToString:[buddy address]])
		{
			[buddy setBlocked:YES];
			[buddy stop];
			break;
		}
	}
}


- (void)_error:(tcctrl_info)code info:(NSString *)info fatal:(BOOL)fatal
{
	// > localQueue <
	
	TCInfo *err = [TCInfo infoOfKind:tcinfo_error infoCode:code infoString:[_config localized:info]];

	[self _sendEvent:err];
		
	if (fatal)
		[self stop];
}

- (void)_error:(tcctrl_info)code info:(NSString *)info context:(id)ctx fatal:(BOOL)fatal
{
	// > localQueue <
		
	TCInfo *err = [TCInfo infoOfKind:tcinfo_error infoCode:code infoString:[_config localized:info] context:ctx];
	
	[self _sendEvent:err];
	
	if (fatal)
		[self stop];
}

- (void)_notify:(tcctrl_info)notice info:(NSString *)info
{
	// > localQueue <
		
	TCInfo *ifo = [TCInfo infoOfKind:tcinfo_info infoCode:notice infoString:[_config localized:info]];

	[self _sendEvent:ifo];
}

- (void)_notify:(tcctrl_info)notice info:(NSString *)info context:(id)ctx
{
	// > localQueue <
	
	TCInfo *ifo = [TCInfo infoOfKind:tcinfo_info infoCode:notice infoString:[_config localized:info] context:ctx];

	[self _sendEvent:ifo];
}

- (void)_sendEvent:(TCInfo *)info
{
	// > localQueue <
	
	if (!info)
		return;
	
	id <TCControllerDelegate> delegate = self.delegate;
	
	if (delegate)
	{
		dispatch_async(_delegateQueue, ^{
			[delegate torchatController:self information:info];
		});
	}
}

@end
