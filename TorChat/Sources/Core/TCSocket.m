/*
 *  TCSocket.h
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

#import "TCSocket.h"

#import "TCDebugLog.h"
#import "TCBuffer.h"
#import "TCTools.h"
#import "TCInfo.h"



/*
** TCSocketOperation
*/
#pragma mark - TCSocketOperation

@interface TCSocketOperation : NSObject

@property (assign, nonatomic) tcsocket_operation	operation;
@property (assign, nonatomic) NSUInteger			size;
@property (assign, nonatomic) NSUInteger			tag;
@property (strong, nonatomic) id					context;

@end



/*
** TCSocket - Private
*/
#pragma mark - TCSocket - Private

@interface TCSocket ()
{
	// -- Vars --
	// > Managed socket
	int					_sock;
	
	// > Queue & Sources
	dispatch_queue_t	_socketQueue;
	
	dispatch_source_t	_tcpReader;
	dispatch_source_t	_tcpWriter;
	
	// > Buffer
	TCBuffer			*_readBuffer;
	TCBuffer			*_writeBuffer;
	bool				_writeActive;
	
	// > Delegate
	dispatch_queue_t	_delegateQueue;
	__weak id <TCSocketDelegate> _delegate;
	
	// > Operations
	TCSocketOperation	*_goperation;
	NSMutableArray		*_operations;
}

// -- Errors --
- (void)callError:(tcsocket_error) error info:(NSString *)info fatal:(BOOL)fatal;

// -- Data Input --
- (void)_dataAvailable;
- (BOOL)_runOperation:(TCSocketOperation *)operation;

@end



/*
** TCSocket
*/
#pragma mark - TCSocket

@implementation TCSocket


/*
** TCSocket - Instance
*/
#pragma mark - TCSocket - Instance

