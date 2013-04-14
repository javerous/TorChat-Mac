/*
 *  TCBuddy.cpp
 *
 *  Copyright 2010 Avérous Julien-Pierre
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

#include <netdb.h>
#include <pwd.h>
#include <errno.h>
#include <sys/stat.h>

#include <Block.h>

#include <arpa/inet.h>
#include <sys/types.h>
#include <sys/socket.h>

#include "TCBuddy.h"

#include "TCConfig.h"
#include "TCTools.h"

#include "TCFileSend.h"
#include "TCFileReceive.h"



/*
** Defines
*/
#pragma mark -
#pragma mark Defines

#define TORCHAT_PORT	11009 // Should be in config file ?



/*
** Types
*/
#pragma mark -
#pragma mark Types

// == Structure representing a Socks connection request ==
struct sockreq
{
	int8_t	version;
	int8_t	command;
	int16_t	dstport;
	int32_t	dstip;
	// A null terminated username goes here
};

// == Structure representing a Socks connection request response ==
struct sockrep
{
	int8_t	version;
	int8_t	result;
	int16_t	ignore1;
	int32_t	ignore2;
};

// == Socks State ==
typedef enum
{
	socks_nostate,
	socks_running,
	socks_finish,
} socks_state;	

// == Socks trame type ==
typedef enum
{
	socks_v4_reply,
} socks_trame;



/*
** TCBuddy - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCBuddy - Constructor & Destructor

TCBuddy::TCBuddy(TCConfig *_config, const std::string &_name, const std::string &_address, const std::string &_comment) :
	config(_config),
	mname(_name),
	maddress(_address),
	mcomment(_comment)
{
    TCDebugLog("Buddy (%s) - New", maddress.c_str());
	
	// Retain config
	_config->retain();
	
	// Build queue
	mainQueue = dispatch_queue_create("com.torchat.core.buddy.main", NULL);

	// Init notice queue & block
	nQueue = 0;
	nBlock = 0;
	
	// Init status
	//writeActive = false;
	running = false;
	ponged = false;
	pongSent = false;
	useExtend = false;
	
	outSocket = NULL;
	inSocket = NULL;
	
	socksstate = socks_nostate;
	mstatus = tcbuddy_status_offline;
	
	// Generate random
	char	rnd[101];
	char	charset [] = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
	size_t	i;
	int		index;
	
	srandomdev();
	
	for (i = 0; i < sizeof(rnd) - 1; i++)
	{
		index = random() % (sizeof(charset) - 1);
		rnd[i] = charset[index];
	}
	
	rnd[100] = '\0';
	
	mrandom = rnd;
}

TCBuddy::~TCBuddy()
{
	TCDebugLog("TCBuddy Destructor");
	
	// Clean out connections
	if (outSocket)
	{
		outSocket->stop();
		outSocket->release();
		outSocket = NULL;
	}
	
	// Clean in connexions
	if (inSocket)
	{
		inSocket->stop();
		inSocket->release();
		inSocket = NULL;
	}
	
	// Clean config
	config->release();
	
	// Clean main queue
	dispatch_release(mainQueue);
}



/*
** TCBuddy - Running
*/
#pragma mark -
#pragma mark TCBuddy - Running

void TCBuddy::start()
{
	dispatch_async_cpp(this, mainQueue, ^{
		
		if (running)
			return;
		
		TCDebugLog( "Buddy (%s) - Start", maddress.c_str());
		
		// -- Make a connection to Tor proxy --
		struct addrinfo	hints, *res, *res0;
		int				error;
		int				s;
		char			sport[50];
		
		memset(&hints, 0, sizeof(hints));
		
		snprintf(sport, sizeof(sport), "%i", config->get_tor_port());
		
		// Configure the resolver
		hints.ai_family = PF_UNSPEC;
		hints.ai_socktype = SOCK_STREAM;

		// Try to resolve and connect to the given address
		error = getaddrinfo(config->get_tor_address().c_str(), sport, &hints, &res0);
		if (error)
		{
			_error(tcbuddy_error_resolve_tor, "core_bd_err_tor_resolve", true);
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
			_error(tcbuddy_error_connect_tor, "core_bd_err_tor_connect", true);
			return;
		}
		
		// Build a socket with this descriptor
		outSocket = new TCSocket(s);
		
		// Set ourself as delegate
		outSocket->setDelegate(mainQueue, this);
		
		// Start SOCKS protocol
		_startSocks();

		// Set as running
		running = true;
		
		// Say that we are connected
		_notify(tcbuddy_notify_connected_tor, "core_bd_note_tor_connected");
	});
}

