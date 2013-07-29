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



#include <stdio.h>
#include <errno.h>

#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>

#include <string>
#include <map>

#include <Block.h>

#include "TCController.h"

#include "TCConfig.h"
#include "TCBuddy.h"
#include "TCTools.h"
#include "TCImage.h"
#include "TCNumber.h"
#include "TCString.h"

#include "TCControlClient.h"




/*
** TCController - Instance
*/
#pragma mark - TCController - Instance

TCController::TCController(id <TCConfig> _config) :
	running(false)
{
	config = _config;
	
	// Init vars
	mstatus = tccontroller_available;
	running = false;
	socketAccept = 0;
	
	nQueue = 0;
	nBlock = NULL;
	
	buddiesLoaded = false;
	
	timer = 0;
	
	// Get profile avatar
	pavatar = [config profileAvatar];
	
	if (!pavatar)
		pavatar = [[TCImage alloc] initWithWidth:64 andHeight:64];
	
	// Get profile name & text
	pname = new TCString([[config profileName] UTF8String]);
	ptext = new TCString([[config profileText] UTF8String]);
	
	// Alloc queue
	mainQueue = dispatch_queue_create("com.torchat.core.controller.main", DISPATCH_QUEUE_SERIAL);
	socketQueue = dispatch_queue_create("com.torchat.core.controller.socket", DISPATCH_QUEUE_SERIAL);
}

TCController::~TCController()
{
	TCDebugLog("TCController Destructor");

	// Close client
	size_t i, cnt = clients.size();
		
	for (i = 0; i < cnt; i++)
	{
		clients[i]->stop();
		clients[i]->release();
	}
		
	clients.clear();
	
	
	// Stop buddies
	cnt = buddies.size();
		
	for (i = 0; i < cnt; i++)
	{
		buddies[i]->stop();
		buddies[i]->release();
	}
	buddies.clear();
		
	// Release delegate
	nBlock = nil;
	nQueue = nil;
	
	// Release config
	config = nil;
}



/*
** TCController - Running
*/
#pragma mark - TCController - Running

void TCController::start()
{
	dispatch_async_cpp(this, mainQueue, ^{
		
		if (running)
			return;
		
		if (!buddiesLoaded)
		{
			NSArray *sbuddies = [config buddies];
			size_t	i, cnt;
			
			//  -- Parse buddies --
			cnt = [sbuddies count];
			
			for (i = 0; i < cnt; i++)
			{
				NSDictionary	*item = sbuddies[i];
				TCBuddy			*buddy = new TCBuddy(config, [item[TCConfigBuddyAlias] UTF8String], [item[TCConfigBuddyAddress] UTF8String], [item[TCConfigBuddyNotes] UTF8String]);
				
				// Check blocked status
				_checkBlocked(buddy);
				
				// Add to list
				buddies.push_back(buddy);
				
				// Notify
				_notify(tcctrl_notify_buddy_new, "core_ctrl_note_new_buddy", buddy);
			}
			
			// -- Check that we are on the buddy list --
			bool				found = false;
			const std::string	self_address = [[config selfAddress] UTF8String];
			
			cnt = buddies.size();
			
			for (i = 0; i < cnt; i++)
			{
				TCBuddy	*buddy = buddies[i];
				
				if (buddy->address().content().compare(self_address) == 0)
				{
					found = true;
					break;
				}
			}
			
			if (!found)
				addBuddy([[config localized:@"core_ctrl_myself"] UTF8String], self_address);
			
			// -- Buddy are loaded --
			buddiesLoaded = true;
		}
		
		// -- Start command server -- 
		struct sockaddr_in	my_addr;
		int					yes = 1;
				
		// > Configure the port and address
		my_addr.sin_family = AF_INET;
		my_addr.sin_port = htons([config clientPort]);
		my_addr.sin_addr.s_addr = INADDR_ANY;
		memset(&(my_addr.sin_zero), '\0', 8);
				
		// > Instanciate the listening socket
		if ((sock = socket(AF_INET, SOCK_STREAM, 0)) == -1)
		{
			_error(tcctrl_error_serv_socket, "core_ctrl_err_socket", true);
			return;
		}
		
		// > Reuse the port
		if (setsockopt(sock, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(int)) == -1)
		{
			_error(tcctrl_error_serv_socket, "core_ctrl_err_setsockopt", true);
			return;
		}
		
		// > Bind the socket to the configuration perviously set
		if (bind(sock, (struct sockaddr *)&my_addr, sizeof(struct sockaddr)) == -1)
		{
			_error(tcctrl_error_serv_socket, "core_ctrl_err_bind", true);
			return;	
		}
		
		// > Set the socket as a listening socket
		if (listen(sock, 10) == -1)
		{
			_error(tcctrl_error_serv_socket, "core_ctrl_err_listen", true);
			return;	
		}
		
		// > Build a source
		socketAccept = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)sock, 0, socketQueue);
		
		// > Set the read handler
		dispatch_source_set_event_handler_cpp(this, socketAccept, ^{
			
			unsigned int		sin_size = sizeof(struct sockaddr);
			struct sockaddr_in	their_addr;
			int					csock;
			
			csock = accept(sock, (struct sockaddr *)&their_addr, &sin_size);
			
			if (csock == -1)
			{
				dispatch_async_cpp(this, mainQueue, ^{
					_error(tcctrl_error_serv_accept, "core_ctrl_err_accept", true);
				});
			}
			else
			{
				// Make the client async
				if (!doAsyncSocket(csock))
				{
					dispatch_async_cpp(this, mainQueue, ^{
						_error(tcctrl_error_serv_accept, "core_ctrl_err_async", true);
					});
					
					return;
				}

				// Add it later
				dispatch_async_cpp(this, socketQueue, ^{
					_addClient(csock);
				});
			}
		});
		
		// > Set the cancel handler
		dispatch_source_set_cancel_handler_cpp(this, socketAccept, ^{
			close(sock);
			sock = -1;
		});

		dispatch_resume(socketAccept);
		
		
		// -- Build a timer to keep alive buddies (start or sendStatus) --
		timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mainQueue);
		
		// Each 120s
		dispatch_source_set_timer(timer, DISPATCH_TIME_NOW, 120000000000L, 0);
		dispatch_source_set_event_handler_cpp(this, timer, ^{
			
			// Do nothing if not running
			if (!running || !buddiesLoaded)
				return;
			
			// (Re)start buddy (start do nothing if already started)
			size_t i, cnt = cnt = buddies.size();
			
			for (i = 0; i < cnt; i++)
				buddies[i]->keepAlive();
			
		});
		dispatch_resume(timer);
		
		// -- Start buddies --
		size_t i, cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = buddies[i];
			
			buddy->start();
		}
		
		// Give the status
		setStatus(mstatus);
		
		// Notify
		_notify(tcctrl_notify_started, "core_ctrl_note_started");
		
		// We are running !
		running = true;
	});
}

