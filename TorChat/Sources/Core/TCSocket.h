/*
 *  TCSocket.h
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



#ifndef _TCSOCKET_H_
# define _TCSOCKET_H_

# include <sys/types.h>
# include <dispatch/dispatch.h>

# include <vector>

# include "TCObject.h"



/*
** Forward
*/
#pragma mark - Forward

@class TCBuffer;
class TCSocket;
class TCInfo;
class TCSocketOperation;



/*
** Types
*/
#pragma mark - Types

// == Socket Errors ==
typedef enum
{
    tcsocket_read_closed,
	tcsocket_read_error,
	tcsocket_read_full,
	
	tcsocket_write_closed,
	tcsocket_write_error,
    
} tcsocket_error;

// == Socket Operations ==
typedef enum
{
	tcsocket_op_data,
	tcsocket_op_line
} tcsocket_operation;



/*
** TCSocketDelegate
*/
#pragma mark - TCSocketDelegate

// == Class ==
class TCSocketDelegate : public TCObject
{
public:
	// -- Delegate Function --
	virtual void socketOperationAvailable(TCSocket *socket, tcsocket_operation operation, int tag, void *content, size_t size) { };
	virtual void socketError(TCSocket *socket, TCInfo *err) { };
	virtual void socketRunPendingWrite(TCSocket *socket) { };
};



/*
** TCSocket
*/
#pragma mark - TCSocket

// == Class ==
class TCSocket : public TCObject
{
public:
	// -- Constructor & Destructor --
	TCSocket(int socket);
	~TCSocket();
	
	// -- Delegate --
	void	setDelegate(dispatch_queue_t queue, TCSocketDelegate *delegate);
	
	// -- Sending --
	bool	sendData(void *data, size_t size, bool copy = true);
	bool	sendData(const TCBuffer &buffer);
	
	// -- Operations --
	void	setGlobalOperation(tcsocket_operation op, size_t psize, int tag);
	void	removeGlobalOperation();
	
	void	scheduleOperation(tcsocket_operation op, size_t psize, int tag);
	
	// -- Running --
	void	stop();
	
private:
	
	// -- Errors --
	void	_callError(tcsocket_error error, const std::string &info, bool fatal);
	
	// -- Data Input --
	void	_dataAvailable();
	bool	_runOperation(TCSocketOperation *operation);
	
	// -- Vars --
	// > Managed socket
	int									_sock;

	// > Queue & Sources
	dispatch_queue_t					socketQueue;
	
	dispatch_source_t					tcpReader;
	dispatch_source_t					tcpWriter;
	
	// > Buffer
	TCBuffer							*readBuffer;
	TCBuffer							*writeBuffer;
	bool								writeActive;
	
	// > Delegate Object
	dispatch_queue_t					delQueue;
	TCSocketDelegate					*delObject;
	
	// > Operations
	TCSocketOperation					*goperation;
	std::vector<TCSocketOperation *>	operations;

};

#endif
