/*
 *  TCSocket.h
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



#include <errno.h>
#include <stdlib.h>

#include "TCSocket.h"

#include "TCTools.h"
#include "TCBuffer.h"
#include "TCInfo.h"



/*
** TCSocketOperation
*/
#pragma mark -
#pragma mark TCSocketOperation

// == Class ==
class TCSocketOperation
{
public:
	// -- Constructor & Destructor --
	TCSocketOperation(tcsocket_operation op, size_t size, int tag):
		_op(op),
		_size(size),
		_tag(tag),
		_ctx(NULL)
	{ };
	
	~TCSocketOperation()
	{
		if (_op == tcsocket_op_line)
		{
			if (!_ctx)
				return;
			
			std::vector<std::string *>	*lines = static_cast<std::vector<std::string *> *>(_ctx);
			size_t						i, cnt = lines->size();
			
			for (i = 0; i < cnt; i++)
				delete lines->at(i);
			
			delete lines;
		}
	}
	
	// -- Property --
	tcsocket_operation	operation() const { return _op; };
	size_t				size() const { return _size; };
	int					tag() const { return _tag; };
	void				*context() const { return _ctx; }
	
	void				setSize(size_t size) { _size = size; };
	void				setContext(void *ctx) { _ctx = ctx; };
	
private:
	tcsocket_operation	_op;
	size_t				_size;
	int					_tag;
	void				*_ctx;
};



/*
** TCSocket - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCSocket - Constructor & Destructor

TCSocket::TCSocket(int sock)
{
	// -- Set vars --
	_sock = sock;
	writeActive = false;
	goperation = NULL;
	
	delObject = NULL;
	delQueue = 0;
	
	// -- Configure socket as asynchrone --
	doAsyncSocket(_sock);
	
	// -- Create Buffer --
	readBuffer = new TCBuffer();
	writeBuffer = new TCBuffer();
	
	// -- Create Queue --
	socketQueue = dispatch_queue_create("com.torchat.core.socket.main", NULL);

	// -- Build Read / Write Source --
	tcpReader = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)_sock, 0, socketQueue);
	tcpWriter = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, (uintptr_t)_sock, 0, socketQueue);
	
	// Set the read handler
	dispatch_source_set_event_handler_cpp(this, tcpReader, ^{
		
		// Build a buffer to read available data
		size_t		estimate = dispatch_source_get_data(tcpReader);
		void		*buffer = malloc(estimate);
		ssize_t		sz;
		
		// Read data
		sz = read(sock, buffer, estimate);
		
		// Check read result
		if (sz < 0)
		{
			_callError(tcsocket_read_error, "core_socket_read_error", true);
			free(buffer);
		}
		else if (sz == 0 && errno != EAGAIN)
		{
			_callError(tcsocket_read_closed, "core_socket_read_closed", true);
			free(buffer);
		}
		else if (sz > 0)
		{			
			if (readBuffer->size() + (size_t)sz > 50 * 1024 * 1024)
			{
				_callError(tcsocket_read_full, "core_socker_read_full", true);
			}
			else
			{
				// Append data to the buffer
				readBuffer->appendData(buffer, (size_t)sz, false);
				
				// Manage datas
				_dataAvailable();
			}
		}
	});
	
	// Set the read handler
	dispatch_source_set_event_handler_cpp(this, tcpWriter, ^{
				
		// If we are no more data, deactivate the write event, else write them
		if (writeBuffer->size() == 0) 
		{
			if (writeActive)
			{
				writeActive = false;
				dispatch_suspend(tcpWriter);
			}
		}
		else
		{
			char	buffer[4096];
			size_t	size = writeBuffer->readData(buffer, sizeof(buffer));
			ssize_t	sz;
			
			// Write data
			sz = write(sock, buffer, size);
			
			// Check write result
			if (sz < 0)
			{
				_callError(tcsocket_write_error, "core_socket_write_error", true);
			}
			else if (sz == 0 && errno != EAGAIN)
			{
				_callError(tcsocket_write_closed, "core_socket_write_closed", true);
			}
			else if (sz > 0)
			{
				// Reinject remaining data in the buffer
				if (sz < size)
					writeBuffer->pushData(buffer + sz, size - (size_t)sz, true);
				
				// If we have space, signal it to fill if necessary
				if (writeBuffer->size() < 1024 && delQueue && delObject)
				{
					TCSocketDelegate *obj = delObject;
					
					obj->retain();
					dispatch_async_cpp(this, delQueue, ^{
						
						obj->socketRunPendingWrite(this);
						
						// Clean
						obj->release();
					});
				}
			}
		}
	});
	
	// -- Set Cancel Handler --
	__block int count = 2;
	
	dispatch_block_t bcancel = ^{
		
		count--;
		
		if (count <= 0 && _sock != -1)
		{
			// Close the socket
			close(_sock);
			_sock = -1;
		}
	};
	
	dispatch_source_set_cancel_handler_cpp(this, tcpReader, bcancel);
	dispatch_source_set_cancel_handler_cpp(this, tcpWriter, bcancel);
	
	// -- Resume Read Source --
	dispatch_resume(tcpReader);
}

TCSocket::~TCSocket()
{
	TCDebugLog("TCSocket Destructor");
	
	// Release queue
	dispatch_release(socketQueue);
	
	// Release buffer
	readBuffer->release();
	writeBuffer->release();
	
	if (delObject)
		delObject->release();
	
	if (delQueue)
		dispatch_release(delQueue);
	
	// Clean global operation
	if (goperation)
		delete goperation;
	goperation = NULL;
	
	// Clean global operations
	size_t i, cnt = operations.size();
	
	for (i = 0; i < cnt; i++)
		delete operations[i];
	operations.clear();
}



/*
** TCSocket - Delegate
*/
#pragma mark -
#pragma mark TCSocket - Delegate

