/*
 *  TCChatView.m
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



#import "TCChatView.h"

#import "TCChatTalk.h"
#import "NSString+TCExtension.h"



/*
** TCChatView - Private
*/
#pragma mark - TCChatView - Private

@interface TCChatView () <NSTextFieldDelegate>
{
}

// -- Property --
@property (strong, nonatomic) NSString *identifier;

@end



/*
** TCChatView
*/
#pragma mark - TCChatView

@implementation TCChatView


/*
** TCChatView - Property
*/
#pragma mark - TCChatView - Property


/*
** TCChatView - Instance
*/
#pragma mark - TCChatView - Instance

+ (TCChatView *)chatViewWithIdentifier:(NSString *)identifier name:(NSString *)name delegate:(id <TCChatViewDelegate>)delegate
{
	TCChatView *result = [[TCChatView alloc] init];
	
	result.name = name;
	result.identifier = identifier;
	result.delegate = delegate;

	return result;
}

- (id)init
{
	self = [super init];

	if (self)
	{
		// Load bundle
		[[NSBundle mainBundle] loadNibNamed:@"ChatView" owner:self topLevelObjects:nil];
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



/*
** TCChatView - IBAction
*/
#pragma mark - TCChatView - IBAction

- (IBAction)textAction:(id)sender
{
	[_talkView appendToConversation:[_userField stringValue] fromUser:tcchat_local];
	
	id <TCChatViewDelegate> delegate = _delegate;
	[delegate chat:self sendMessage:[_userField stringValue]];
	
	[_userField setStringValue:@""];
}



/*
** TCChatView - Content
*/
#pragma mark - TCChatView - Property

- (void)receiveMessage:(NSString *)message
{	
	[_talkView appendToConversation:message fromUser:tcchat_remote];
}

- (void)receiveError:(NSString *)error
{
	[_talkView addErrorMessage:error];
	
}

- (void)receiveStatus:(NSString *)status
{
	[_talkView addStatusMessage:status fromUserName:self.name];
}

- (void)setLocalAvatar:(NSImage *)image
{
	[_talkView setLocalAvatar:image];
}

- (void)setRemoteAvatar:(NSImage *)image
{
	[_talkView setRemoteAvatar:image];
}

@end