void TCBuddy::stop()
{
	dispatch_async_cpp(this, mainQueue, ^{

		if (running)
		{
			tcbuddy_status lstatus;
			
			// Realease out socket
			if (outSocket)
			{
				outSocket->stop();
				outSocket->release();
				
				outSocket = NULL;
			}
			
			// Realease in socket
			if (inSocket)
			{
				inSocket->stop();
				inSocket->release();
				
				inSocket = NULL;
			}
			
			// Clean receive session
			frec_iterator fr;
			
			for (fr = freceive.begin(); fr != freceive.end(); fr++)
				fr->second->release();
			
			freceive.clear();
			
			
			// Clean send session
			fsend_iterator fs;
			
			for (fs = fsend.begin(); fs != fsend.end(); fs++)
				fs->second->release();
			
			fsend.clear();
			
			// Reset status
			lstatus = mstatus;
			mstatus = tcbuddy_status_offline;
			
			socksstate = socks_nostate;
			ponged = false;
			pongSent = false;
			useExtend = false;
			running = false;
			
			// Notify
			if (lstatus != tcbuddy_status_offline)
				_notify(tcbuddy_notify_status, "core_bd_note_status_changed"); // Offline
			
			_notify(tcbuddy_notify_disconnected, "core_bd_note_stoped");
		}
	});
}

bool TCBuddy::isRunning()
{
	__block bool result = false;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		result = running;
	});
	
	return result;
}

bool TCBuddy::isPonged()
{
	__block bool result = false;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		result = ponged;
	});
	
	return result;
}



/*
** TCBuddy - Delegate
*/
#pragma mark -
#pragma mark TCBuddy - Delegate

void TCBuddy::setDelegate(dispatch_queue_t queue, tcbuddy_event event)
{
	tcbuddy_event cpy = NULL;
	
	if (event)
		cpy = Block_copy(event);
	
	if (queue)
		dispatch_retain(queue);

	// Asign on a block
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Queue
		if (nQueue)
			dispatch_release(nQueue);
		
		nQueue = queue;
		
		
		// Block
		if (nBlock)
			Block_release(nBlock);
		nBlock = cpy;
	});
}



/*
** TCBuddy - Accessors
*/
#pragma mark -
#pragma mark TCBuddy - Accessor

const std::string TCBuddy::name()
{
	__block std::string result;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		result = mname;
	});
	
	return result;
}

void TCBuddy::setName(const std::string &name)
{
	std::string *cpy = new std::string(name);
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Set the new name in config
		config->set_buddy_name(maddress, *cpy);
		
		// Change the name internaly
		mname = *cpy;
		
		// Notidy of the change
		_notify(tcbuddy_notify_info, "core_bd_note_name_changed");
		
		// Clean
		delete cpy;
	});
}

const std::string TCBuddy::comment()
{
	__block std::string result;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		result = mcomment;
	});
	
	return result;
}

void TCBuddy::setComment(const std::string &comment)
{
	std::string *cpy = new std::string(comment);
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Set the new name in config
		config->set_buddy_comment(maddress, *cpy);
		
		// Change the name internaly
		mcomment = *cpy;
		
		// Notify of the change
		_notify(tcbuddy_notify_info, "core_bd_note_comment_changed");
		
		// Clean
		delete cpy;
	});
}

tcbuddy_status TCBuddy::status()
{
	__block tcbuddy_status res = tcbuddy_status_offline;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		
		if (pongSent && ponged)
			res = mstatus;
		else
			res = tcbuddy_status_offline;
	});
					  
	return res;
}




/*
** TCBuddy - Files Info
*/
#pragma mark -
#pragma mark TCBuddy - Files Info

std::string TCBuddy::fileFileName(const std::string &uuid, tcbuddy_file_way way)
{
	std::string			*c_uuid = new std::string(uuid);
	__block std::string res;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		
		if (way == tcbuddy_file_send)
		{
			fsend_const_iterator its = fsend.find(*c_uuid);
			
			if (its != fsend.end())
				res = its->second->fileName();
		}
		else if (way == tcbuddy_file_receive)
		{
			frec_const_iterator itr = freceive.find(*c_uuid);
			
			if (itr != freceive.end())
				res = itr->second->fileName();
		}
		
		delete c_uuid;
	});
	
	return res;
}

std::string TCBuddy::fileFilePath(const std::string &uuid, tcbuddy_file_way way)
{
	std::string			*c_uuid = new std::string(uuid);
	
	__block std::string res;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		
		if (way == tcbuddy_file_send)
		{
			// Search the file send
			fsend_const_iterator its = fsend.find(*c_uuid);
			
			if (its != fsend.end())
				res = its->second->filePath();
		}
		else if (way == tcbuddy_file_receive)
		{
			// Search the file receive
			frec_const_iterator itr = freceive.find(*c_uuid);
			
			if (itr != freceive.end())
				res = itr->second->filePath();
		}
		
		delete c_uuid;
	});
	
	return res;
}

bool TCBuddy::fileStat(const std::string &uuid, tcbuddy_file_way way, uint64_t &done, uint64_t &total)
{
	std::string		*c_uuid = new std::string(uuid);
	
	__block bool		result = false;
	__block uint64_t	rdone = 0;
	__block uint64_t	rtotal = 0;
	
	
	dispatch_sync_cpp(this, mainQueue, ^{
		
		if (way == tcbuddy_file_send)
		{
			// Search the file send
			fsend_const_iterator its = fsend.find(*c_uuid);
			
			if (its != fsend.end())
			{
				TCFileSend *file = its->second;
				
				rdone = file->validatedSize();
				rtotal = file->fileSize();
				
				result = true;
			}
		}
		else if (way == tcbuddy_file_receive)
		{
			// Search the file receive
			frec_const_iterator itr = freceive.find(*c_uuid);
			
			if (itr != freceive.end())
			{
				TCFileReceive *file = itr->second;
				
				rdone = file->receivedSize();
				rtotal = file->fileSize();
				
				result = true;
			}
		}
		
		delete c_uuid;
	});
	
	// Give values
	done = rdone;
	total = rtotal;
	
	// Return result
	return result;
}

