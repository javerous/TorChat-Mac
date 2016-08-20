/*
 *  TCCoreManager.m
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

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#import <SMFoundation/SMFoundation.h>

#import "TCCoreManager.h"
#import "TCConnection.h"

#import "TCDebugLog.h"

#import "TCConfigCore.h"
#import "TCImage.h"

#import "TCBuddy.h"
#import "TCBuddy.h"
#import "TCTools.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCCoreManager
*/
#pragma mark - TCCoreManager

@interface TCCoreManager () <TCConnectionDelegate>
{
	// -- Vars --
	// > Main Queue
	dispatch_queue_t		_localQueue;
	
	// > Accept Socket
	dispatch_queue_t		_socketQueue;
	dispatch_source_t		_socketAccept;
	int						_sock;
	
	// > Buddies
	NSMutableArray			*_buddies;
	
	// > Config
	id <TCConfigCore>		_config;
	NSString				*_selfIdentifier;
	
	// > Clients
	NSMutableArray			*_connections;
	
	// > Status
	bool					_running;
	TCStatus				_mstatus;
	
	// > Profile
	TCImage					*_profileAvatar;
	NSString				*_profileName;
	NSString				*_profileText;
	
	// > Observers
	NSHashTable				*_observers;
	dispatch_queue_t		_externalQueue;
}

// -- Blocked --
- (void)_checkBlocked:(TCBuddy *)buddy;

// -- Connection --
- (void)_addConnectionSocket:(int)sock;
- (void)removeConnection:(TCConnection *)connection;

// -- Helpers --
- (void)_error:(TCCoreError)code fatal:(BOOL)fatal;
- (void)_error:(TCCoreError)code context:(id)ctx fatal:(BOOL)fatal;

- (void)_notify:(TCCoreEvent)notice;
- (void)_notify:(TCCoreEvent)notice context:(id)ctx;

- (void)_sendEvent:(SMInfo *)info;

@end



/*
** TCCoreManager
*/
#pragma mark - TCCoreManager

@implementation TCCoreManager


/*
** TCCoreManager - Instance
*/
#pragma mark - TCCoreManager - Instance

+ (void)initialize
{
	[self registerInfoDescriptors];
}

