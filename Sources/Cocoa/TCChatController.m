/*
 *  TCChatController.m
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#import "TCChatController.h"

#import "TCChatView.h"
#import "TCStringExtension.h"



/*
** TCChatController - Private
*/
#pragma mark -
#pragma mark TCChatController - Private

@interface TCChatController ()
	- (void)_resizeUserField;
@end



/*
** TCChatController
*/
#pragma mark -
#pragma mark TCChatController

@implementation TCChatController


/*
** TCChatController - Property
*/
#pragma mark -
#pragma mark TCChatController - Property

@synthesize delegate;
@synthesize name;



/*
** TCChatController - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCChatController - Constructor & Destructor

+ (TCChatController *)chatWithName:(NSString *)name onDelegate:(id <TCChatControllerDelegate>)delegate;
{
	TCChatController *result = [[[TCChatController alloc] initWithWindowNibName:@"Chat"] autorelease];
	
	result.delegate = delegate;
	result.name = name;

	[[result window] setTitle:[NSString stringWithFormat:NSLocalizedString(@"chat_title", @""), name]];
	
	return result;
}

- (id)initWithWindow:(NSWindow *)window
{	
    if ((self = [super initWithWindow:window]))
	{
		[window center];
    }
    
    return self;
}

- (void)dealloc
{
	[name release];
    
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	baseRect = [userField frame];
	
	[self.window center];
	[self setWindowFrameAutosaveName:@"ChatWindow"];
}



/*
** TCChatController - IBAction
*/
#pragma mark -
#pragma mark TCChatController - IBAction

- (IBAction)textAction:(id)sender
{
	[chatView appendToConversation:[userField stringValue] fromUser:tcchat_local];
	[delegate chat:self sendMessage:[userField stringValue]];
	
	[userField setStringValue:@""];
	[self _resizeUserField];
}



/*
** TCChatController - Action
*/
#pragma mark -
#pragma mark TCChatController - Action

- (void)openWindow
{
	[self showWindow:self];
}



/*
** TCChatController - Content
*/
#pragma mark -
#pragma mark TCChatController - Content

- (void)receiveMessage:(NSString *)message
{
	[self showWindow:self];
	
	[chatView appendToConversation:message fromUser:tcchat_remote];
}

- (void)receiveError:(NSString *)error
{
	[chatView addErrorMessage:error];
	
}

- (void)receiveStatus:(NSString *)status
{
	[chatView addStatusMessage:status fromUserName:self.name];
}



/*
** TCChatController - Tools
*/
#pragma mark -
#pragma mark TCChatController - Tools

- (void)_resizeUserField
{
	NSString	*text = [userField stringValue];
	
	if ([text length] == 0)
		text = @" ";
	
	NSRect		r = [userField frame];
	NSFont		*font = [userField font];
	float		height = [text heightForDrawingWithFont:font andWidth:(r.size.width - 8)];
	float		lheight = [@" " heightForDrawingWithFont:font andWidth:100];

	height += (baseRect.size.height - lheight);

	if (height != r.size.height)
	{
		NSRect rChat = [chatView frame];
			
		rChat.origin.y += (height - r.size.height);
		rChat.size.height -= (height - r.size.height);
		
		if (rChat.size.height < 150)
			return;
			
		[chatView setFrame:rChat];
		
		r.size.height = height;
		
		[userField setFrame:r];
	}
}



/*
** TCChatController - Events
*/
#pragma mark -
#pragma mark TCChatController - Events

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self _resizeUserField];
}


- (void)windowDidResize:(NSNotification *)notification
{
	[self _resizeUserField];
}

@end