void TCBuddy::fileCancel(const std::string &uuid, tcbuddy_file_way way)
{
	std::string *c_uuid = new std::string(uuid);
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		if (way == tcbuddy_file_send)
		{
			// Search the file send
			fsend_iterator its = fsend.find(*c_uuid);
			
			if (its != fsend.end())
			{
				TCFileSend	*file = its->second;
				
				// Say to the remote peer to stop receiving data
				_sendFileStopReceiving(*c_uuid);
				
				// Notify that we stop sending the file
				TCFileInfo *info = new TCFileInfo(file);
				
				_notify(tcbuddy_notify_file_send_stoped, "core_bd_note_file_send_canceled", info);

				info->release();
				
				// Release file
				file->release();
				fsend.erase(its);
			}
		}
		else if (way == tcbuddy_file_receive)
		{
			// Search the file receive
			frec_iterator itr = freceive.find(*c_uuid);
			
			if (itr != freceive.end())
			{
				TCFileReceive	*file = itr->second;
				
				// Say to the remote peer to stop sending data
				_sendFileStopSending(*c_uuid);
				
				// Notify that we stop sending the file
				TCFileInfo *info = new TCFileInfo(file);

				_notify(tcbuddy_notify_file_receive_stoped, "core_bd_note_file_receive_canceled", info);
				
				info->release();
				
				// Release file
				file->release();
				freceive.erase(itr);
			}
		}
		
		delete c_uuid;
	});
}



/*
** TCBuddy - Send Command
*/
#pragma mark -
#pragma mark TCBuddy - Send Command

void TCBuddy::sendStatus(tccontroller_status status)
{
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Send status only if we are ponged
		if (pongSent)		
			_sendStatus(status);
	});
}

void TCBuddy::sendMessage(const std::string &message)
{
	std::string *amsg = new std::string(message);
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Send Message only if we sent pong and we are ponged
		if (pongSent && ponged)
			_sendCommand("message", *amsg);
		else
		{
			_error(tcbuddy_error_message_offline, *amsg, false);
		}
		
		delete amsg;
	});
}

void TCBuddy::sendFile(const std::string &filepath)
{
	std::string *cpy = new std::string(filepath);
		
	dispatch_async_cpp(this, mainQueue, ^{

		// Send file only if we sent pong and we are ponged
		if (pongSent && ponged)
		{
			TCFileSend *file = NULL;

			// Try to open the file for send
			try
			{
				file = new TCFileSend(*cpy);
			}
			catch (std::string error)
			{
				if (file)
					file->release();
				delete cpy;
				
				_error(tcbuddy_error_send_file, error, false);
				return;
			}

			// Insert the new file session
			fsend[file->uuid()] = file;

			// Notify
			TCFileInfo *info = new TCFileInfo(file);
			
			_notify(tcbuddy_notify_file_send_start, "core_bd_note_file_send_start", info);
			
			info->release();

			// Start the file session
			_sendFileName(file);
						
			// Send the first block to start the send
			if (useExtend)
			{
				_sendFileDataB64(file);
			}
			else
			{
				// Because TorChat python have a race condition on a GUI callback, we wait 5 seconds before sending first block
				file->retain();
				
				dispatch_after_cpp(this, dispatch_time(DISPATCH_TIME_NOW, 5000000000L), mainQueue, ^{
					_sendFileData(file);
					
					file->release();
				});
			}
		}
		else
		{
			_error(tcbuddy_error_file_offline, "core_bd_err_file_offline", false);
		}
		
		delete cpy;
	});
}



/*
** TCBuddy - Action
*/
#pragma mark -
#pragma mark TCBuddy - Action

void TCBuddy::startHandshake(const std::string &rrandom, tccontroller_status status)
{
	std::string *cpy = new std::string(rrandom);
	
	dispatch_async_cpp(this, mainQueue, ^{
		_sendPong(*cpy);
		_sendStatus(status);
		_sendAddMe(); // This seem really useless
		_sendVersion();
		
		pongSent = true;
		
		delete cpy;
	});
}

void TCBuddy::setInputConnection(TCSocket *sock)
{
	if (!sock)
		return;
	
	sock->retain();
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		// Activate send message & send file commands
		ponged = true;
		
		// Use this incomming connection
		sock->setDelegate(mainQueue, this);
		
		if (inSocket)
		{
			inSocket->stop();
			inSocket->release();
		}
		
		inSocket = sock;
		
		inSocket->setGlobalOperation(tcsocket_op_line, 0, 0);
		
		// Notify that we are readdy
		if (ponged && pongSent)
			_notify(tcbuddy_notify_identified, "core_bd_note_identified");
	});
}



/*
** TCBuddy(TCSocket) - Delegate
*/
#pragma mark -
#pragma mark TCBuddy(TCSocket) - Delegate