- (nullable instancetype)initWithConfiguration:(id <TCConfigCore>)config
{
	self = [super init];
	
	if (self)
	{
		_config = config;
		
		// Hold self identifier.
		_selfIdentifier = config.selfIdentifier;
		
		if (_selfIdentifier == nil)
			return nil;
		
		// Init vars.
		_mstatus = TCStatusAvailable;

		// Get profile avatar.
		_profileAvatar = [config profileAvatar];

		// Get profile name & text.
		_profileName = [config profileName];
		_profileText = [config profileText];
		
		// Queues.
		_localQueue = dispatch_queue_create("com.torchat.core.controller.local", DISPATCH_QUEUE_SERIAL);
		_socketQueue = dispatch_queue_create("com.torchat.core.controller.socket", DISPATCH_QUEUE_SERIAL);
		_externalQueue = dispatch_queue_create("com.torchat.core.controller.external", DISPATCH_QUEUE_SERIAL);
		
		// Containers.
		_connections = [[NSMutableArray alloc] init];
		_buddies = [[NSMutableArray alloc] init];
		_observers = [NSHashTable weakObjectsHashTable];
		
		// Load buddies.
		// > Get saved buddies.
		NSArray *configBuddies = [_config buddiesIdentifiers];

		[configBuddies enumerateObjectsUsingBlock:^(NSString * _Nonnull buddyIdentifier, NSUInteger idx, BOOL * _Nonnull stop) {
			
			NSString	*alias = [_config buddyAliasForBuddyIdentifier:buddyIdentifier];
			NSString	*notes = [_config buddyNotesForBuddyIdentifier:buddyIdentifier];
			TCBuddy		*buddy = [[TCBuddy alloc] initWithCoreManager:self configuration:_config identifier:buddyIdentifier alias:alias notes:notes];

			// Check blocked status
			[self _checkBlocked:buddy];
			
			// Add to list
			[_buddies addObject:buddy];
		}];
		
		// > Check we are on buddy list.
		BOOL found = NO;
		
		for (TCBuddy *buddy in _buddies)
		{
			if ([[buddy identifier] isEqualToString:_selfIdentifier])
			{
				found = true;
				break;
			}
		}
		
		if (!found)
		{
			// Add buddy in config.
			[_config addBuddyWithIdentifier:_selfIdentifier alias:nil notes:nil];
			[_config setBuddyLastName:_config.profileName forBuddyIdentifier:_selfIdentifier];
			
			// Add buddy in our list.
			TCBuddy *buddy = [[TCBuddy alloc] initWithCoreManager:self configuration:_config identifier:_selfIdentifier alias:nil notes:nil];
			
			[self _checkBlocked:buddy];
			[_buddies addObject:buddy];
		}
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCCoreManager dealloc");
	
	// Close client
	for (TCConnection *connection in _connections)
		[connection stopWithCompletionHandler:nil];

	// Stop buddies
	for (TCBuddy *buddy in _buddies)
		[buddy stopWithCompletionHandler:nil];
}



/*
** TCCoreManager - Life
*/
#pragma mark - TCCoreManager - Life

- (void)start
{
	dispatch_async(_localQueue, ^{
		[self _start];
	});
}

- (void)_start
{
	// > localQueue <
	
	if (_running)
		return;
	
	// -- Start command server --
	struct sockaddr_in	my_addr;
	int					yes = 1;
	
	// > Configure the port and address
	my_addr.sin_family = AF_INET;
	my_addr.sin_port = htons(_config.selfPort);
	my_addr.sin_addr.s_addr = INADDR_ANY;
	memset(&(my_addr.sin_zero), '\0', 8);
	
	// > Instanciate the listening socket
	if ((_sock = socket(AF_INET, SOCK_STREAM, 0)) == -1)
	{
		[self _error:TCCoreErrorSocketCreate fatal:YES];
		return;
	}
	
	// > Reuse the port
	if (setsockopt(_sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1)
	{
		[self _error:TCCoreErrorSocketOption fatal:YES];
		return;
	}
	
	// > Bind the socket to the configuration perviously set
	if (bind(_sock, (struct sockaddr *)&my_addr, sizeof(struct sockaddr)) == -1)
	{
		[self _error:TCCoreErrorSocketBind fatal:YES];
		return;
	}
	
	// > Set the socket as a listening socket
	if (listen(_sock, 10) == -1)
	{
		[self _error:TCCoreErrorSocketListen fatal:YES];
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
				[self _error:TCCoreErrorServAccept fatal:NO];
			});
		}
		else
		{
			// Make the client async
			if (!doAsyncSocket(csock))
			{
				dispatch_async(_localQueue, ^{
					[self _error:TCCoreErrorServAcceptAsync fatal:NO];
				});
				
				return;
			}
			
			// Add it later
			dispatch_async(_socketQueue, ^{
				[self _addConnectionSocket:csock];
			});
		}
	});
	
	// > Set the cancel handler
	dispatch_source_set_cancel_handler(_socketAccept, ^{
		close(_sock);
		_sock = -1;
	});
	
	dispatch_resume(_socketAccept);
	
	// -- Start buddies --
	for (TCBuddy *buddy in _buddies)
		[buddy start];
	
	// Give the status
	[self setStatus:_mstatus];
	
	// Notify
	[self _notify:TCCoreEventStarted];
	
	// We are running
	_running = YES;
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_async(_localQueue, ^{
		[self _stopWithCompletionHandler:handler];
	});
}

