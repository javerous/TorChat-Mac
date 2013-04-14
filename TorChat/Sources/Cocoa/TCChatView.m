/*
 *  TCChatView.m
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



#import "TCChatView.h"

#import "TCChatTalk.h"
#import "TCStringExtension.h"



/*
** TCChatView - Private
*/
#pragma mark - TCChatView - Private

@interface TCChatView ()
{
	NSRect	baseRect;
}

// -- Property --
@property (retain, nonatomic) NSString *identifier;

// -- Functions --
- (void)_resizeUserField;

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

@synthesize view;

@synthesize userField;
@synthesize talkView;
@synthesize lineView;
@synthesize backView;

@synthesize name;
@synthesize identifier;

@synthesize delegate;



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

	return [result autorelease];
}

- (id)init
{
	self = [super init];

	if (self)
	{
		// Load bundle
		[NSBundle loadNibNamed:@"ChatView" owner:self];
	}

	return self;
}

- (void)dealloc
{
	[name release];
	[identifier release];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (void)awakeFromNib
{
	// "Mark" field size
	baseRect = [userField frame];
	
	// Install notification
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(windowDidResize:) name:NSWindowDidResizeNotification object:view.window];
}



/*
** TCChatView - IBAction
*/
#pragma mark - TCChatView - IBAction

- (IBAction)textAction:(id)sender
{
	[talkView appendToConversation:[userField stringValue] fromUser:tcchat_local];
	[self.delegate chat:self sendMessage:[userField stringValue]];
	
	[userField setStringValue:@""];
	[self _resizeUserField];
}


/*
** TCChatView - Content
*/
#pragma mark - TCChatView - Property

- (void)receiveMessage:(NSString *)message
{	
	[talkView appendToConversation:message fromUser:tcchat_remote];
}

- (void)receiveError:(NSString *)error
{
	[talkView addErrorMessage:error];
	
}

- (void)receiveStatus:(NSString *)status
{
	[talkView addStatusMessage:status fromUserName:self.name];
}

- (void)setLocalAvatar:(NSImage *)image
{
	[talkView setLocalAvatar:image];
}

- (void)setRemoteAvatar:(NSImage *)image
{
	[talkView setRemoteAvatar:image];
}



/*
** TCChatView - Events
*/
#pragma mark - TCChatView - Events

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self _resizeUserField];
}


- (void)windowDidResize:(NSNotification *)notification
{
	[self _resizeUserField];
}



/*
** TCChatView - Tools
*/
#pragma mark - TCChatView - Tools

- (void)_resizeUserField
{
	NSString *text = [userField stringValue];

	if ([text length] == 0)
		text = @" ";

	NSRect	r = [userField frame];
	NSFont	*font = [userField font];
	CGFloat	height = [text heightForDrawingWithFont:font andWidth:(r.size.width - 8)];
	CGFloat	lheight = [@" " heightForDrawingWithFont:font andWidth:100];

	height += (baseRect.size.height - lheight);

	if (height != r.size.height)
	{
		NSRect rect;
		
		// > Update talkView size
		rect = [talkView frame];
	
		rect.origin.y += (height - r.size.height);
		rect.size.height -= (height - r.size.height);
	
		if (rect.size.height < 150)
			return;
	
		[talkView setFrame:rect];
		
		// > Update back size
		rect = [backView frame];
		
		rect.size.height += (height - r.size.height);

		[backView setFrame:rect];
	
		// > Update line position
		rect = [lineView frame];
		
		rect.origin.y += (height - r.size.height);

		[lineView setFrame:rect];

		// > Update user field size
		r.size.height = height;

		[userField setFrame:r];
	}
}

@end
