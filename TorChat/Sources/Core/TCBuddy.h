/*
 *  TCBuddy.h
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



#ifndef _TCBUDDY_H_
# define _TCBUDDY_H_

# include <dispatch/dispatch.h>

# include <string>
# include <vector>
# include <map>

# include "TCController.h"
# include "TCInfo.h"

# include "TCSocket.h"
# include "TCObject.h"



/*
** Forward
*/
#pragma mark - Forward

class TCBuddy;
class TCConfig;
class TCFileReceive;
class TCFileSend;
class TCString;
class TCImage;
class TCArray;
class TCNumber;



/*
** Types
*/
#pragma mark - Types

// == Status ==
typedef enum
{
	tcbuddy_status_offline,
	tcbuddy_status_available,
	tcbuddy_status_away,
	tcbuddy_status_xa,
	
} tcbuddy_status;

// == Info Codes ==
typedef enum
{
	// -- Notify --
	tcbuddy_notify_connected_tor,
	tcbuddy_notify_connected_buddy,
	tcbuddy_notify_disconnected,
	tcbuddy_notify_identified,
	
	tcbuddy_notify_status,
	tcbuddy_notify_message,
	tcbuddy_notify_alias,
	tcbuddy_notify_notes,
	tcbuddy_notify_version,
	tcbuddy_notify_client,
	tcbuddy_notify_blocked,
		
	tcbuddy_notify_file_send_start,
	tcbuddy_notify_file_send_running,
	tcbuddy_notify_file_send_finish,
	tcbuddy_notify_file_send_stoped,
	
	tcbuddy_notify_file_receive_start,
	tcbuddy_notify_file_receive_running,
	tcbuddy_notify_file_receive_finish,
	tcbuddy_notify_file_receive_stoped,
	
	tcbuddy_notify_profile_text,
	tcbuddy_notify_profile_name,
	tcbuddy_notify_profile_avatar,
	
	
	// -- Error --
	tcbuddy_error_resolve_tor,
	tcbuddy_error_connect_tor,
	
	tcbuddy_error_socket,
	
	tcbuddy_error_socks,
	
	tcbuddy_error_too_messages,
	tcbuddy_error_message_offline,
	tcbuddy_error_message_blocked,
	
	tcbuddy_error_send_file,
	tcbuddy_error_receive_file,
	tcbuddy_error_file_offline,
	tcbuddy_error_file_blocked,
	
	tcbuddy_error_parse
} tcbuddy_info;

// == File ==
typedef enum
{
	tcbuddy_file_receive,
	tcbuddy_file_send
} tcbuddy_file_way;

// == Channel ==
typedef enum
{
	tcbuddy_channel_out,	// Connection initied by TCBuddy
	tcbuddy_channel_in,		// Connection received by TControlClient
} tcbuddy_channel;

// == Notify block ==
typedef void (^tcbuddy_event)(TCBuddy *buddy, const TCInfo *info);

// == Iterators Alias ==
typedef std::map<std::string, TCFileReceive *>::iterator		frec_iterator;
typedef std::map<std::string, TCFileSend *>::iterator			fsend_iterator;

typedef std::map<std::string, TCFileReceive *>::const_iterator	frec_const_iterator;
typedef std::map<std::string, TCFileSend *>::const_iterator		fsend_const_iterator;



/*
** TCBuddy
*/
#pragma mark - TCBuddy

// == Class ==
class TCBuddy : public TCSocketDelegate // Inherit from TCObject (via TCSocketDelegate)
{
public:
	
	// -- Instance --
	TCBuddy(TCConfig *config, const std::string &alias, const std::string &address, const std::string &notes);
	~TCBuddy();
	
	// -- Run --
	void start();
	void stop();
	
	bool isRunning();
	bool isPonged();
	void keepAlive();
	
	
	// -- Delegate --
	void setDelegate(dispatch_queue_t queue, tcbuddy_event event);
	
	// -- Accessors --
	TCString *			alias();
	void				setAlias(TCString *name);
	
	TCString *			notes();
	void				setNotes(TCString *notes);
	
	bool				blocked();
	void				setBlocked(bool blocked);
		
	tcbuddy_status		status();

	TCString & address() const	{ return *maddress; }
	TCString & brandom() const	{ return *mrandom; }
	
	// -- Files Info --
	std::string		fileFileName(const std::string &uuid, tcbuddy_file_way way);
	std::string		fileFilePath(const std::string &uuid, tcbuddy_file_way way);
	bool			fileStat(const std::string &uuid, tcbuddy_file_way way, uint64_t &done, uint64_t &total);
	void			fileCancel(const std::string &uuid, tcbuddy_file_way way);
    
	// -- Send Command --
    void            sendStatus(tccontroller_status status);
	void			sendAvatar(TCImage *avatar);
	void			sendProfileName(TCString *name);
	void			sendProfileText(TCString *text);
	void			sendMessage(TCString *message);
	void			sendFile(TCString *filepath);
	
	// -- Action --
	void			startHandshake(TCString *rrandom, tccontroller_status status, TCImage *avatar, TCString *name, TCString *text);
	void			setInputConnection(TCSocket *sock);

	// -- Content --
	TCArray *		getMessages();
	TCString *		getProfileText();
	TCImage *		getProfileAvatar();
	
