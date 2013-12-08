/*
 *  TCChatController.h
 *
 *  Copyright 2013 Avérous Julien-Pierre
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


/*
** Forward
*/
#pragma mark - Forward

@class TCChatController;



/*
** TCChatController - Delegate
*/
#pragma mark - TCChatController - Delegate

@protocol TCChatControllerDelegate <NSObject>

- (void)chatSendMessage:(NSString *)message identifier:(NSString *)identifier context:(id)context;

@end



/*
** TCChatController
*/
#pragma mark - TCChatController

@interface TCChatController : NSWindowController

// -- Constructor --
+ (TCChatController *)sharedController;

// -- Chat --
- (void)startChatWithIdentifier:(NSString *)identifier name:(NSString *)name localAvatar:(NSImage *)lavatar remoteAvatar:(NSImage *)ravatar context:(id)context delegate:(id <TCChatControllerDelegate>)delegate;
- (void)selectChatWithIdentifier:(NSString *)identifier;
- (void)stopChatWithIdentifier:(NSString *)identifier;

// -- Content --
- (void)receiveMessage:(NSString *)message forIdentifier:(NSString *)identifier;
- (void)receiveError:(NSString *)error forIdentifier:(NSString *)identifier;
- (void)receiveStatus:(NSString *)status forIdentifier:(NSString *)identifier;

- (void)setLocalAvatar:(NSImage *)image forIdentifier:(NSString *)identifier;
- (void)setRemoteAvatar:(NSImage *)image forIdentifier:(NSString *)identifier;

@end
