/*
 *  TCConnection.h
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

@class TCConnection;
@class TCInfo;
@class TCSocket;



/*
** TCConnectionDelegate
*/
#pragma mark - TCConnectionDelegate

@protocol TCConnectionDelegate <NSObject>

- (void)connection:(TCConnection *)connection pingAddress:(NSString *)address withRandomToken:(NSString *)random;
- (void)connection:(TCConnection *)connection pongWithSocket:(TCSocket *)socket andRandomToken:(NSString *)random;

- (void)connection:(TCConnection *)connection information:(TCInfo *)info;

@end



/*
** TCConnection
*/
#pragma mark - TCConnection

@interface TCConnection : NSObject

// -- Instance --
- (id)initWithDelegate:(id <TCConnectionDelegate>)delegate andSocket:(int)sock;

// -- Life --
- (void)start;
- (void)stop;

@end