void TCBuddy::socketOperationAvailable(TCSocket *socket, tcsocket_operation operation, int tag, void *content, size_t size)
{
	// > mainQueue <
	
	if (operation == tcsocket_op_data)
	{
		// Get the reply
		struct sockrep *thisrep = static_cast<struct sockrep *> (content);
		
		// Check result
		switch (thisrep->result)
		{
			case 90: // Socks v4 protocol finish
			{
				socksstate = socks_finish;
				
				outSocket->setGlobalOperation(tcsocket_op_line, 0, 0);
				
				// Notify
				_notify(tcbuddy_notify_connected_buddy, "core_bd_note_connected");
				
				// We are connected, do things
				_connectedSocks();
				
				break;
			}
				
			case 91:
				_error(tcbuddy_error_socks, "core_bd_err_socks_91", true);				
				break;
				
			case 92:
				_error(tcbuddy_error_socks, "core_bd_err_socks_92", true);
				break;
				
			case 93:
				_error(tcbuddy_error_socks, "core_bd_err_socks_93", true);
				break;
				
			default:
				_error(tcbuddy_error_socks, "core_bd_err_socks_unknown", true);
				break;
		}
		
		// Clean content
		free(content);
	}
	else if (operation == tcsocket_op_line)
	{
		std::vector <std::string *> *vect = static_cast< std::vector <std::string *> * > (content);
		size_t						i, cnt = vect->size();
		
		for (i = 0; i < cnt; i++)
		{
			std::string *line = vect->at(i);
			
			dispatch_async_cpp(this, mainQueue, ^{
				
				// Parse the line
				parseLine(*line);
				
				// Free memory
				delete line;
			});
		}
		
		// Clean
		delete vect;
	}
}

void TCBuddy::socketError(TCSocket *socket, TCInfo *err)
{
	// > mainQueue <
	
	// Localize the info
	err->setInfo(config->localized(err->info()));
	
	// Fallback error
	_error(tcbuddy_error_socket, "core_bd_err_socket", err, true);
}

void TCBuddy::socketRunPendingWrite(TCSocket *socket)
{
	// > mainQueue <
	
	_runPendingWrite();
}



/*
** TCBuddy(TCParser) - Overwrite
*/
#pragma mark -
#pragma mark TCBuddy(TCParser) - Overwrite

void TCBuddy::doStatus(const std::string &status)
{
	tcbuddy_status nstatus = tcbuddy_status_offline;
		
	if (status.compare("available") == 0)
		nstatus = tcbuddy_status_available;
	else if (status.compare("away") == 0)
		nstatus = tcbuddy_status_away;
	else if (status.compare("xa") == 0)
		nstatus = tcbuddy_status_xa;
	
	dispatch_async_cpp(this, mainQueue, ^{

		if (nstatus != mstatus)
		{
			mstatus = nstatus;
			
			// Notify that status changed
			_notify(tcbuddy_notify_status, "core_bd_note_status_changed");
		}
	});
}

void TCBuddy::doMessage(const std::string &message)
{
	std::string *amsg = new std::string(message);
	
	dispatch_async_cpp(this, mainQueue, ^{
		
		if (messages.size() < 500)
		{
			messages.push_back(amsg);
			
			// Notify it
			_notify(tcbuddy_notify_message, "core_bd_note_new_message");
		}
		else
			_error(tcbuddy_error_too_messages, "core_bd_err_too_messages", false);
	});
}

void TCBuddy::doVersion(const std::string &version)
{
	// The Python version send raw data on a text based protocol (bad choice, but, it does not matter...).
	// So python fail, depending of the data, when doeing some text based operation on this data
	// (like splitting, etc.), because of conversion in UTF8 or things like this.
	// So, this version add the possibility to send data base64 encoded to prevent this. To distinct TorChat
	// clients with this ability (currently, only this version...), a _ext" is added on the version string.
	// This can give an information to the remote side about ourself, but I think that this is not critical.
	
	std::vector<std::string> *exp = createExplode(version, "_");

	if (exp->size() >= 2)
	{
		if (exp->at(1).compare("ext") == 0)
		{
			dispatch_async_cpp(this, mainQueue, ^{
				useExtend = true;
			});
		}
	}
	
	delete exp;
}

void TCBuddy::doAddMe()
{
	// Really, this is useless no ? :D
}

void TCBuddy::doRemoveMe()
{
	// Dude ! Don't touch my buddy list, okay ?
}

void TCBuddy::doFileName(const std::string &uuid, const std::string &fsize, const std::string &bsize, const std::string &filename)
{	
	// Quick check
	std::string *sfilename_1 = createReplaceAll(filename, "..", "_");
	std::string *sfilename_2 = createReplaceAll(*sfilename_1, "/", "_");
	
	
	// Get the download folder
	std::string down = config->real_path(config->get_download_folder());
	
	mkdir(down.c_str(), S_IRWXU | (S_IRGRP | S_IXGRP) | (S_IRWXO | S_IXOTH));
	
	
	// Build the filnal download path
	down = down + "/" + address() + "/";
	
	mkdir(down.c_str(), S_IRWXU | (S_IRGRP | S_IXGRP) | (S_IRWXO | S_IXOTH));
	
	
	// Parse values
	uint64_t	ifsize = strtoull(fsize.c_str(), NULL, 10);
	uint64_t	ibsize = strtoull(bsize.c_str(), NULL, 10);

	TCFileReceive *file = NULL;

	// Build a receiver instance
	// Try to open the file for send
	try
	{
		file = new TCFileReceive(uuid, down, *sfilename_2, ifsize, ibsize);
	}
	catch (std::string error)
	{
		if (file)
			file->release();
		
		_error(tcbuddy_error_receive_file, error, false);
		return;
	}
	
	// Add it to the list
	dispatch_async_cpp(this, mainQueue, ^{
		freceive[file->uuid()] = file;
		
		TCFileInfo *info = new TCFileInfo(file);
		
		_notify(tcbuddy_notify_file_receive_start, "core_bd_note_file_receive_start", info);
		
		info->release();
	});

	// Clean
	delete sfilename_1;
	delete sfilename_2;
}

