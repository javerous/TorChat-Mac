/*
 *  TCContoller.h
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#import "TCController.h"

#import "TCConfig.h"
#import "TCImage.h"

#import "TCControlClient.h"
#import "TCBuddy.h"
#import "TCString.h"
#import "TCBuddy.h"
#import "TCTools.h"
#import "TCNumber.h"



/*
** TCController
*/
#pragma mark - TCController

@interface TCController ()
{
	// -- Vars --
	// > Main Queue
	dispatch_queue_t		_mainQueue;
	
	// > Timer
	dispatch_source_t		_timer;
	
	// > Accept Socket
	dispatch_queue_t		_socketQueue;
	dispatch_source_t		_socketAccept;
	int						_sock;
	
	// > Buddies
	BOOL					_buddiesLoaded;
	std::vector<TCBuddy *>	_buddies;
	
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
- (void)_error:(tcctrl_info)code info:(NSString *)info context:(TCObject *)ctx fatal:(BOOL)fatal;

- (void)_notify:(tcctrl_info)notice info:(NSString *)info;
- (void)_notify:(tcctrl_info)notice info:(NSString *)info context:(TCObject *)ctx;

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
		_mainQueue = dispatch_queue_create("com.torchat.core.controller.main", DISPATCH_QUEUE_SERIAL);
		_socketQueue = dispatch_queue_create("com.torchat.core.controller.socket", DISPATCH_QUEUE_SERIAL);

		// Containers.
		_clients = [[NSMutableArray alloc] init];
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
	size_t i, cnt = _buddies.size();
	
	for (i = 0; i < cnt; i++)
	{
		_buddies[i]->stop();
		_buddies[i]->release();
	}
	
	_buddies.clear();
}



/*
** TCController - Life
*/
#pragma mark - TCController - Life

