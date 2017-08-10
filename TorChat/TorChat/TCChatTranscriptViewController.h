/*
 *  TCChatTranscriptViewController.h
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
** Forward
*/
#pragma mark - Forward

@class TCTheme;



/*
** TCChatTranscriptViewController
*/
#pragma mark - TCChatTranscriptViewController

@interface TCChatTranscriptViewController : NSViewController

// -- Instance --
- (instancetype)initWithTheme:(TCTheme *)theme NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

// -- Content --
- (void)addItems:(NSArray *)items endOfTranscript:(BOOL)endOfTranscript; // items: array of TCChatMessage and / or TCChatNotice
- (void)removeMessageID:(int64_t)msgID;

- (void)setLocalAvatar:(NSImage *)image;
- (void)setRemoteAvatar:(NSImage *)image;

// -- Helper --
- (NSUInteger)maxMessagesCountToFillHeight:(CGFloat)height;
- (CGFloat)maxHeightForMessagesCount:(NSUInteger)count;

// -- Properties --
// Message.
@property (readonly) NSUInteger messagesCount;

// View.
@property (readonly, nonatomic) CGFloat scrollOffset; // should be fetched on main queue.

// Handlers.
@property (strong, atomic) void (^errorActionHandler)(TCChatTranscriptViewController *controller, int64_t messageID); // called on global queue.
@property (strong, atomic) void (^transcriptScrollHandler)(TCChatTranscriptViewController *controller, CGFloat scrollOffset); // called on main queue.

@end


NS_ASSUME_NONNULL_END