void TCController::stop()
{
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Check if we are running
		if (!running)
			return;
		
		// Cancel the socket
		dispatch_source_cancel(socketAccept);
		
		// Cancel the timer
		if (timer)
			dispatch_source_cancel(timer);
		
		socketAccept = nil;
		
		// Stop & release clients
		size_t i, cnt = clients.size();
		
		for (i = 0; i < cnt; i++)
		{
			clients[i]->stop();
			clients[i]->release();
		}
		clients.clear();
		
		// Stop buddies
		cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
			buddies[i]->stop();
				
		// Notify
		_notify(tcctrl_notify_stoped, "core_ctrl_note_stoped");
		
		running = false;
	});
}



/*
** TCController - Delegate
*/
#pragma mark - TCController - Delegate

void TCController::setDelegate(dispatch_queue_t queue, tcctrl_event event)
{
	// Asign on a block
	dispatch_async_cpp(this, mainQueue, ^{
		nQueue = queue;
		nBlock = event;
	});
}



/*
** TCController - Status
*/
#pragma mark - TCController - Status

void TCController::setStatus(tccontroller_status status)
{
	// Give the status
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Notify
		if (status != mstatus)
		{
			TCNumber *nstatus = new TCNumber((uint8_t)status);
			
			_notify(tcctrl_notify_status, "", nstatus);
			
			nstatus->release();
		}
		
		// Hold internal status
		mstatus = status;
		
		// Run the controller if needed, else send status
		if (!running)
			start();
		else
		{
			// Give this status to buddy list
			size_t i, cnt = cnt = buddies.size();
			
			for (i = 0; i < cnt; i++)
			{
				TCBuddy	*buddy = buddies[i];
				
				buddy->sendStatus(status);
			}
		}
	});
}

tccontroller_status	TCController::status()
{
	__block tccontroller_status result = tccontroller_available;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		result = mstatus;
	});
	
	return result;
}