	TCString *		getProfileName();		// Current profile name
	TCString *		getLastProfileName();	// Last know profile name
	TCString *		getFinalName();			// Best name representation (alias / profile name / last know profile name)


private:
	// -- TcSocket Delegate --
	virtual void	socketOperationAvailable(TCSocket *socket, tcsocket_operation operation, int tag, void *content, size_t size);
	virtual void	socketError(TCSocket *socket, TCInfo *err);
	virtual void	socketRunPendingWrite(TCSocket *socket);
	
	// -- TCParser Command --
	virtual void	doStatus(const std::string &status);
	virtual void	doMessage(const std::string &message);
	virtual void	doVersion(const std::string &version);
	virtual void	doClient(const std::string &client);
	virtual void	doProfileText(const std::string &text);
	virtual void	doProfileName(const std::string &name);
	virtual void	doProfileAvatar(const std::string &bitmap);
	virtual void	doProfileAvatarAlpha(const std::string &bitmap);
	virtual void	doAddMe();
	virtual void	doRemoveMe();
	virtual void	doFileName(const std::string &uuid, const std::string &fsize, const std::string &bsize, const std::string &filename);
	virtual void	doFileData(const std::string &uuid, const std::string &start, const std::string &hash, const std::string &data);
	virtual void	doFileDataOk(const std::string &uuid, const std::string &start);
	virtual void	doFileDataError(const std::string &uuid, const std::string &start);
	virtual void	doFileStopSending(const std::string &uuid);
	virtual void	doFileStopReceiving(const std::string &uuid);
	
	virtual void	parserError(TCInfo *err);

	// -- Send Low Command --
	void			_sendPing();
	void            _sendPong(TCString *random);
	void			_sendVersion();
	void			_sendClient();
	void			_sendProfileName(TCString *name);
	void			_sendProfileText(TCString *text);
	void			_sendAvatar(TCImage *avatar);
	void			_sendAddMe();
	void			_sendRemoveMe();
	void            _sendStatus(tccontroller_status status);
	void			_sendMessage(const std::string &message);
	void			_sendFileName(TCFileSend *file);
	void			_sendFileData(TCFileSend *file);
	void			_sendFileDataOk(const std::string &uuid, uint64_t start);
	void			_sendFileDataError(const std::string &uuid, uint64_t start);
	void			_sendFileStopSending(const std::string &uuid);
	void			_sendFileStopReceiving(const std::string &uuid);
	
	// -- Send Command Data --
	bool			_sendCommand(const std::string &command, tcbuddy_channel channel = tcbuddy_channel_out);
	bool			_sendCommand(const std::string &command, const std::vector<std::string> &data, tcbuddy_channel channel = tcbuddy_channel_out);
	bool			_sendCommand(const std::string &command, const std::string &data, tcbuddy_channel channel = tcbuddy_channel_out);
	bool			_sendCommand(const std::string &command, TCString *data, tcbuddy_channel channel = tcbuddy_channel_out);
	bool			_sendData(const void *data, size_t size, tcbuddy_channel channel = tcbuddy_channel_out);
	
	// -- Network Helper --
	void			_startSocks();
	void			_loadData();
	void			_connectedSocks();
	void			_runPendingWrite();
	void			_runPendingFileWrite();
	
	// -- Helper --
	void			_error(tcbuddy_info code, const std::string &info, bool fatal);
	void			_error(tcbuddy_info code, const std::string &info, TCObject *ctx, bool fatal);
	void			_error(tcbuddy_info code, const std::string &info, TCInfo *serr, bool fatal);
	
	void			_notify(tcbuddy_info notice);
	void			_notify(tcbuddy_info notice, const std::string &info);
	void			_notify(tcbuddy_info notice, const std::string &info, TCObject *ctx);
	
	void			_send_event(TCInfo *info);
	
	TCNumber *		_status();
	
	// -- Vars --
	// > Config
	TCConfig					*config;
	
	// > Status
	int							socksstate;
	bool						running;
	bool						ponged;
	bool						pongSent;
	
	bool						mblocked;
	
	// > Property
	TCString *					malias;
	TCString *					maddress;
	TCString *					mnotes;
	TCString *					mrandom;
		
	tcbuddy_status				mstatus;
	tccontroller_status			cstatus;

	// > Dispatch
	dispatch_queue_t			mainQueue;

	// > Socket
	TCSocket					*inSocket;
	TCSocket					*outSocket;
	
	// > Command
	std::vector<std::string *>	bufferedCommands;
	
	// Delegate
	dispatch_queue_t			nQueue;
	tcbuddy_event				nBlock;
			
	// > Profile
	TCString					*profileName;
	TCString					*profileText;
	TCImage						*profileAvatar;
		
	// > Peer
	TCString *					peerClient;
	TCString *					peerVersion;

	
	// > File session
	std::map<std::string, TCFileReceive *>	freceive;
	std::map<std::string, TCFileSend *>		fsend;
};



/*
** TCFileInfo
*/
#pragma mark - TCFileInfo

class TCFileInfo : public TCObject
{
public:
	// -- Constructor --
	TCFileInfo(TCFileSend *sender);
	TCFileInfo(TCFileReceive *receiver);
	~TCFileInfo();
	
	// -- Property --
	const std::string & uuid();
	
	uint64_t			fileSizeCompleted();
	uint64_t			fileSizeTotal();
	
	const std::string & fileName();
	const std::string & filePath();
	
private:
	TCFileSend		*sender;
	TCFileReceive	*receiver;
};

#endif