void TCBuddy::doFileData(const std::string &uuid, const std::string &start, const std::string &hash, const std::string &data)
{	
	std::string *c_uuid = new std::string(uuid);
	std::string *c_start = new std::string(start);
	std::string *c_hash = new std::string(hash);
	std::string *c_data = new std::string(data);
	
	// Manage file chunk
	dispatch_async_cpp(this, mainQueue, ^{
		
		frec_iterator	it = freceive.find(*c_uuid);
		
		if (it != freceive.end())
		{
			TCFileReceive	*file = it->second;
			uint64_t		offset = strtoull(c_start->c_str(), NULL, 10);
			
			if (file->writeChunk(c_data->data(), c_data->size(), *c_hash, &offset))
			{
				// Send that this chunk is okay
				_sendFileDataOk(*c_uuid, offset);
				
				// Notify of the new chunk
				TCFileInfo *info = new TCFileInfo(file);
				
				_notify(tcbuddy_notify_file_receive_running, "core_bd_note_file_chunk_receive", info);

				// Do nothing if we are no more to send
				if (file->isFinished())
				{
					// Notify that we have finished
					_notify(tcbuddy_notify_file_receive_finish, "core_bd_note_file_receive_finish", info);

					// Release file
					file->release();
					freceive.erase(it);
				}
				
				// Release info
				info->release();
			}
			else
				_sendFileDataError(*c_uuid, offset);
		}
		else
		{
			_sendFileStopSending(*c_uuid);
		}
		
		// Clean
		delete c_uuid;
		delete c_start;
		delete c_hash;
		delete c_data;
	});
}

void TCBuddy::doFileDataB64(const std::string &uuid, const std::string &start, const std::string &hash, const std::string &data)
{	
	std::string *c_uuid = new std::string(uuid);
	std::string *c_start = new std::string(start);
	std::string *c_hash = new std::string(hash);
	std::string *c_data = new std::string(data);
	
	// Manage file chunk
	dispatch_async_cpp(this, mainQueue, ^{
		
		frec_iterator	it = freceive.find(*c_uuid);
		
		if (it != freceive.end())
		{
			TCFileReceive	*file = it->second;
			uint64_t		offset = strtoull(c_start->c_str(), NULL, 10);
			
			void			*odata = NULL;
			size_t			osize = 0;
			
			if (createDecodeBase64(*c_data, &osize, &odata))
			{
				if (file->writeChunk(odata, osize, *c_hash, &offset))
				{
					// Send that this chunk is okay
					_sendFileDataOk(*c_uuid, offset);

					// Notify of the new chunk
					TCFileInfo *info = new TCFileInfo(file);
					
					_notify(tcbuddy_notify_file_receive_running, "core_bd_note_file_chunk_receive", info);
					
					// Do nothing if we are no more to send
					if (file->isFinished())
					{
						// Notify that we have finished
	
						_notify(tcbuddy_notify_file_receive_finish, "core_bd_note_file_receive_finish", info);
						
						// Release the file
						file->release();
						freceive.erase(it);
					}
					
					// Release info
					info->release();
				}
				else
				{
					_sendFileDataError(*c_uuid, offset);
				}
				
				free(odata);
			}
			else
			{
				_sendFileDataError(*c_uuid, offset);
			}
		}
		else
		{
			_sendFileStopSending(*c_uuid);
		}
		
		// Clean
		delete c_uuid;
		delete c_start;
		delete c_hash;
		delete c_data;
	});
}

void TCBuddy::doFileDataOk(const std::string &uuid, const std::string &start)
{	
	std::string *c_uuid = new std::string(uuid);
	std::string *c_start = new std::string(start);
	
	// Manage file chunk
	dispatch_async_cpp(this, mainQueue, ^{
		
		fsend_iterator	it = fsend.find(*c_uuid);
		
		if (it != fsend.end())
		{
			uint64_t	offset = strtoull(c_start->c_str(), NULL, 10);
			TCFileSend	*file = it->second;
			
			// Inform that this offset was validated
			file->setValidatedOffset(offset);
			
			// Notice the advancing
			TCFileInfo *info = new TCFileInfo(file);
			
			_notify(tcbuddy_notify_file_send_running, "core_bd_note_file_chunk_send", info);
			
			// Do nothing if we are no more to send
			if (file->isFinished())
			{
				// Notify
				_notify(tcbuddy_notify_file_send_finish, "core_bd_note_file_send_finish", info);
				
				// Release the file
				file->release();
				fsend.erase(it);
			}
			else
				_runPendingFileWrite();
			
			// Release info
			info->release();
		}
		else
		{
			_sendFileStopReceiving(*c_uuid);
		}
		
		// Clean
		delete c_uuid;
		delete c_start;
	});
}

