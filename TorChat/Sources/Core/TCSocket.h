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


#import <Foundation/Foundation.h>


/*
** Forward
*/
#pragma mark - Forward

@class TCSocket;
@class TCBuffer;
@class TCInfo;



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

@protocol TCSocketDelegate <NSObject>

@required
- (void)socket:(TCSocket *)socket operationAvailable:(tcsocket_operation)operation tag:(NSUInteger)tag content:(id)content;

@optional
- (void)socket:(TCSocket *)socket error:(TCInfo *)error;
- (void)socketRunPendingWrite:(TCSocket *)socket;

@end



/*
** TCSocket
*/
#pragma mark - TCSocket

@interface TCSocket : NSObject

// -- Properties --
@property (weak, atomic) id <TCSocketDelegate> delegate;

// -- Instance --
- (id)initWithSocket:(int)descriptor;

// -- Sending --
- (BOOL)sendBytes:(const void *)bytes ofSize:(NSUInteger)size copy:(BOOL)copy;
- (BOOL)sendBuffer:(TCBuffer *)buffer;

// -- Operations --
- (void)setGlobalOperation:(tcsocket_operation)operation withSize:(NSUInteger)size andTag:(NSUInteger)tag;
- (void)removeGlobalOperation;

- (void)scheduleOperation:(tcsocket_operation)operation withSize:(NSUInteger)size andTag:(NSUInteger)tag;

// -- Life --
- (void)stop;

@end