- (void)_stopWithCompletionHandler:(nullable dispatch_block_t)handler
{
	// > localQueue <
	
	if (!handler)
		handler = ^{ };
	
	// Check if we are running.
	if (!_running)
	{
		handler();
		return;
	}
	
	dispatch_group_t group = dispatch_group_create();

	// Cancel the socket.
	if (_socketAccept)
	{
		dispatch_source_cancel(_socketAccept);
		_socketAccept = nil;
	}
	
	// Stop & release clients.
	for (TCConnection *connection in _connections)
	{
		dispatch_group_enter(group);
		
		[connection stopWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}
	
	[_connections removeAllObjects];
	
	// Stop buddies.
	for (TCBuddy *buddy in _buddies)
	{
		dispatch_group_enter(group);
		
		[buddy stopWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}
	
	// Notify.
	[self _notify:TCCoreEventStopped];
	
	_running = false;
	
	// Wait end.
	dispatch_group_notify(group, _externalQueue, handler);
}


/*
** TCCoreManager - Status
*/
#pragma mark - TCCoreManager - Status

- (void)setStatus:(TCStatus)status
{
	// Give the status
	dispatch_async(_localQueue, ^{
		
		// Check & hold status.
		if (status == _mstatus)
			return;

		_mstatus = status;
		
		if (status == TCStatusOffline)
		{
			// Stop the controller.
			[self _stopWithCompletionHandler:nil];
		}
		else
		{
			// Run the controller if needed, else send status
			if (!_running)
				[self _start];
			else
			{
				// Give this status to buddy list
				for (TCBuddy *buddy in _buddies)
					[buddy sendStatus:status];
			}
		}
		
		// Notify
		[self _notify:TCCoreEventStatus context:@(status)];
	});
}

- (TCStatus)status
{
	__block TCStatus result = TCStatusAvailable;
	
	dispatch_sync(_localQueue, ^{
		result = _mstatus;
	});
	
	return result;
}



/*
** TCCoreManager - Profile
*/
#pragma mark - TCCoreManager - Profile

- (void)setProfileAvatar:(nullable TCImage *)avatar
{
	// Set the avatar
	dispatch_async(_localQueue, ^{
		
		_profileAvatar = avatar;
		
		// Store avatar
		[_config setProfileAvatar:_profileAvatar];
		
		// Give this avatar to buddy list
		for (TCBuddy *buddy in _buddies)
			[buddy sendAvatar:_profileAvatar];
		
		// Notify
		[self _notify:TCCoreEventProfileAvatar context:_profileAvatar];
	});
}

- (nullable TCImage *)profileAvatar
{
	__block id result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _profileAvatar;
	});
	
	return result;
}


- (void)setProfileName:(nullable NSString *)name
{
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
		[self _notify:TCCoreEventProfileName context:_profileName];
	});
}

- (nullable NSString *)profileName
{
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _profileName;
	});
	
	return result;
}

- (void)setProfileText:(nullable NSString *)text
{
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
		[self _notify:TCCoreEventProfileText context:_profileText];
	});
}

- (nullable NSString *)profileText
{
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _profileText;
	});
	
	return result;
}


/*
** TCCoreManager - Buddies
*/
#pragma mark - TCCoreManager - Buddies

- (NSArray *)buddies
{
	__block NSArray *buddies;
	
	dispatch_sync(_localQueue, ^{
		buddies = [_buddies copy];
	});
	
	return buddies;
}

- (void)addBuddyWithIdentifier:(NSString *)identifier name:(nullable NSString *)name
{
	[self addBuddyWithIdentifier:identifier name:name comment:@""];
}