void TCBuddy::doFileDataError(const std::string &uuid, const std::string &start)
{	
	std::string *c_uuid = new std::string(uuid);
	std::string *c_start = new std::string(start);

	// Manage file chunk
	dispatch_async_cpp(this, mainQueue, ^{

		fsend_iterator	it = fsend.find(*c_uuid);
		
		if (it != fsend.end())
		{
			TCFileSend	*file = it->second;
			uint64_t	offset = strtoull(c_start->c_str(), NULL, 10);
			
			// Set the position where we should re-send
			file->setNextChunkOffset(offset);
		}
		else
		{
			_sendFileStopReceiving(*c_uuid);
		}
		
		// Clean
		delete c_uuid;
		delete c_start;
	});
}

void TCBuddy::doFileStopSending(const std::string &uuid)
{	
	std::string *c_uuid = new std::string(uuid);
	
	// Manage file chunk
	dispatch_async_cpp(this, mainQueue, ^{
		
		fsend_iterator	it = fsend.find(*c_uuid);
		
		if (it != fsend.end())
		{
			TCFileSend	*file = it->second;
			
			// Notify that we stop sending the file
			TCFileInfo *info = new TCFileInfo(file);
			
			_notify(tcbuddy_notify_file_send_stoped, "core_bd_note_file_send_stoped", info);
			
			info->release();

			
			// Release file
			file->release();
			fsend.erase(it);
		}
		
		// Clean
		delete c_uuid;
	});
}

void TCBuddy::doFileStopReceiving(const std::string &uuid)
{	
	std::string *c_uuid = new std::string(uuid);
	
	// Manage file chunk
	dispatch_async_cpp(this, mainQueue, ^{
		
		frec_iterator	it = freceive.find(*c_uuid);
		
		if (it != freceive.end())
		{
			TCFileReceive	*file = it->second;
			
			// Notify that we stop receiving the file
			TCFileInfo *info = new TCFileInfo(file);
			
			_notify(tcbuddy_notify_file_receive_stoped, "core_bd_note_file_receive_stoped", info);
			
			info->release();
			
			// Release file
			file->release();
			freceive.erase(it);
		}
		
		// Clean
		delete c_uuid;
	});
}

void TCBuddy::parserError(TCInfo *err)
{
	if (!err)
		return;
	
	err->retain();
	
	dispatch_async_cpp(this, mainQueue, ^{
		_error(tcbuddy_error_parse, "core_bd_err_parse", err, false);
		
		err->release();
	});
}



/*
** TCBuddy - Content
*/
#pragma mark -
#pragma mark TCBuddy - Content

std::vector<std::string *>	TCBuddy::getMessages()
{
	__block std::vector<std::string *> cpy;
	
	dispatch_sync_cpp(this, mainQueue, ^{
		cpy = messages;
		
		messages.clear();
	});
	
	return cpy;
}



/*
** TCBuddy - Send Low Command
*/
#pragma mark -
#pragma mark TCBuddy - Send Low Command

void TCBuddy::_sendPing()
{
	// > mainQueue <
	
	std::vector <std::string> items;
	
	items.push_back(config->get_self_address());
	items.push_back(mrandom);
	
	_sendCommand("ping", items);
}

void TCBuddy::_sendPong(const std::string &random)
{
	// > mainQueue <
	
    _sendCommand("pong", random);
}

void TCBuddy::_sendStatus(tccontroller_status status)
{
	// > mainQueue <
	
	switch (status)
	{
		case tccontroller_available:
			_sendCommand("status", "available");
			break;
			
		case tccontroller_away:
			_sendCommand("status", "away");
			break;
			
		case tccontroller_xa:
			_sendCommand("status", "xa");
			break;
	}
}

void TCBuddy::_sendMessage(const std::string &message)
{
	// > mainQueue <
	
	_sendCommand("message", message);
}

void TCBuddy::_sendVersion()
{
	// > mainQueue <
	
	_sendCommand("version", "0.9.9.287");
}

void TCBuddy::_sendAddMe()
{
	// > mainQueue <
	
	_sendCommand("add_me");
}

void TCBuddy::_sendFileName(TCFileSend *file)
{
	// > mainQueue <
	
	if (!file)
		return;
	
	std::vector <std::string> items;
	
	char		buffer[1024];
	
	// Add the uuid
	items.push_back(std::string(file->uuid()));
	
	// Add the file size
	snprintf(buffer, sizeof(buffer), "%llu", file->fileSize());
	items.push_back(std::string(buffer));
	
	// Add the block size
	snprintf(buffer, sizeof(buffer), "%u", file->blockSize());
	items.push_back(std::string(buffer));
	
	// Add the filename
	items.push_back(std::string(file->fileName()));
	
	// Send the command
	_sendCommand("filename", items, tcbuddy_channel_in);
}

