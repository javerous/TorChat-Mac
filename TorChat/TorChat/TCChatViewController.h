/*
 *  TCChatViewController.h
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

#import "TCConfigApp.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Forward
*/
#pragma mark - Forward

@class TCChatViewController;
@class TCChatMessage;
@class TCBuddy;


/*
** Defines
*/
#pragma mark - Defines

#define TCChatViewMessageKey		@"message"
#define TCChatViewRemoteKey			@"remote"
#define TCChatViewTimestampKey		@"timestamp"
#define TCChatViewErrorKey			@"error"



/*
** TCChatViewController
*/
#pragma mark - TCChatViewController

@interface TCChatViewController : NSViewController

// -- Property --
@property (weak, nonatomic, readonly) TCBuddy *buddy;

// -- Instance --
+ (instancetype)chatViewWithBuddy:(TCBuddy *)buddy configuration:(id <TCConfigApp>)config;

- (instancetype)initWithBuddy:(TCBuddy *)buddy configuration:(id <TCConfigApp>)config NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;
- (nullable instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;

// -- Content --
- (void)setLocalAvatar:(NSImage *)image;

@property (nonatomic, readonly) NSUInteger messagesCount;

// -- Focus --
- (void)makeFirstResponder;

@end


NS_ASSUME_NONNULL_END