- (void)addBuddyWithIdentifier:(NSString *)identifier name:(nullable NSString *)name comment:(nullable NSString *)comment
{
	NSAssert(identifier, @"identifier is nil");
	
	TCBuddy *buddy = [[TCBuddy alloc] initWithCoreManager:self configuration:_config identifier:identifier alias:name notes:comment];
	
    dispatch_async(_localQueue, ^{
        
		// Check blocked status.
		[self _checkBlocked:buddy];
		
        // Add to the buddy list.
		[_buddies addObject:buddy];
		
		// Notify.
		[self _notify:TCCoreEventBuddyNew context:buddy];
		
        // Start it.
		if (_running)
			[buddy start];
		
		// Save to config.
		[_config addBuddyWithIdentifier:identifier alias:name notes:comment];
    });
}

- (void)removeBuddyWithIdentifier:(NSString *)identifier
{
	NSAssert(identifier, @"identifier is nil");

	dispatch_async(_localQueue, ^{
		
		NSUInteger	i, cnt = [_buddies count];
		
		// Search the buddy.
		for (i = 0; i < cnt; i++)
		{
			TCBuddy *buddy = _buddies[i];
			
			if ([[buddy identifier] isEqualToString:identifier])
			{
				// Stop and release.
				[buddy stopWithCompletionHandler:nil];
				
				[_buddies removeObjectAtIndex:i];
				
				// Save to config.
				[_config removeBuddyWithIdentifier:identifier];
				
				// Notify.
				[self _notify:TCCoreEventBuddyRemove context:buddy];
				
				break;
			}
		}
	});
}

- (nullable TCBuddy *)buddyWithIdentifier:(NSString *)identifier
{
	NSAssert(identifier, @"identifier is nil");
	
    __block TCBuddy *result = nil;
	
	dispatch_sync(_localQueue, ^{
        
		for (TCBuddy *buddy in _buddies)
		{
			if ([[buddy identifier] isEqualToString:identifier])
			{
				result = buddy;
				break;
			}
        }
    });
	
    return result;
}

