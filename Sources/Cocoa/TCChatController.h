/*
 *  TCChatController.h
 *
 *  Copyright 2011 Avérous Julien-Pierre
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
#pragma mark -
#pragma mark Forward

@class TCCocoaBuddy;
@class TCChatController;
@class TCChatView;



/*
** TCChatController - Delegate
*/
#pragma mark -
#pragma mark TCChatController - Delegate

@protocol TCChatControllerDelegate <NSObject>

- (void)chat:(TCChatController *)chat sendMessage:(NSString *)message;

@end



/*
** TCChatController
*/
#pragma mark -
#pragma mark TCChatController

@interface TCChatController : NSWindowController
{
	IBOutlet NSTextField	*userField;
	IBOutlet TCChatView		*chatView;
	
@private
	id <TCChatControllerDelegate>	delegate;
	NSString						*name;
	
	NSRect							baseRect;
}

// -- Property --
@property (assign, nonatomic) id <TCChatControllerDelegate>		delegate;
@property (retain, nonatomic) NSString							*name;

// -- Constructor --
+ (TCChatController *)chatWithName:(NSString *)name onDelegate:(id <TCChatControllerDelegate>)delegate;

// -- IBAction --
- (IBAction)textAction:(id)sender;

// -- Action --
- (void)openWindow;

// -- Content --
- (void)receiveMessage:(NSString *)message;
- (void)receiveError:(NSString *)error;
- (void)receiveStatus:(NSString *)status;

- (void)setLocalAvatar:(NSImage *)image;
- (void)setRemoteAvatar:(NSImage *)image;

@end
