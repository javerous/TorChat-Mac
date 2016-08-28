/*
 *  TCMainController.h
 *
 *  Copyright 2016 Avérous Julien-Pierre
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


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TCMainControllerErrorDomain @"TCMainControllerErrorDomain"


/*
** Forward
*/
#pragma mark - Forward

@class TCPreferencesWindowController;
@class TCBuddiesWindowController;
@class TCChatWindowController;
@class TCFilesWindowController;
@class TCLogsWindowController;



/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, TCMainControllerResult) {
	TCMainControllerResultStarted,	// context = nil
	TCMainControllerResultCanceled,	// context = nil
	TCMainControllerResultErrored,	// context = NSError
};



/*
** TCMainController
*/
#pragma mark - TCMainController

@interface TCMainController : NSObject

// -- Life --
- (void)startWithCompletionHandler:(void (^)(TCMainControllerResult result, id _Nullable context))handler;
- (void)stopWithCompletionHandler:(dispatch_block_t)handler;

@property (nonatomic) void (^fatalErrorHandler)(NSString *errorCause);

// -- Controllers --
@property (nonatomic, readonly) TCPreferencesWindowController	*preferencesController;
@property (nonatomic, readonly) TCBuddiesWindowController		*buddiesController;
@property (nonatomic, readonly) TCChatWindowController			*chatController;
@property (nonatomic, readonly) TCFilesWindowController			*filesController;
@property (nonatomic, readonly) TCLogsWindowController			*logsController;

@end

NS_ASSUME_NONNULL_END