- (void)start
{
	dispatch_async(_mainQueue, ^{
		
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
				TCBuddy			*buddy = new TCBuddy(_config, [item[TCConfigBuddyAlias] UTF8String], [item[TCConfigBuddyAddress] UTF8String], [item[TCConfigBuddyNotes] UTF8String]);
				
				// Check blocked status
				[self _checkBlocked:buddy];
				
				// Add to list
				_buddies.push_back(buddy);
				
				// Notify
				[self _notify:tcctrl_notify_buddy_new info:@"core_ctrl_note_new_buddy" context:buddy];
			}
			
			// -- Check that we are on the buddy list --
			bool				found = false;
			const std::string	self_address = [[_config selfAddress] UTF8String];
			
			cnt = _buddies.size();
			
			for (i = 0; i < cnt; i++)
			{
				TCBuddy	*buddy = _buddies[i];
				
				if (buddy->address().content().compare(self_address) == 0)
				{
					found = true;
					break;
				}
			}
			
			if (!found)
				[self addBuddy:[_config localized:@"core_ctrl_myself"] address:@(self_address.c_str())];
			
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
				dispatch_async(_mainQueue, ^{
					[self _error:tcctrl_error_serv_accept info:@"core_ctrl_err_accept" fatal:YES];
				});
			}
			else
			{
				// Make the client async
				if (!doAsyncSocket(csock))
				{
					dispatch_async(_mainQueue, ^{
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
		_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _mainQueue);
		
		// Each 120s
		dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 120000000000L, 0);
		dispatch_source_set_event_handler(_timer, ^{
			
			// Do nothing if not running
			if (!_running || !_buddiesLoaded)
				return;
			
			// (Re)start buddy (start do nothing if already started)
			size_t i, cnt = cnt = _buddies.size();
			
			for (i = 0; i < cnt; i++)
				_buddies[i]->keepAlive();
			
		});
		dispatch_resume(_timer);
		
		// -- Start buddies --
		size_t i, cnt = _buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = _buddies[i];
			
			buddy->start();
		}
		
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
	dispatch_async(_mainQueue, ^{
		
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
		size_t i, cnt = _buddies.size();
		
		for (i = 0; i < cnt; i++)
			_buddies[i]->stop();
		
		// Notify
		[self _notify:tcctrl_notify_stoped info:@"core_ctrl_note_stoped"];
		
		_running = false;
	});
}

// -- Status --
- (void)setStatus:(tccontroller_status)status
{
	// Give the status
	dispatch_async(_mainQueue, ^{
		
		// Notify
		if (status != _mstatus)
		{
			TCNumber *nstatus = new TCNumber((uint8_t)status);
			
			[self _notify:tcctrl_notify_status info:@"" context:nstatus];
			
			nstatus->release();
		}
		
		// Hold internal status
		_mstatus = status;
		
		// Run the controller if needed, else send status
		if (!_running)
			[self start];
		else
		{
			// Give this status to buddy list
			size_t i, cnt = cnt = _buddies.size();
			
			for (i = 0; i < cnt; i++)
			{
				TCBuddy	*buddy = _buddies[i];
				
				buddy->sendStatus(status);
			}
		}
	});
}

- (tccontroller_status)status
{
	__block tccontroller_status result = tccontroller_available;
	
	dispatch_sync(_mainQueue, ^{
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
	dispatch_async(_mainQueue, ^{
		
		_profileAvatar = avatar;
		
		// Store avatar
		[_config setProfileAvatar:_profileAvatar];
		
		// Give this avatar to buddy list
		size_t i, cnt = cnt = _buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = _buddies[i];
			
			buddy->sendAvatar(_profileAvatar);
		}
		
		// Notify
		[self _notify:tcctrl_notify_profile_avatar info:@"core_ctrl_note_profile_avatar" context:(__bridge TCObject *)_profileAvatar];
	});
}

- (TCImage *)profileAvatar
{
	__block TCImage *result = NULL;
	
	dispatch_sync(_mainQueue, ^{
		
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
	dispatch_async(_mainQueue, ^{
		
		// Hold the name
		_profileName = name;
		
		// Store the name
		[_config setProfileName:name];
		
		// Give this name to buddy list
		size_t		i, cnt = cnt = _buddies.size();
		TCString	*pname = new TCString([_profileName UTF8String]);

		for (i = 0; i < cnt; i++)
		{
			TCBuddy *buddy = _buddies[i];
			
			buddy->sendProfileName(pname);
		}
		
		// Notify
		[self _notify:tcctrl_notify_profile_name info:@"core_ctrl_note_profile_name" context:pname];
		
		pname->release();
	});
}

- (NSString *)profileName
{
	__block NSString *result = NULL;
	
	dispatch_sync(_mainQueue, ^{
		result = _profileName;
	});
	
	return result;
}

- (void)setProfileText:(NSString *)text
{
	if (!text)
		return;
	
	// Set the avatar
	dispatch_async(_mainQueue, ^{
		
		// Hold the text
		_profileText = text;
		
		// Store the text
		[_config setProfileText:text];
		
		// Give this text to buddy list
		size_t		i, cnt = cnt = _buddies.size();
		TCString	*ptext = new TCString([_profileText UTF8String]);

		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = _buddies[i];
			
			buddy->sendProfileText(ptext);
		}
		
		// Notify
		[self _notify:tcctrl_notify_profile_text info:@"core_ctrl_note_profile_name" context:ptext];
		
		ptext->release();
	});
}

- (NSString *)profileText
{
	__block NSString *result = NULL;
	
	dispatch_sync(_mainQueue, ^{
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
	
	TCBuddy *buddy = new TCBuddy(_config, [name UTF8String], [address UTF8String], [comment UTF8String]);
	
    dispatch_async(_mainQueue, ^{
        
		// Check blocked status
		[self _checkBlocked:buddy];
		
        // Add to the buddy list
        _buddies.push_back(buddy);
		
		// Notify
		[self _notify:tcctrl_notify_buddy_new info:@"core_ctrl_note_new_buddy" context:buddy];
		
        // Start it
        buddy->start();
		
		// Save to config
		[_config addBuddy:address alias:name notes:comment];
    });
}

- (void)removeBuddy:(NSString *)address
{
	dispatch_async(_mainQueue, ^{
		
		size_t	i, cnt = _buddies.size();
		
		// Search the buddy
		for (i = 0; i < cnt; i++)
		{
			if (_buddies[i]->address().content().compare([address UTF8String]) == 0)
			{
				// Stop and release
				TCBuddy	*buddy = _buddies[i];
				
				buddy->stop();
				buddy->release();
				
				_buddies.erase(_buddies.begin() + (ptrdiff_t)i);
				
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
		return NULL;
	
    __block TCBuddy *result = NULL;
	
	dispatch_sync(_mainQueue, ^{
        
        size_t i, cnt = cnt = _buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = _buddies[i];
            
            if (buddy->address().content().compare([address UTF8String]) == 0)
            {
                result = buddy;
				result->retain();
				
                break;
            }
        }
    });
	
    return result;
}

- (TCBuddy *)buddyWithRandom:(NSString *)random
{
    __block TCBuddy *result = NULL;
	
	dispatch_sync(_mainQueue, ^{
        
        size_t i, cnt = cnt = _buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = _buddies[i];
            
            if (buddy->brandom().content().compare([random UTF8String]) == 0)
            {
                result = buddy;
				result->retain();
				
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
	
	dispatch_sync(_mainQueue, ^{
		
		// Add the address to the configuration
		if ([_config addBlockedBuddy:address] == YES)
			result = YES;
	});
	
	// Mark the buddy as blocked
	if (result)
	{
		TCBuddy * buddy = [self buddyWithAddress:address];
		
		if (buddy)
		{
			buddy->setBlocked(true);
			buddy->release();
		}
	}
	
	return result;
}

- (BOOL)removeBlockedBuddy:(NSString *)address
{
	__block BOOL result = false;
	
	dispatch_sync(_mainQueue, ^{
		
		// Remove the address from the configuration
		if ([_config removeBlockedBuddy:address] == YES)
			result = YES;
	});
	
	// Mark the buddy as un-blocked
	if (result)
	{
		TCBuddy * buddy = [self buddyWithAddress:address];
		
		if (buddy)
		{
			buddy->setBlocked(false);
			buddy->release();
		}
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
	info->retain();
	
	dispatch_async(_mainQueue, ^{
		[self _sendEvent:info];
		info->release();
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
	
	info->retain();
	
	dispatch_async(_mainQueue, ^{
		[self _sendEvent:info];
		info->release();
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
	// > mainQueue <
	
	if (!_config)
		return;
	
	// XXX not thread safe
	NSArray	*blocked = [_config blockedBuddies];
	size_t	i, cnt = [blocked count];
	
	buddy->setBlocked(false);
	
	// Search
	for (i = 0; i < cnt; i++)
	{
		const std::string address = [blocked[i] UTF8String];
		
		if (address.compare(buddy->address().content()) == 0)
		{
			buddy->setBlocked(true);
			buddy->stop();
			break;
		}
	}
}


- (void)_error:(tcctrl_info)code info:(NSString *)info fatal:(BOOL)fatal
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, [[_config localized:info] UTF8String]);
	
	[self _sendEvent:err];
	
	err->release();
	
	if (fatal)
		[self stop];
}

- (void)_error:(tcctrl_info)code info:(NSString *)info context:(TCObject *)ctx fatal:(BOOL)fatal
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, [[_config localized:info] UTF8String], ctx);
	
	[self _sendEvent:err];
	
	err->release();
	
	if (fatal)
		[self stop];
}

- (void)_notify:(tcctrl_info)notice info:(NSString *)info
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice, [[_config localized:info] UTF8String]);
	
	[self _sendEvent:ifo];

	ifo->release();
}

- (void)_notify:(tcctrl_info)notice info:(NSString *)info context:(TCObject *)ctx
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice, [[_config localized:info] UTF8String], ctx);
	
	[self _sendEvent:ifo];
	
	ifo->release();
}

- (void)_sendEvent:(TCInfo *)info
{
	// > mainQueue <
	
	if (!info)
		return;
	
	id <TCControllerDelegate> delegate = self.delegate;
	
	if (delegate)
	{
		info->retain();
		
		dispatch_async(_delegateQueue, ^{
			
			[delegate torchatController:self information:info];
			
			info->release();
		});
	}
}

@end