void TCController::setProfileAvatar(TCImage *image)
{
	if (!image)
		return;
	
	// Set the avatar
	dispatch_async_cpp(this, mainQueue, ^{
		
		pavatar = image;
		
		// Store avatar
		[config setProfileAvatar:pavatar];
		
		// Give this avatar to buddy list
		size_t i, cnt = cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = buddies[i];
			
			buddy->sendAvatar(pavatar);
		}
		
		// Notify
		_notify(tcctrl_notify_profile_avatar, "core_ctrl_note_profile_avatar", (__bridge TCObject *)pavatar);
	});
}

TCImage * TCController::profileAvatar()
{
	__block TCImage *result = NULL;
	
	dispatch_sync_cpp(this, mainQueue, ^{

		if (pavatar)
			result = [pavatar copy];
	});
	
	return result;
}

void TCController::setProfileName(TCString *name)
{
	if (!name)
		return;
	
	name->retain();
	
	// Set the avatar
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Hold the name
		pname->release();
		pname = name;
		
		// Store the name
		[config setProfileName:@(name->content().c_str())];
		
		// Give this name to buddy list
		size_t i, cnt = cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = buddies[i];
			
			buddy->sendProfileName(pname);
		}
		
		// Notify
		_notify(tcctrl_notify_profile_name, "core_ctrl_note_profile_name", pname);
	});
}

TCString * TCController::profileName()
{
	__block TCString *result = NULL;
	
	dispatch_sync_cpp(this, mainQueue, ^{

		pname->retain();
		
		result = pname;
	});

	return result;
}

void TCController::setProfileText(TCString *text)
{
	if (!text)
		return;
	
	text->retain();
	
	// Set the avatar
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Hold the text
		ptext->release();
		ptext = text;
		
		// Store the text
		[config setProfileText:@(text->content().c_str())];
		
		// Give this text to buddy list
		size_t i, cnt = cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = buddies[i];
			
			buddy->sendProfileText(ptext);
		}
		
		// Notify
		_notify(tcctrl_notify_profile_text, "core_ctrl_note_profile_name", ptext);
	});
}

TCString * TCController::profileText()
{
	__block TCString *result = NULL;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		
		ptext->retain();
		
		result = ptext;
	});
	
	return result;
}



/*
** TCController - Buddies
*/
#pragma mark - TCController - Buddies

void TCController::addBuddy(const std::string &name, const std::string &address)
{
	addBuddy(name, address, "");
}

void TCController::addBuddy(const std::string &name, const std::string &address, const std::string &comment)
{
	TCBuddy		*buddy = new TCBuddy(config, name, address, comment);
	std::string	*cname = new std::string(name.c_str());
	std::string	*caddress = new std::string(address.c_str());
	std::string	*ccomment = new std::string(comment.c_str());
	
    dispatch_async_cpp(this, mainQueue, ^{
        
		// Check blocked status
		_checkBlocked(buddy);
		
        // Add to the buddy list
        buddies.push_back(buddy);
				
		// Notify
		_notify(tcctrl_notify_buddy_new, "core_ctrl_note_new_buddy", buddy);
		
        // Start it
        buddy->start();
		
		// Save to config
		[config addBuddy:@(caddress->c_str()) alias:@(cname->c_str()) notes:@(ccomment->c_str())];
		
		// Clean
		delete cname;
		delete caddress;
		delete ccomment;
    });
}

void TCController::removeBuddy(const std::string &address)
{
	std::string *cpy = new std::string(address);
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		size_t	i, cnt = buddies.size();
		
		// Search the buddy
		for (i = 0; i < cnt; i++)
		{
			if (buddies[i]->address().content().compare(*cpy) == 0)
			{
				// Stop and release
				TCBuddy	*buddy = buddies[i];
				
				buddy->stop();
				buddy->release();
				
				buddies.erase(buddies.begin() + (ptrdiff_t)i);
				
				// Save to config
				[config removeBuddy:@(cpy->c_str())];
				
				break;
			}
		}
				
		delete cpy;
	});
}

TCBuddy * TCController::getBuddyAddress(const std::string &address)
{    
	std::string		*addr = new std::string(address);
    __block TCBuddy *result = NULL;
	
	dispatch_sync_cpp(this, mainQueue, ^{
        
        size_t i, cnt = cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = buddies[i];
            
            if (buddy->address().content().compare(*addr) == 0)
            {
                result = buddy;
				result->retain();
				
                break;
            }
        }
		
		delete addr;
    });
	
    return result;
}