- (nullable TCBuddy *)buddyWithRandom:(NSString *)random
{
	NSAssert(random, @"random is nil");
	
    __block TCBuddy *result = nil;
	
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



/*
** TCCoreManager - Blocked Buddies
*/
#pragma mark - TCCoreManager - Blocked Buddies

- (void)addBlockedBuddyWithIdentifier:(NSString *)identifier
{
	// Add blocked buddy to configuration.
	[_config addBlockedBuddyWithIdentifier:identifier];
	
	// Mark the buddy as blocked.
	TCBuddy *buddy = [self buddyWithIdentifier:identifier];
	
	if (buddy)
	{
		[buddy setBlocked:YES];
		[buddy stopWithCompletionHandler:nil];
	
		dispatch_async(_localQueue, ^{
			[self _notify:TCCoreEventBuddyBlocked context:buddy];
		});
	}
}

- (void)removeBlockedBuddyWithIdentifier:(NSString *)identifier
{
	// Remove blocked buddy from configuration.
	[_config removeBlockedBuddyWithIdentifier:identifier];
	
	// Mark the buddy as unblocked.
	TCBuddy *buddy = [self buddyWithIdentifier:identifier];
	
	if (buddy)
	{
		[buddy setBlocked:NO];
		[buddy start];
		
		dispatch_async(_localQueue, ^{
			[self _notify:TCCoreEventBuddyUnblocked context:buddy];
		});
	}
}

- (void)_checkBlocked:(TCBuddy *)buddy
{
	// > localQueue <
	
	if (!_config)
		return;
	
	NSArray	*blocked = [_config blockedBuddies];
	size_t	i, cnt = [blocked count];
	
	[buddy setBlocked:NO];
	
	// Search
	for (i = 0; i < cnt; i++)
	{
		NSString *identifier = blocked[i];
		
		if ([identifier isEqualToString:[buddy identifier]])
		{
			[buddy setBlocked:YES];
			[buddy stopWithCompletionHandler:nil];
			break;
		}
	}
}



/*
** TCCoreManager - Observers
*/
#pragma mark - TCCoreManager - Observers

- (void)addObserver:(id <TCCoreManagerObserver>)observer
{
	NSAssert(observer, @"observer is nil");
	
	dispatch_async(_localQueue, ^{
		[_observers addObject:observer];
	});
}

- (void)removeObserver:(id <TCCoreManagerObserver>)observer
{
	dispatch_async(_localQueue, ^{
		[_observers removeObject:observer];
	});
}



/*
** TCCoreManager - TCConnectionDelegate
*/
#pragma mark - TCCoreManager - TCConnectionDelegate

- (void)connection:(TCConnection *)connection receivedPingWithBuddyIdentifier:(NSString *)identifier randomToken:(NSString *)random
{
	TCBuddy *abuddy = [self buddyWithIdentifier:identifier];
	
	if ([abuddy blocked])
	{
		[self removeConnection:connection];
		return;
	}
	
	// Check for faked pings: we search all our already
	// *connected* buddies and if there is one with the same identifier
	// but another incoming connection then this one must be a fake.

	if ([abuddy isPonged])
	{
		[self _error:TCCoreErrorClientAlreadyPinged fatal:NO];
		[self removeConnection:connection];
		return;
	}
	
	// if someone is pinging us with our own identifier and the
	// random value is not from us, then someone is definitely
	// trying to fake and we can close.
	if ([identifier isEqualToString:_selfIdentifier] && abuddy && [[abuddy random] isEqualToString:random] == NO)
	{
		[self _error:TCCoreErrorClientMasquerade fatal:NO];
		[self removeConnection:connection];
		return;
	}
	
	// if the buddy don't exist, add it on the buddy list
	if (!abuddy)
	{
		[self addBuddyWithIdentifier:identifier name:nil];
		
		abuddy = [self buddyWithIdentifier:identifier];
		
		if (!abuddy)
		{
			[self _error:TCCoreErrorClientAddBuddy fatal:NO];
			[self removeConnection:connection];
			return;
		}
	}
		
	// ping messages must be answered with pong messages
	// the pong must contain the same random string as the ping.
	[abuddy handlePingWithRandomToken:random];
}

- (void)connection:(TCConnection *)connection receivedPongOnSocket:(SMSocket *)sock randomToken:(NSString *)random
{
	TCBuddy *buddy = [self buddyWithRandom:random];
	
	if (buddy)
	{
		// Check blocked list
		if ([buddy blocked])
		{
			// Stop buddy
			[buddy stopWithCompletionHandler:nil];
			
			// Stop socket
			[sock stop];
		}
		else
		{
			// Give the baby to buddy
			[buddy handlePongWithSocket:sock];
		}
	}
	else
		[self _error:TCCoreErrorClientCmdPong fatal:NO];
	
	// We don't need the connection at this time: simply remove it.
	[self removeConnection:connection];
}

- (void)connection:(TCConnection *)connection information:(SMInfo *)info
{	
	// Forward the information.
	dispatch_async(_localQueue, ^{
		[self _sendEvent:info];
	});
	
	// If it's an error: kill the connection.
	if (info.kind == SMInfoError)
		[self removeConnection:connection];
}



/*
** TCCoreManager - Connections
*/
#pragma mark - TCCoreManager - Connections

- (void)_addConnectionSocket:(int)csock
{
	// > socketQueue <
	
	TCConnection *client = [[TCConnection alloc] initWithDelegate:self andSocket:csock];
	
	[_connections addObject:client];
	
	[client start];
}

- (void)removeConnection:(TCConnection *)connection
{
	dispatch_async(_socketQueue, ^{
		[connection stopWithCompletionHandler:nil];
		[_connections removeObject:connection];
	});
}




/*
** TCCoreManager - Helpers
*/
#pragma mark - TCCoreManager - Helpers

- (void)_error:(TCCoreError)code fatal:(BOOL)fatal
{
	// > localQueue <
	
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCCoreManagerInfoDomain code:code];

	[self _sendEvent:err];
		
	if (fatal)
		[self _stopWithCompletionHandler:nil];
}

