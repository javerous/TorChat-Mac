/*
 *  TCBuddyInfoWindowsController.h
 *
 *  Copyright 2019 Avérous Julien-Pierre
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

#import "TCConfigApp.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Forward
*/
#pragma mark - Forward

@class TCBuddy;
@class TCDragImageView;
@class TCCoreManager;



/*
** TCBuddyInfoController
*/
#pragma mark - TCBuddyInfoController

@interface TCBuddyInfoWindowsController : NSObject

// -- Instance --
- (instancetype)initWithConfiguration:(id <TCConfigApp>)configuration coreManager:(TCCoreManager *)coreManager NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

// -- Tools --
- (void)showInfoForBuddy:(TCBuddy *)buddy;
- (void)closeInfoForBuddy:(TCBuddy *)buddy completionHandler:(nullable  dispatch_block_t)handler;

// -- Sync --
- (void)synchronizeWithCompletionHandler:(dispatch_block_t)handler;

@end


NS_ASSUME_NONNULL_END