- (id)initWithSocket:(int)descriptor
{
	self = [super init];
	
	if (self)
	{
		// -- Set vars --
		_sock = descriptor;

		// -- Configure socket as asynchrone --
		doAsyncSocket(_sock);
		
		// -- Create Buffer --
		_readBuffer = [[TCBuffer alloc] init];
		_writeBuffer = [[TCBuffer alloc] init];
		
		// Create containers.
		_operations = [[NSMutableArray alloc] init];
		
		// -- Create Queue --
		_socketQueue = dispatch_queue_create("com.torchat.core.socket.main", DISPATCH_QUEUE_SERIAL);
		_delegateQueue = dispatch_queue_create("com.torchat.core.socket.delegate", DISPATCH_QUEUE_SERIAL);

		// -- Build Read / Write Source --
		_tcpReader = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)_sock, 0, _socketQueue);
		_tcpWriter = dispatch_source_create(DISPATCH_SOURCE_TYPE_WRITE, (uintptr_t)_sock, 0, _socketQueue);
		
		// Set the read handler
		dispatch_source_set_event_handler(_tcpReader, ^{
			
			// Build a buffer to read available data
			size_t		estimate = dispatch_source_get_data(_tcpReader);
			void		*buffer = malloc(estimate);
			ssize_t		sz;
			
			// Read data
			sz = read(_sock, buffer, estimate);
			
			// Check read result
			if (sz < 0)
			{
				[self callError:tcsocket_read_error info:@"core_socket_read_error" fatal:YES];
				free(buffer);
			}
			else if (sz == 0 && errno != EAGAIN)
			{
				[self callError:tcsocket_read_closed info:@"core_socket_read_closed" fatal:YES];
				free(buffer);
			}
			else if (sz > 0)
			{
				if ([_readBuffer size] + (size_t)sz > 50 * 1024 * 1024)
				{
					[self callError:tcsocket_read_full info:@"core_socker_read_full" fatal:YES];
					free(buffer);
				}
				else
				{
					// Append data to the buffer
					[_readBuffer appendBytes:buffer ofSize:(NSUInteger)sz copy:NO];
					
					// Manage datas
					[self _dataAvailable];
				}
			}
			else
				free(buffer);
		});
		
		// Set the read handler
		dispatch_source_set_event_handler(_tcpWriter, ^{
			
			// If we are no more data, deactivate the write event, else write them
			if ([_writeBuffer size] == 0)
			{
				if (_writeActive)
				{
					_writeActive = false;
					dispatch_suspend(_tcpWriter);
				}
			}
			else
			{
				char		buffer[4096];
				NSUInteger	size = [_writeBuffer readBytes:buffer ofSize:sizeof(buffer)];
				ssize_t		sz;
				
				// Write data
				sz = write(_sock, buffer, size);
				
				// Check write result
				if (sz < 0)
				{
					[self callError:tcsocket_write_error info:@"core_socket_write_error" fatal:YES];
				}
				else if (sz == 0 && errno != EAGAIN)
				{
					[self callError:tcsocket_write_closed info:@"core_socket_write_closed" fatal:YES];
				}
				else if (sz > 0)
				{
					// Reinject remaining data in the buffer
					if (sz < size)
						[_writeBuffer pushBytes:buffer + sz ofSize:(size - (NSUInteger)sz) copy:YES];
					
					// If we have space, signal it to fill if necessary
					id <TCSocketDelegate> delegate = _delegate;
					
					if ([_writeBuffer size] < 1024 && _delegateQueue && delegate)
					{
						dispatch_async(_delegateQueue, ^{
							[delegate socketRunPendingWrite:self];
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
		
		dispatch_source_set_cancel_handler(_tcpReader, bcancel);
		dispatch_source_set_cancel_handler(_tcpWriter, bcancel);
		
		// -- Resume Read Source --
		dispatch_resume(_tcpReader);
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog("TCSocket Destructor");
}


/*
** TCSocket - Delegate
*/
#pragma mark - TCSocket - Delegate

- (void)setDelegate:(id<TCSocketDelegate>)delegate
{
	dispatch_async(_socketQueue, ^{
		
		// Hold delegate.
		_delegate = delegate;
		
		if (!delegate)
			return;

		// Check if some data can send to the new delegate
		if ([_readBuffer size] > 0)
			[self _dataAvailable];
	});
}

- (id <TCSocketDelegate>)delegate
{
	__block id <TCSocketDelegate> delegate;
	
	dispatch_sync(_socketQueue, ^{
		delegate = _delegate;
	});
	
	return delegate;
}



/*
** TCSocket - Sending
*/
#pragma mark - TCSocket - Sending

- (BOOL)sendBytes:(const void *)bytes ofSize:(NSUInteger)size copy:(BOOL)copy
{
	if (!bytes || size == 0)
		return NO;
	
	void *cpy = NULL;
	
	// Copy data if needed.
	if (copy)
	{
		cpy = malloc(size);
		
		memcpy(cpy, bytes, size);
	}
	else
		cpy = (void *)bytes;
	
	// Put data in send buffer, and activate sending if needed.
	dispatch_async(_socketQueue, ^{
		
		// Check that we can alway write
		if (!_tcpWriter)
		{
			free(cpy);
			return;
		}
		
		// Append data in write buffer
		[_writeBuffer appendBytes:cpy ofSize:size copy:NO];
		
		// Activate write if needed
		if ([_writeBuffer size] > 0 && !_writeActive)
		{
			_writeActive = YES;
			
			dispatch_resume(_tcpWriter);
		}
	});
	
	return true;
}

- (BOOL)sendBuffer:(TCBuffer *)buffer
{
	if ([buffer size] == 0)
		return NO;
	
	return NO;
}



/*
** TCSocket - Operations
*/
#pragma mark - TCSocket - Operations

- (void)setGlobalOperation:(tcsocket_operation)operation withSize:(NSUInteger)size andTag:(NSUInteger)tag
{
	dispatch_async(_socketQueue, ^{
		
		// Create global operation.
		_goperation = [[TCSocketOperation alloc] init];
		
		_goperation.operation = operation;
		_goperation.size = size;
		_goperation.tag = tag;
		
		// Check if operations can be executed.
		if ([_readBuffer size] > 0)
			[self _dataAvailable];
	});
}

- (void)removeGlobalOperation
{
	dispatch_async(_socketQueue, ^{
		_goperation = nil;
	});
}

- (void)scheduleOperation:(tcsocket_operation)operation withSize:(NSUInteger)size andTag:(NSUInteger)tag
{
	dispatch_async(_socketQueue, ^{
		
		// Create global operation.
		TCSocketOperation *op = [[TCSocketOperation alloc] init];
		
		op.operation = operation;
		op.size = size;
		op.tag = tag;
		
		// Add the operation.
		[_operations addObject:op];
		
		// Check if operations can be executed.
		if ([_readBuffer size] > 0)
			[self _dataAvailable];
	});
}



/*
** TCSocket - Life
*/
#pragma mark - TCSocket - Life

- (void)stop
{
	dispatch_async(_socketQueue, ^{
		
		if (_tcpWriter)
		{
			// Resume the source if suspended.
			if (!_writeActive)
				dispatch_resume(_tcpWriter);
			
			// Cancel & release it
			dispatch_source_cancel(_tcpWriter);
			_tcpWriter = nil;
		}
		
		if (_tcpReader)
		{
			// Cancel & release the source.
			dispatch_source_cancel(_tcpReader);
			_tcpReader = nil;
		}
	});
}



/*
** TCSocket - Errors
*/
#pragma mark - TCSocket - Errors

- (void)callError:(tcsocket_error)error info:(NSString *)info fatal:(BOOL)fatal
{
	// If fatal, just stop.
	if (fatal)
		[self stop];
	
	// Check delegate
	id <TCSocketDelegate> delegate = _delegate;
	
	if (!delegate)
		return;
	
	TCInfo *err = [TCInfo infoOfKind:tcinfo_error infoCode:error infoString:info];
	
	// Dispatch on the delegate queue.
	dispatch_async(_delegateQueue, ^{
		[delegate socket:self error:err];
	});
}



/*
** TCSocket - Data Input
*/
#pragma mark - TCSocket - Data Input

- (void)_dataAvailable
{
	// > socketQueue <
		
	// Check if we have a global operation, else execute scheduled operation.
	if (_goperation)
	{
		while (1)
		{
			if (![self _runOperation:_goperation])
				break;
		}
	}
	else
	{
		NSMutableIndexSet	*indexes = [[NSMutableIndexSet alloc] init];
		NSUInteger			i, count = [_operations count];
		
		for (i = 0; i < count; i++)
		{
			TCSocketOperation *op = _operations[i];
			
			if ([self _runOperation:op])
				[indexes addIndex:i];
			else
				break;
		}
		
		[_operations removeObjectsAtIndexes:indexes];
	}
}

- (BOOL)_runOperation:(TCSocketOperation *)operation
{
	// > socketQueue <
	
	if (!operation)
		return NO;
	
	// Check delegate.
	id <TCSocketDelegate> delegate = _delegate;
	
	if (!delegate)
		return NO;
	
	// Nothing to read, nothing to do.
	if ([_readBuffer size] == 0)
		return false;
	
	// Execute the  operation.
	switch (operation.operation)
	{
		// Operation is to read a chunk of raw data.
		case tcsocket_op_data:
		{
			// Get the amount to read.
			NSUInteger size = operation.size;
			
			if (size == 0)
				size = [_readBuffer size];
			
			if (size > [_readBuffer size])
				return NO;
			
			void		*buffer = malloc(size);
			NSUInteger	tag = operation.tag;
			NSData		*data;
			
			// Read the chunk of data.
			size = [_readBuffer readBytes:buffer ofSize:size];
			
			data = [[NSData alloc] initWithBytesNoCopy:buffer length:size freeWhenDone:YES];
			
			// -- Give to delegate --
			dispatch_async(_delegateQueue, ^{
				[delegate socket:self operationAvailable:tcsocket_op_data tag:tag content:data];
			});
			
			return YES;
		}
			
		// Operation is to read lines.
		case tcsocket_op_line:
		{
			NSUInteger		max = operation.size;
			NSMutableArray	*lines = NULL;
			NSUInteger		tag = operation.tag;
			
			// Build lines vector
			if (operation.context)
				lines = operation.context;
			else
			{
				lines = [[NSMutableArray alloc] init];
				
				operation.context = lines;
			}
			
			// Parse lines
			while (1)
			{
				// Check that we have the amount of line needed.
				if (max > 0 && [lines count] >= max)
					break;
				
				// Get line
				NSData *line = [_readBuffer dataUpToCStr:"\n" includeSearch:NO];
								
				if (!line)
					break;
				
				// Add the line
				[lines addObject:line];
			}
			
			// Check that we have lines
			if ([lines count] == 0)
				return NO;
			
			// Check that we have enought lines.
			if (max > 0 && [lines count] < max)
				return NO;
			
			// Clean context (the delegate is responsive to deallocate lines).
			operation.context = nil;
						
			// -- Give to delegate --
			dispatch_async(_delegateQueue, ^{
				[delegate socket:self operationAvailable:tcsocket_op_line tag:tag content:lines];
			});
			
			return YES;
		}
	}
	
	return NO;
}

@end



/*
** TCSocketOperation
*/
#pragma mark - TCSocketOperation

@implementation TCSocketOperation

@end