- (void)_error:(TCCoreError)code context:(id)ctx fatal:(BOOL)fatal
{
	// > localQueue <
		
	SMInfo *err = [SMInfo infoOfKind:SMInfoError domain:TCCoreManagerInfoDomain code:code context:ctx];
	
	[self _sendEvent:err];
	
	if (fatal)
		[self _stopWithCompletionHandler:nil];
}

- (void)_notify:(TCCoreEvent)notice
{
	// > localQueue <
		
	SMInfo *ifo = [SMInfo infoOfKind:SMInfoInfo domain:TCCoreManagerInfoDomain code:notice];

	[self _sendEvent:ifo];
}

- (void)_notify:(TCCoreEvent)notice context:(id)ctx
{
	// > localQueue <
	
	SMInfo *ifo = [SMInfo infoOfKind:SMInfoInfo domain:TCCoreManagerInfoDomain code:notice context:ctx];

	[self _sendEvent:ifo];
}

- (void)_sendEvent:(SMInfo *)info
{
	// > localQueue <
	
	NSAssert(info, @"info is nil");
	
	for (id <TCCoreManagerObserver> observer in _observers)
	{
		dispatch_async(_externalQueue, ^{
			[observer torchatManager:self information:info];
		});
	}
}



/*
** TCCoreManager - Infos
*/
#pragma mark - TCCoreManager - Infos

