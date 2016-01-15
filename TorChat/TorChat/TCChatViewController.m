/*
 *  TCChatViewController.m
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

#import "TCChatViewController.h"

#import "TCChatTranscriptViewController.h"

#import "TCThreePartImageView.h"


/*
** TCChatViewController - Private
*/
#pragma mark - TCChatViewController - Private

@interface TCChatViewController ()
{
	TCChatTranscriptViewController	*_chatTranscript;
}

// -- Properties --
@property (strong, nonatomic) IBOutlet NSView				*transcriptView;
@property (strong, nonatomic) IBOutlet NSTextField			*userField;
@property (strong, nonatomic) IBOutlet NSBox				*lineView;
@property (strong, nonatomic) IBOutlet TCThreePartImageView	*backView;

@property (strong, nonatomic) NSString *bidentifier;

// -- IBAction --
- (IBAction)textAction:(id)sender;

@end



/*
** TCChatViewController
*/
#pragma mark - TCChatViewController

@implementation TCChatViewController


/*
** TCChatViewController - Property
*/
#pragma mark - TCChatViewController - Property


/*
** TCChatViewController - Instance
*/
#pragma mark - TCChatViewController - Instance

+ (TCChatViewController *)chatViewWithIdentifier:(NSString *)identifier name:(NSString *)name delegate:(id <TCChatViewDelegate>)delegate
{
	TCChatViewController *result = [[TCChatViewController alloc] init];
	
	result.name = name;
	result.bidentifier = identifier;
	result.delegate = delegate;

	return result;
}

- (id)init
{
	self = [super initWithNibName:@"ChatView" bundle:nil];

	if (self)
	{
		// Create trasncript controller.
		_chatTranscript = [[TCChatTranscriptViewController alloc] init];
	}

	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



/*
** TCChatView - NSViewController
*/
#pragma mark - TCChatView - NSViewController

- (void)loadView
{
	[super loadView];
	
	// Include transcript view.
	NSDictionary	*viewsDictionary;
	NSView			*view = _chatTranscript.view;
	
	[_transcriptView addSubview:view];
	
	viewsDictionary = NSDictionaryOfVariableBindings(view);
	
	[_transcriptView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:viewsDictionary]];
	[_transcriptView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:viewsDictionary]];

	// Configure back.
	_backView.startCap = [NSImage imageNamed:@"back_send_field"];
	_backView.centerFill = [NSImage imageNamed:@"back_send_field"];
	_backView.endCap = [NSImage imageNamed:@"back_send_field"];
}



/*
** TCChatViewController - IBAction
*/
#pragma mark - TCChatViewController - IBAction

- (IBAction)textAction:(id)sender
{
	[_chatTranscript appendLocalMessage:[_userField stringValue]];
		
	id <TCChatViewDelegate> delegate = _delegate;
	
	[delegate chat:self sendMessage:[_userField stringValue]];
	
	[_userField setStringValue:@""];
}



/*
** TCChatView - Content
*/
#pragma mark - TCChatView - Content

- (void)receiveMessage:(NSString *)message
{
	[_chatTranscript appendRemoteMessage:message];
}

- (void)receiveError:(NSString *)error
{
	[_chatTranscript appendError:error];
}

- (void)receiveStatus:(NSString *)status
{
	[_chatTranscript appendStatus:status];
}

- (void)setLocalAvatar:(NSImage *)image
{
	[_chatTranscript setLocalAvatar:image];
}

- (void)setRemoteAvatar:(NSImage *)image
{
	[_chatTranscript setRemoteAvatar:image];
}

- (NSUInteger)messagesCount
{
	return [_chatTranscript messagesCount];
}



/*
** TCChatView - Focus
*/
#pragma mark - TCChatView - Focus

- (void)makeFirstResponder
{
	[self.view.window makeFirstResponder:_userField];
}

@end
