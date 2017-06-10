/*
 *  TCBuddiesWindowController.h
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

#import <Cocoa/Cocoa.h>

#import "TCConfigApp.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Forward
*/
#pragma mark - Forward

@class TCMainController;
@class TCCoreManager;
@class TCDropButton;
@class TCBuddy;



/*
**  TCBuddiesWindowController
*/
#pragma mark -  TCBuddiesWindowController

@interface TCBuddiesWindowController : NSWindowController

// -- Instance --
- (instancetype)initWithMainController:(TCMainController *)mainController configuration:(id <TCConfigApp>)configuration coreManager:(TCCoreManager *)coreMananager NS_DESIGNATED_INITIALIZER;

- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithWindow:(nullable NSWindow *)window NS_UNAVAILABLE;

// -- IBAction --
- (void)showSelectedBuddyInfo;

- (void)addBuddy;
- (void)removeSelectedBuddy;
- (void)toggleBlockForSelectedBuddy;

- (void)startChatWithSelectedBuddy;
- (void)sendFileToSelectedBuddy;

- (void)editProfile;

// -- Selection --
@property (nullable, nonatomic, readonly) TCBuddy *selectedBuddy;

// -- Synchronize --
- (void)synchronizeWithCompletionHandler:(dispatch_block_t)handler;

@end


NS_ASSUME_NONNULL_END