+ (void)registerInfoDescriptors
{
	NSMutableDictionary *descriptors = [[NSMutableDictionary alloc] init];
	
	// == TCCoreManagerInfoDomain ==
	descriptors[TCCoreManagerInfoDomain] = ^  NSDictionary * (SMInfoKind kind, int code) {
		
		switch (kind) {
			case SMInfoInfo:
			{
				switch ((TCCoreEvent)code)
				{
					case TCCoreEventStarted:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventStarted",
							SMInfoTextKey : @"core_mng_event_started",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreEventStopped:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventStopped",
							SMInfoTextKey : @"core_mng_event_stopped",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreEventStatus:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventStatus",
							SMInfoDynTextKey : ^ NSString *(NSNumber *context) {
								
								NSString *status = @"-";
								
								switch ([context intValue])
								{
									case TCStatusOffline:	status = NSLocalizedString(@"bd_status_offline", @""); break;
									case TCStatusAvailable: status = NSLocalizedString(@"bd_status_available", @""); break;
									case TCStatusAway:		status = NSLocalizedString(@"bd_status_away", @""); break;
									case TCStatusXA:		status = NSLocalizedString(@"bd_status_xa", @""); break;
								}
								
								return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_status", @""), status];
							},
							SMInfoLocalizableKey : @NO,
						};
					}
						
					case TCCoreEventProfileAvatar:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventProfileAvatar",
							SMInfoTextKey : @"core_mng_event_profile_avatar",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreEventProfileName:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventProfileName",
							SMInfoTextKey : @"core_mng_event_profile_name",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreEventProfileText:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventProfileText",
							SMInfoTextKey : @"core_mng_event_profile_text",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreEventBuddyNew:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventBuddyNew",
							SMInfoDynTextKey : ^ NSString *(TCBuddy *context) {
								return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_new_buddy", @""), context.identifier];
							},
							SMInfoLocalizableKey : @NO,
						};
					}
						
					case TCCoreEventBuddyRemove:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventBuddyRemove",
							SMInfoDynTextKey : ^ NSString *(TCBuddy *context) {
								return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_remove_buddy", @""), context.identifier];
							},
							SMInfoLocalizableKey : @NO,
						};
					}
						
					case TCCoreEventBuddyBlocked:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventBuddyBlocked",
							SMInfoDynTextKey : ^ NSString *(TCBuddy *context) {
								return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_blocked_buddy", @""), context.identifier];
							},
							SMInfoLocalizableKey : @NO,
						};
					}
						
					case TCCoreEventBuddyUnblocked:
					{
						return @{
							SMInfoNameKey : @"TCCoreEventBuddyUnblocked",
							SMInfoDynTextKey : ^ NSString *(TCBuddy *context) {
								return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_unblock_buddy", @""), context.identifier];
							},
							SMInfoLocalizableKey : @NO,
						};
					}
						
					case TCCoreEventClientStarted:
						return nil; // can't happen in this domain.
						
					case TCCoreEventClientStopped:
						return nil; // can't happen in this domain.
				}
				
				break;
			}
				
			case SMInfoWarning:
			{
				break;
			}
				
			case SMInfoError:
			{
				switch ((TCCoreError)code)
				{
					case TCCoreErrorSocket:
						return nil; // can't happen in this domain.
						
					case TCCoreErrorSocketCreate:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorSocketCreate",
							SMInfoTextKey : @"core_mng_error_socket",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorSocketOption:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorSocketOption",
							SMInfoTextKey : @"core_mng_error_setsockopt",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorSocketBind:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorSocketBind",
							SMInfoTextKey : @"core_mng_error_bind",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorSocketListen:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorSocketListen",
							SMInfoTextKey : @"core_mng_error_listen",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorServAccept:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorServAccept",
							SMInfoTextKey : @"core_mng_error_accept",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorServAcceptAsync:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorServAcceptAsync",
							SMInfoTextKey : @"core_mng_error_async",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorClientAlreadyPinged:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientAlreadyPinged",
							SMInfoTextKey : @"core_cnx_error_already_pinged",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorClientMasquerade:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientMasquerade",
							SMInfoTextKey : @"core_cnx_error_masquerade",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorClientAddBuddy:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientAddBuddy",
							SMInfoTextKey : @"core_cnx_error_add_buddy",
							SMInfoLocalizableKey : @YES,
							};
					}
						
					case TCCoreErrorClientCmdUnknownCommand:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdUnknownCommand",
						};
					}
						
					case TCCoreErrorClientCmdPing:
						return nil; // can't happen in this domain.
						
					case TCCoreErrorClientCmdPong:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdPong",
							SMInfoTextKey : @"core_cnx_error_pong",
							SMInfoLocalizableKey : @YES,
						};
					}
						
					case TCCoreErrorClientCmdStatus:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdStatus",
						};
					}
						
					case TCCoreErrorClientCmdVersion:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdVersion",
						};
					}
						
					case TCCoreErrorClientCmdClient:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdClient",
						};
					}
						
					case TCCoreErrorClientCmdProfileText:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdProfileText",
						};
					}
						
					case TCCoreErrorClientCmdProfileName:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdProfileName",
						};
					}
						
					case TCCoreErrorClientCmdProfileAvatar:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdProfileAvatar",
						};
					}
						
					case TCCoreErrorClientCmdProfileAvatarAlpha:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdProfileAvatarAlpha",
						};
					}
						
					case TCCoreErrorClientCmdMessage:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdMessage",
						};
					}
						
					case TCCoreErrorClientCmdAddMe:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdAddMe",
						};
					}
						
					case TCCoreErrorClientCmdRemoveMe:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdRemoveMe",
						};
					}
						
					case TCCoreErrorClientCmdFileName:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdFileName",
						};
					}
						
					case TCCoreErrorClientCmdFileData:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdFileData",
						};
					}
						
					case TCCoreErrorClientCmdFileDataOk:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdFileDataOk",
						};
					}
						
					case TCCoreErrorClientCmdFileDataError:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdFileDataError",
						};
					}
						
					case TCCoreErrorClientCmdFileStopSending:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdFileStopSending",
						};
					}
						
					case TCCoreErrorClientCmdFileStopReceiving:
					{
						return @{
							SMInfoNameKey : @"TCCoreErrorClientCmdFileStopReceiving",
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


NS_ASSUME_NONNULL_END