void TCBuddy::_sendFileData(TCFileSend *file)
{
	// > mainQueue <
	
	if (!file)
		return;
	
	uint8_t		chunk[file->blockSize()];
	uint64_t	chunksz = 0;
	uint64_t	offset = 0;
	std::string	*md5 = NULL;
	
	md5 = file->readChunk(chunk, &chunksz, &offset);
	
	if (md5)
	{		
		std::vector <std::string>	items;
		char						buffer[50];
		
		// Add UUID
		items.push_back(file->uuid());
		
		// Add the offset
		snprintf(buffer, sizeof(buffer), "%llu", offset);
		items.push_back(buffer);
		
		// Add the MD5
		items.push_back(*md5);
		delete md5;
		
		// add the data
		std::string chk((char *)chunk, chunksz);
		items.push_back(chk);
		
		// Send the chunk
		_sendCommand("filedata", items, tcbuddy_channel_in);
	}
}

void TCBuddy::_sendFileDataB64(TCFileSend *file)
{	
	// > mainQueue <
	
	if (!file)
		return;
	
	uint8_t		chunk[file->blockSize()];
	uint64_t	chunksz = 0;
	uint64_t	offset = 0;
	std::string	*md5 = NULL;
	
	md5 = file->readChunk(chunk, &chunksz, &offset);
		
	if (md5)
	{		
		std::vector <std::string>	items;
		char						buffer[50];
		
		// Add UUID
		items.push_back(file->uuid());
		
		// Add the offset
		snprintf(buffer, sizeof(buffer), "%llu", offset);
		items.push_back(buffer);
		
		// Add the MD5
		items.push_back(*md5);
		delete md5;
		
		// Add the data
		std::string *b64 = createEncodeBase64(chunk, chunksz);
		items.push_back(*b64);
		delete b64;
		
		// Send the chunk
		_sendCommand("filedata_b64", items, tcbuddy_channel_in);
	}
}

void TCBuddy::_sendFileDataOk(const std::string &uuid, uint64_t start)
{
	// > mainQueue <
	
	std::vector<std::string>	items;
	char						buffer[100];
	
	// Add UUID
	items.push_back(uuid);
	
	// Add the offset
	snprintf(buffer, sizeof(buffer), "%llu", start);
	
	items.push_back(buffer);
	
	
	// Send the command
	_sendCommand("filedata_ok", items);
}

void TCBuddy::_sendFileDataError(const std::string &uuid, uint64_t start)
{
	// > mainQueue <
	
	std::vector<std::string>	items;
	char						buffer[100];
	
	// Add UUID
	items.push_back(uuid);
	
	// Add the offset
	snprintf(buffer, sizeof(buffer), "%llu", start);
	
	items.push_back(buffer);
	
	// Send the command
	_sendCommand("filedata_error", items);
}

void TCBuddy::_sendFileStopSending(const std::string &uuid)
{
	// > mainQueue <
	
	_sendCommand("file_stop_sending", uuid);
}

void TCBuddy::_sendFileStopReceiving(const std::string &uuid)
{
	// > mainQueue <
	
	_sendCommand("file_stop_receiving", uuid);
}



/*
** TCBuddy - Send Command Data
*/
#pragma mark -
#pragma mark TCBuddy - Send Command Data

bool TCBuddy::_sendCommand(const std::string &command, tcbuddy_channel channel)
{
	// > mainQueue <
	
	return _sendCommand(command, "", channel);
}

bool TCBuddy::_sendCommand(const std::string &command, const std::vector<std::string> &data, tcbuddy_channel channel)
{
	// > mainQueue <
	
	std::string *result = createJoin(data, " ");
	bool		bresult;

	// Send the command
	bresult = _sendCommand(command, *result, channel);
	
	// Clean
	delete result;
	
	return bresult;
}

bool TCBuddy::_sendCommand(const std::string &command, const std::string &data, tcbuddy_channel channel)
{
	// > mainQueue <
	
	// -- Build the command line --
	std::string *part = new std::string(command);
	
	if (data.size() > 0)
	{
		part->append(" ");
		part->append(data);
	}
	
	// Escape protocol special chars
	std::string *l1 = createReplaceAll(*part, "\\", "\\/");
	std::string *l2 = createReplaceAll(*l1, "\n", "\\n");
		
	l2->append("\n");
	
	delete part;
	delete l1;

	// -- Buffer or send the command --
	if (socksstate != socks_finish)
	{
		bufferedCommands.push_back(l2);
		
		if (!running)
			start();
	}
	else
	{
		_sendData(l2->data(), l2->size(), channel);
		delete l2;
	}
	
	return true;
}

bool TCBuddy::_sendData(const void *data, size_t size, tcbuddy_channel channel)
{
	// > mainQueue <
	
	if (!data || size == 0)
		return false;

	void *cpy = malloc(size);
	
	if (!cpy)
		return false;
	
	memcpy(cpy, data, size);

	if (channel == tcbuddy_channel_in && inSocket)
		inSocket->sendData(cpy, size, false);
	else if (channel == tcbuddy_channel_out && outSocket)
		outSocket->sendData(cpy, size, false);
	else
		free(cpy);

	return true;
}



/*
** TCBuddy - Network Helper
*/
#pragma mark -
#pragma mark TCBuddy - Network Helper