void TCSocket::setDelegate(dispatch_queue_t queue, TCSocketDelegate *delegate)
{
	// Retain Queue
	if (queue)
		dispatch_retain(queue);
	
	// Retain Delegate
	if (delegate)
		delegate->retain();
	
	// Set items in socket queue
	dispatch_async_cpp(this, socketQueue, ^{
		
		// Set delegate queue
		if (delQueue)
			dispatch_release(delQueue);
		delQueue = queue;
		
		// Set delegate object
		if (delObject)
			delObject->release();
		delObject = delegate;
		
		// Check if some data can send to the new delegate
		if (readBuffer->size() > 0)
			_dataAvailable();
	});
}



/*
** TCSocket - Sending
*/
#pragma mark -
#pragma mark TCSocket - Sending

bool TCSocket::sendData(void *data, size_t size, bool copy)
{
	if (!data || size == 0)
		return false;
	
	void *cpy = NULL;
	
	// Copy data if needed
	if (copy)
	{
		cpy = malloc(size);
		
		memcpy(cpy, data, size);
	}
	else
		cpy = data;

	// Put data in send buffer, and activate sending if needed
	dispatch_async_cpp(this, socketQueue, ^{
		
		// Check that we can alway write
		if (!tcpWriter)
		{
			free(cpy);
			return;
		}
		
		// Append data in write buffer
		writeBuffer->appendData(cpy, size, false);
		
		// Activate write if needed
		if (writeBuffer->size() > 0 && !writeActive)
		{
			writeActive = true;
			
			dispatch_resume(tcpWriter);
		}
	});
	
	return true;
}

bool TCSocket::sendData(const TCBuffer &buffer)
{
	return false;
}



/*
** TCSocket - Operations
*/
#pragma mark -
#pragma mark TCSocket - Operations

void TCSocket::setGlobalOperation(tcsocket_operation op, size_t psize, int tag)
{
	dispatch_async_cpp(this, socketQueue, ^{
		
		if (goperation)
			delete goperation;
		
		goperation = new TCSocketOperation(op, psize, tag);
		
		// Check if operations can be executed
		if (readBuffer->size() > 0)
			_dataAvailable();
	});
}

void TCSocket::removeGlobalOperation()
{
	dispatch_async_cpp(this, socketQueue, ^{
		
		if (goperation)
			delete goperation;
		
		goperation = NULL;
	});
}

void TCSocket::scheduleOperation(tcsocket_operation op, size_t psize, int tag)
{
	dispatch_async_cpp(this, socketQueue, ^{
		
		// Add the operation
		operations.push_back(new TCSocketOperation(op, psize, tag));
		
		// Check if operations can be executed
		if (readBuffer->size() > 0)
			_dataAvailable();
	});
}



/*
** TCSocket - Running
*/
#pragma mark -
#pragma mark TCSocket - Running

