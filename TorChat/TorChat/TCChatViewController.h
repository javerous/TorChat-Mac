/*
 *  TCChatViewController.h
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

#import <Foundation/Foundation.h>


/*
** Forward
*/
#pragma mark - Forward

@class TCChatViewController;



/*
** TCChatViewController - Delegate
*/
#pragma mark - TCChatViewController - Delegate

@protocol TCChatViewDelegate <NSObject>

- (void)chat:(TCChatViewController *)chat sendMessage:(NSString *)message;

@end



/*
** TCChatViewController
*/
#pragma mark - TCChatViewController

@interface TCChatViewController : NSViewController

// -- Property --
@property (strong, nonatomic, readonly) NSString *bidentifier;
@property (strong, nonatomic)			NSString *name;

@property (weak, atomic)				id <TCChatViewDelegate> delegate;


// -- Instance --
+ (TCChatViewController *)chatViewWithIdentifier:(NSString *)identifier name:(NSString *)name delegate:(id <TCChatViewDelegate>)delegate;

// -- Content --
- (void)receiveMessage:(NSString *)message;
- (void)receiveError:(NSString *)error;
- (void)receiveStatus:(NSString *)status;

- (void)setLocalAvatar:(NSImage *)image;
- (void)setRemoteAvatar:(NSImage *)image;

- (NSUInteger)messagesCount;

// -- Focus --
- (void)makeFirstResponder;

@end