void TCBuddy::_startSocks()
{
	// > mainQueue <
	
	const char			*user = "torchat";
	struct sockreq		*thisreq;
	char				*buffer;
	unsigned int		datalen;
	
	// Get the target connexion informations
	std::string host = maddress + ".onion";

	// Check data size
	datalen = sizeof(struct sockreq) + strlen(user) + 1;
	datalen += strlen(host.c_str()) + 1;
	
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
	strcpy(pos, host.c_str());
	
	// Set the next input operation
	outSocket->scheduleOperation(tcsocket_op_data, sizeof(struct sockrep), socks_v4_reply);
	
	// Send the request
	if (_sendData(buffer, datalen))
		socksstate = socks_running;
	else
		_error(tcbuddy_error_socks, "core_bd_err_socks_request", true);
	
	free(buffer);
}

void TCBuddy::_connectedSocks()
{
	// > mainQueue <
	
	// -- Send ping --
	_sendPing();
	
	// -- Send buffered commands --
	size_t i, cnt = bufferedCommands.size();
	
	for (i = 0; i < cnt; i++)
	{
		_sendData(bufferedCommands[i]->data(), bufferedCommands[i]->size());
		
		delete bufferedCommands[i];
	}
	
	bufferedCommands.clear();
}

// There is place to write, so... write
void TCBuddy::_runPendingWrite()
{
	// > mainQueue <
	
	// Try to send pending files send
	_runPendingFileWrite();
}

void TCBuddy::_runPendingFileWrite()
{
	// > mainQueue <
		
	// Send a block of each send file session
	fsend_iterator it;
	
	for (it = fsend.begin(); it != fsend.end(); it++)
	{
		TCFileSend *file = it->second;
		
		if ((file->readSize() - file->validatedSize()) >= 16 * file->blockSize())
			continue;
		
		if (useExtend)
			_sendFileDataB64(file);
		else
			_sendFileData(file);
	}
}



/*
** TCBuddy - Helper
*/
#pragma mark -
#pragma mark TCBuddy - Helper

void TCBuddy::_error(tcbuddy_info code, const std::string &info, bool fatal)
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, config->localized(info));
	
	_send_event(err);
	
	err->release();
	
	// Fatal -> stop
	if (fatal)
		stop();		
}

void TCBuddy::_error(tcbuddy_info code, const std::string &info, TCObject *ctx, bool fatal)
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, config->localized(info), ctx);
	
	_send_event(err);
	
	err->release();
	
	// Fatal -> stop
	if (fatal)
		stop();		
}

void TCBuddy::_error(tcbuddy_info code, const std::string &info, TCInfo *serr, bool fatal)
{
	// > mainQueue <
	
	TCInfo *err = new TCInfo(tcinfo_error, code, config->localized(info), serr);
	
	_send_event(err);
	
	err->release();
	
	// Fatal -> stop
	if (fatal)
		stop();	
}

void TCBuddy::_notify(tcbuddy_info notice)
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice);
	
	_send_event(ifo);
	
	ifo->release();
}

void TCBuddy::_notify(tcbuddy_info notice, const std::string &info)
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice, config->localized(info));
	
	_send_event(ifo);
	
	ifo->release();
}

void TCBuddy::_notify(tcbuddy_info notice, const std::string &info, TCObject *ctx)
{
	// > mainQueue <
	
	TCInfo *ifo = new TCInfo(tcinfo_info, notice, config->localized(info), ctx);
	
	_send_event(ifo);
	
	ifo->release();
}

void TCBuddy::_send_event(TCInfo *info)
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




/*
** TCFileInfo
*/
#pragma mark -
#pragma mark TCFileInfo

// -- Constructor --
TCFileInfo::TCFileInfo(TCFileSend *_sender)
{
	if (!_sender)
		throw "NULL TCFileSend in TCFileInfo";
	
	_sender->retain();
	
	sender = _sender;
	receiver = NULL;
}

TCFileInfo::TCFileInfo(TCFileReceive *_receiver)
{
	if (!_receiver)
		throw "NULL TCFileSend in TCFileInfo";
	
	_receiver->retain();
	
	receiver = _receiver;
	sender = NULL;
}

TCFileInfo::~TCFileInfo()
{
	if (sender)
		sender->release();
	sender = NULL;
	
	if (receiver)
		receiver->release();
	receiver = NULL;
}

// -- Property --
const std::string & TCFileInfo::uuid()
{
	if (receiver)
		return receiver->uuid();
	if (sender)
		return sender->uuid();
	
	return "";
}

uint64_t TCFileInfo::fileSizeCompleted()
{
	if (receiver)
		return receiver->receivedSize();
	if (sender)
		return sender->validatedSize();
	
	return 0;
}

uint64_t TCFileInfo::fileSizeTotal()
{
	if (receiver)
		return receiver->fileSize();
	if (sender)
		return sender->fileSize();
	
	return 0;
}

const std::string & TCFileInfo::fileName()
{
	if (receiver)
		return receiver->fileName();
	if (sender)
		return sender->fileName();
	
	return "";
}

const std::string & TCFileInfo::filePath()
{
	if (receiver)
		return receiver->filePath();
	if (sender)
		return sender->filePath();
	
	return "";
}
