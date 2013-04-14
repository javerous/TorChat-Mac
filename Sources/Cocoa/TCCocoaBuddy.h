/*
 *  TCCocoaBuddy.h
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



#import <Cocoa/Cocoa.h>

#include "TCBuddy.h"

#import "TCChatController.h"



/*
** Forward
*/
#pragma mark -
#pragma mark Forward

@class TCCocoaBuddy;



/*
** TCCocoaBuddy - Delegate
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Delegate


@protocol TCCocoaBuddyDelegate <NSObject>

- (void)buddyHasChanged:(TCCocoaBuddy *)buddy;

@end
    



/*
** TCCocoaBuddy
*/
#pragma mark -
#pragma mark TCCocoaBuddy

// == Class ==
@interface TCCocoaBuddy : NSObject <TCChatControllerDelegate>
{
@private
    TCBuddy						*buddy;
	TCChatController			*chat;
	
	dispatch_queue_t			mainQueue;
	
	id <TCCocoaBuddyDelegate>	delegate;
	
	tcbuddy_status				_status;
}

// -- Property --
@property (assign, nonatomic) id <TCCocoaBuddyDelegate>	delegate;

// -- Constructor --
- (id)initWithBuddy:(TCBuddy *)buddy;

// -- Status --
- (tcbuddy_status)status;
- (NSString *)name;
- (NSString *)address;
- (NSString *)comment;

- (void)setName:(NSString *)name;
- (void)setComment:(NSString *)comment;

// -- Actions --
- (void)openChatWindow;

// -- Handling --
- (void)yieldCore;

// -- File --
- (void)cancelFileUpload:(NSString *)uuid;
- (void)cancelFileDownload:(NSString *)uuid;

- (void)sendFile:(NSString *)fileName;

@end