void TCSocket::stop()
{
	dispatch_async_cpp(this, socketQueue, ^{
		
		if (tcpWriter)
		{
			// Resume the source if suspended
			if (!writeActive)
				dispatch_resume(tcpWriter);
			
			// Cancel & release it
			dispatch_source_cancel(tcpWriter);
			dispatch_release(tcpWriter);
			
			tcpWriter = 0;
		}

	
		if (tcpReader)
		{
			// Cancel & release the source
			dispatch_source_cancel(tcpReader);
			dispatch_release(tcpReader);
			
			tcpReader = 0;
		}
	});
}



/*
** TCSocket - Errors
*/
#pragma mark -
#pragma mark TCSocket - Errors

void TCSocket::_callError(tcsocket_error error, const std::string &info, bool fatal)
{
	// If fatal, just stop
	if (fatal)
		stop();
	
	// Check delegate
	if (!delObject || !delQueue)
		return;
	
	TCSocketDelegate	*obj = delObject;
	TCInfo				*err = new TCInfo(tcinfo_error, error, info);
	
	// Retain delegate
	obj->retain();
	
	// Dispatch on the delegate queue
	dispatch_async_cpp(this, delQueue, ^{
		
		obj->socketError(this, err);
		
		// Release
		obj->release();
		err->release();
	});
}



/*
** TCSocket - Data Input
*/
#pragma mark -
#pragma mark TCSocket - Data Input

// == Manage available data ==
void TCSocket::_dataAvailable()
{
	// Check if we have a global operation, else execute scheduled operation
	if (goperation)
	{
		while (1)
		{
			if (!_runOperation(goperation))
				break;
		}
	}
	else
	{
		std::vector<TCSocketOperation *>::iterator it = operations.begin();

		while (it != operations.end())
		{
			TCSocketOperation *op = *it;
			
			if (_runOperation(op))
			{
				delete op;
				
				it = operations.erase(it);
			}
			else
				break;
		}
	}
}

// == Run an operation on available data ==
bool TCSocket::_runOperation(TCSocketOperation *op)
{
	// Check delegate
	if (!delObject || !delQueue)
		return false;
	
	// Nothing to read, nothing to do
	if (readBuffer->size() == 0)
		return false;
	
	// Execute the  operation
	switch (op->operation())
	{
		// Operation is to read a chunk of raw data
		case tcsocket_op_data:
		{
			// Get the amount to read
			size_t size = op->size();
			
			if (size == 0)
				size = readBuffer->size();
			
			if (size > readBuffer->size())
				return false;
			
			void	*buffer = malloc(size);
			int		tag = op->tag();
			
			// Read the chunk of data
			size = readBuffer->readData(buffer, size);
			
			// -- Give to delegate --
			TCSocketDelegate *obj = delObject;
			
			// Retain delegate
			obj->retain();
			
			// Give the operation result
			dispatch_async_cpp(this, delQueue, ^{
				obj->socketOperationAvailable(this, tcsocket_op_data, tag, buffer, size);
				
				// Release delegate
				obj->release();
			});
			
			return true;
		}
			
		// Operation is to read lines
		case tcsocket_op_line:
		{
			size_t						max = op->size();
			std::vector<std::string *>	*lines = NULL;
			int							tag = op->tag();
			size_t						cnt;
			
			// Build lines vector
			if (op->context())
				lines = static_cast<std::vector<std::string *> *> (op->context());
			else
			{
				lines = new std::vector<std::string *>;
				
				op->setContext(lines);
			}
			
			// Parse lines
			while (1)
			{
				// Check that we have the amount of line needed
				if (max > 0 && lines->size() >= max)
					break;
				
				// Get line
				std::string *line = readBuffer->createStringSearch("\n", false);
				
				if (!line)
					break;
				
				// Add the line
				lines->push_back(line);
			}
			
			// Check that we have lines
			if (lines->size() == 0)
				return false;
			
			// Check that we have enought lines
			if (max > 0 && lines->size() < max)
				return false;
			
			// Clean context (the delegate is responsive to deallocate lines)
			op->setContext(NULL);
			
			cnt = lines->size();

			// -- Give to delegate --
			TCSocketDelegate *obj = delObject;
			
			// Retain delegate
			obj->retain();
				
			// Give the operation result
			dispatch_async_cpp(this, delQueue, ^{
				obj->socketOperationAvailable(this, tcsocket_op_line, tag, lines, cnt);
	
				// Release delegate and this
				obj->release();
			});

			return true;
		}
	}
	
	return false;
}

