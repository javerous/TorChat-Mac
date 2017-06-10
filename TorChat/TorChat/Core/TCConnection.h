/*
 *  TCConnection.h
 *
 *  Copyright 2017 Avérous Julien-Pierre
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


NS_ASSUME_NONNULL_BEGIN


/*
** Globals
*/
#pragma mark - Globals

#define TCConnectionInfoDomain	@"TCConnectionInfoDomain"



/*
** Forward
*/
#pragma mark - Forward

@class TCConnection;
@class SMInfo;
@class SMSocket;



/*
** TCConnectionDelegate
*/
#pragma mark - TCConnectionDelegate

@protocol TCConnectionDelegate <NSObject>

- (void)connection:(TCConnection *)connection receivedPingWithBuddyIdentifier:(NSString *)identifier randomToken:(NSString *)random;
- (void)connection:(TCConnection *)connection receivedPongOnSocket:(SMSocket *)socket randomToken:(NSString *)random;

- (void)connection:(TCConnection *)connection information:(SMInfo *)info;

@end



/*
** TCConnection
*/
#pragma mark - TCConnection

@interface TCConnection : NSObject

// -- Instance --
- (instancetype)initWithDelegate:(id <TCConnectionDelegate>)delegate socket:(int)socketFD NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;


// -- Life --
- (void)start;
- (void)stopWithCompletionHandler:(nullable dispatch_block_t)handler;

@end


NS_ASSUME_NONNULL_END