TCBuddy * TCController::getBuddyRandom(const std::string &random)
{
	std::string		*ran = new std::string(random);
    __block TCBuddy *result = NULL;
	
	dispatch_sync_cpp(this, mainQueue, ^{
        
        size_t i, cnt = cnt = buddies.size();
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy	*buddy = buddies[i];
            
            if (buddy->brandom().content().compare(*ran) == 0)
            {
                result = buddy;
				result->retain();
				
                break;
            }
        }
		
		delete ran;
    });
    
    return result;
}



/*
** TCController - Blocked Buddies 
*/
#pragma mark - TCController - Blocked Buddies

bool TCController::addBlockedBuddy(const std::string &address)
{
	__block bool	result = false;
	std::string		*addr = new std::string(address);

	dispatch_sync_cpp(this, mainQueue, ^{
		
		// Add the address to the configuration
		if ([config addBlockedBuddy:@(addr->c_str())] == YES)
			result = true;
		
		// Clean
		delete addr;
	});
	
	// Mark the buddy as blocked
	if (result)
	{
		TCBuddy * buddy = getBuddyAddress(address);
		
		if (buddy)
		{
			buddy->setBlocked(true);
			buddy->release();
		}
	}
		
	return result;
}

bool TCController::removeBlockedBuddy(const std::string &address)
{
	__block bool	result = false;
	std::string		*addr = new std::string(address);

	dispatch_sync_cpp(this, mainQueue, ^{
		
		// Remove the address from the configuration
		if ([config removeBlockedBuddy:@(addr->c_str())] == YES)
			result = true;
		
		// Clean
		delete addr;
	});
	
	// Mark the buddy as un-blocked
	if (result)
	{
		TCBuddy * buddy = getBuddyAddress(address);
		
		if (buddy)
		{
			buddy->setBlocked(false);
			buddy->release();
		}
	}
	
	return result;
}



/*
** TCController - TCControlClient
*/
#pragma mark - TCController - TCControlClient

void TCController::cc_error(TCControlClient *client, TCInfo *serr)
{
	if (!client || !serr)
		return;
	
	// Give the error
	serr->retain();
	
	dispatch_async_cpp(this, mainQueue, ^{
		_send_event(serr);
		
		serr->release();
	});
	
	
	// Remove the client
	client->retain();

	dispatch_async_cpp(this, socketQueue, ^{
		
		std::vector<TCControlClient *>::iterator it;
		
		for (it = clients.begin(); it != clients.end(); it++)
		{
			TCControlClient *item = *it;
			
			if (item == client)
			{
				clients.erase(it);
				
				item->stop();
				item->release();
				
				break;
			}
		}
		
		// Realease it
		client->release();
	});
}

void TCController::cc_notify(TCControlClient *client, TCInfo *info)
{	
	if (!client || !info)
		return;
	
	info->retain();
	
	dispatch_async_cpp(this, mainQueue, ^{
		_send_event(info);
		
		info->release();
	});
}



/*
** TCController - Tools
*/
#pragma mark - TCController - Tools

void TCController::_addClient(int csock)
{
	// > socketQueue <
	
	TCControlClient *client = new TCControlClient(config, csock);
	
	clients.push_back(client);
	
	client->start(this);
}

void TCController::_checkBlocked(TCBuddy *buddy)
{
	// > mainQueue <
	
	if (!config)
		return;
	
	// XXX not thread safe
	NSArray	*blocked = [config blockedBuddies];
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




/*
** TCController - Helpers
*/
#pragma mark - TCController - Helpers

void TCController::_error(tcctrl_info code, const std::string &info, bool fatal)
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, [[config localized:@(info.c_str())] UTF8String]);
	
	_send_event(err);
	
	err->release();
	
	if (fatal)
		stop();
}

void TCController::_error(tcctrl_info code, const std::string &info, TCObject *ctx, bool fatal)
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, [[config localized:@(info.c_str())] UTF8String], ctx);
	
	_send_event(err);
	
	err->release();
	
	if (fatal)
		stop();
}

void TCController::_notify(tcctrl_info notice, const std::string &info)
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice, [[config localized:@(info.c_str())] UTF8String]);
	
	_send_event(ifo);
	
	ifo->release();
}

void TCController::_notify(tcctrl_info notice, const std::string &info, TCObject *ctx)
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice, [[config localized:@(info.c_str())] UTF8String], ctx);
	
	_send_event(ifo);
	
	ifo->release();
}

void TCController::_send_event(TCInfo *info)
{
	// > mainQueue <
	
	if (!info)
		return;
	
	if (nQueue && nBlock)
	{
		info->retain();
		
		dispatch_async_cpp(this, nQueue, ^{
			
			nBlock(this, info);
			
			info->release();
		});
	}
}
