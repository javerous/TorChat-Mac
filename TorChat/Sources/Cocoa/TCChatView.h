/*
 *  TCChatView.h
 *
 *  Copyright 2012 Avérous Julien-Pierre
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

@class TCChatTalk;
@class TCChatView;



/*
** TCChatView - Delegate
*/
#pragma mark - TCChatView - Delegate

@protocol TCChatViewDelegate <NSObject>

- (void)chat:(TCChatView *)chat sendMessage:(NSString *)message;

@end



/*
** TCChatView
*/
#pragma mark - TCChatView

@interface TCChatView : NSObject

// -- Property --
@property (assign) IBOutlet NSView		*view;

@property (assign) IBOutlet NSTextField	*userField;
@property (assign) IBOutlet TCChatTalk	*talkView;
@property (assign) IBOutlet NSBox		*lineView;
@property (assign) IBOutlet NSView		*backView;

@property (retain, nonatomic, readonly) NSString *identifier;
@property (retain, nonatomic)			NSString *name;

@property (assign, nonatomic)			id <TCChatViewDelegate> delegate;


// -- Instance --
+ (TCChatView *)chatViewWithIdentifier:(NSString *)identifier name:(NSString *)name delegate:(id <TCChatViewDelegate>)delegate;

// -- IBAction --
- (IBAction)textAction:(id)sender;

// -- Content --
- (void)receiveMessage:(NSString *)message;
- (void)receiveError:(NSString *)error;
- (void)receiveStatus:(NSString *)status;

- (void)setLocalAvatar:(NSImage *)image;
- (void)setRemoteAvatar:(NSImage *)image;

@end
