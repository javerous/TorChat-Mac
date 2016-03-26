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

@import SMFoundation;

#import "TCChatViewController.h"

#import "TCChatTranscriptViewController.h"

#import "TCThreePartImageView.h"

#import "TCChatMessage.h"

#import "TCImage.h"
#import "TCBuddy.h"


/*
** TCChatViewController - Private
*/
#pragma mark - TCChatViewController - Private

@interface TCChatViewController () <TCBuddyObserver>
{
	id <TCConfigApp> _configuration;

	TCChatTranscriptViewController	*_chatTranscript;
	NSMutableDictionary				*_erroredMessages;
	
	BOOL _isFetchingTranscript;
	BOOL _pendingFetchTranscript;
	
	int64_t		_transcriptTopMsgID;
	int64_t		_tmpMsgID;
}

// -- Properties --
@property (strong, nonatomic) IBOutlet NSView				*transcriptView;
@property (strong, nonatomic) IBOutlet NSTextField			*userField;
@property (strong, nonatomic) IBOutlet NSBox				*lineView;
@property (strong, nonatomic) IBOutlet TCThreePartImageView	*backView;

@property (strong, nonatomic) NSString *name;

@property (weak, nonatomic) TCBuddy *buddy;

// -- IBAction --
- (IBAction)textAction:(id)sender;

@end



/*
** TCChatViewController
*/
#pragma mark - TCChatViewController

@implementation TCChatViewController


/*
** TCChatViewController - Instance
*/
#pragma mark - TCChatViewController - Instance

+ (TCChatViewController *)chatViewWithBuddy:(TCBuddy *)buddy configuration:(id <TCConfigApp>)config
{
	return [[TCChatViewController alloc] initWithBuddy:buddy configuration:config];
}

- (id)initWithBuddy:(TCBuddy *)buddy configuration:(id <TCConfigApp>)config
{
	self = [super initWithNibName:@"ChatView" bundle:nil];

	if (self)
	{
		// Hold parameters.
		_buddy = buddy;
		_configuration = config;
		
		// Init IDs.
		_transcriptTopMsgID = [_configuration transcriptLastMessageIDForBuddyIdentifier:buddy.identifier];
		_tmpMsgID = -2;
		
		// Create trasncript controller.
		_chatTranscript = [[TCChatTranscriptViewController alloc] init];
		
		// Containers.
		_erroredMessages = [[NSMutableDictionary alloc] init];
		
		// Observe buddy change.
		[buddy addObserver:self];
	}

	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCChatViewController dealloc");
}



/*
** TCChatViewController - NSViewController
*/
#pragma mark - TCChatViewController - NSViewController

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
	
	[_transcriptView setNeedsLayout:YES];
	
	// Set remote avatar.
	NSImage *remoteAvatar = [[_buddy profileAvatar] imageRepresentation];
	
	if (remoteAvatar)
		[_chatTranscript setRemoteAvatar:remoteAvatar];
	
	// Configure back.
	_backView.startCap = [NSImage imageNamed:@"back_send_field"];
	_backView.centerFill = [NSImage imageNamed:@"back_send_field"];
	_backView.endCap = [NSImage imageNamed:@"back_send_field"];
	
	// Handle error action.
	__weak TCChatViewController	*weakSelf = self;
	__weak NSMutableDictionary	*weakErroredMessages = _erroredMessages;
	
	_chatTranscript.errorActionHandler = ^(TCChatTranscriptViewController *controller, int64_t messageID) {

		dispatch_async(dispatch_get_main_queue(), ^{
			
			// > Get ref to controller.
			TCChatViewController	*strongSelf = weakSelf;
			NSMutableDictionary		*strongErroredMessages = weakErroredMessages;
			
			if (!strongSelf || !strongErroredMessages)
				return;

			// > Get original message.
			TCChatMessage *erroredMessage = strongErroredMessages[@(messageID)];
			
			if (!erroredMessage)
				return;
			
			// > Show alert.
			NSString	*message = erroredMessage.message;
			NSString	*error = NSLocalizedString(erroredMessage.error, @"");
			NSAlert		*alert = [[NSAlert alloc] init];
			
			alert.messageText = NSLocalizedString(@"chat_error_send_title", @"");
			alert.informativeText = NSLocalizedString(error, @"");
			
			[alert addButtonWithTitle:NSLocalizedString(@"chat_send_resend", @"")];
			[alert addButtonWithTitle:NSLocalizedString(@"chat_send_cancel", @"")];

			[alert beginSheetModalForWindow:strongSelf.view.window completionHandler:^(NSModalResponse returnCode) {
				if (returnCode == NSAlertFirstButtonReturn)
				{
					// > Remove message.
					[strongErroredMessages removeObjectForKey:@(messageID)];
					[strongSelf->_configuration transcriptRemoveMessageForID:messageID];
					[controller removeMessageID:messageID];

					// > Resent message.
					[strongSelf sendMessage:message];
				}
			}];
		});
	};
	
	_chatTranscript.transcriptScrollHandler = ^(TCChatTranscriptViewController *controller, CGFloat scrollOffset) {
		[weakSelf _fetchTranscript];
	};
}

- (void)viewDidLayout
{
	[self _fetchTranscript];
}

- (void)_fetchTranscript
{
	// > main queue <
	
	if (_transcriptTopMsgID == -1)
		return;
	
	// Handle requests.
	if (_isFetchingTranscript)
	{
		_pendingFetchTranscript = YES;
		return;
	}
	
	// Check if we need to fetch messages.
	NSUInteger currentMsgCount = [_chatTranscript messagesCount];
	NSUInteger fillMsgCount = [_chatTranscript messagesCountToFillHeight:_transcriptView.frame.size.height];
	NSUInteger fetchLimit = 0;
	
	fillMsgCount += 5;
	
	if (currentMsgCount < fillMsgCount)
	{
		fetchLimit = (fillMsgCount - currentMsgCount);
		fetchLimit += 5;
	}
	else
	{
		CGFloat scrollOffset = _chatTranscript.scrollOffset;
		
		if (scrollOffset >= [_chatTranscript heightForMessagesCount:5])
			return;
		
		fetchLimit = 10;
	}
	
	_isFetchingTranscript = YES;

	// Fetch messages.
	[_configuration transcriptMessagesForBuddyIdentifier:_buddy.identifier beforeMessageID:@(_transcriptTopMsgID + 1) limit:fetchLimit completionHandler:^(NSArray *messages) {
		
		if (messages.count == 0)
		{
			_transcriptTopMsgID = -1;
			return;
		}
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			// > Handle messages.
			for (TCChatMessage *msg in messages)
			{
				if (msg.messageID < _transcriptTopMsgID)
					_transcriptTopMsgID = msg.messageID;
				
				if (msg.error)
					_erroredMessages[@(msg.messageID)] = msg;
			}
			
			// > Unset fetching lock.
			_isFetchingTranscript = NO;
			
			// > Re-fetch if pending.
			if (_pendingFetchTranscript)
			{
				_pendingFetchTranscript = NO;
				[self _fetchTranscript];
			}
		});
		
		// > Add to transcript view.
		[_chatTranscript addMessages:messages endOfTranscript:NO];
	}];
}



/*
** TCChatViewController - IBAction
*/
#pragma mark - TCChatViewController - IBAction

- (IBAction)textAction:(id)sender
{
	NSString *message = _userField.stringValue;

	_userField.stringValue = @"";

	[self sendMessage:message];
}



/*
** TCChatViewController - Content
*/
#pragma mark - TCChatViewController - Content

- (void)sendMessage:(NSString *)message
{
	// Create local message.
	TCChatMessage *msg = [[TCChatMessage alloc] init];

	msg.message = message;
	msg.timestamp = [NSDate timeIntervalSinceReferenceDate];
	msg.side = TCChatMessageSideLocal;
	
	// Send message.
	TCChatTranscriptViewController	*chatTranscript = _chatTranscript;
	TCBuddy							*buddy = _buddy;
	
	[buddy sendMessage:message completionHanndler:^(SMInfo *info) {
		
		// Set send error.
		if (info.kind == SMInfoError)
		{
			if (info.code == TCBuddyErrorMessageOffline)
				msg.error = @"chat_error_send_offline";
			else if (info.code == TCBuddyErrorMessageBlocked)
				msg.error = @"chat_error_send_blocked";
		}
		
		// Handle send result.
		if (_configuration.saveTranscript)
		{
			[_configuration addTranscriptForBuddyIdentifier:buddy.identifier message:msg completionHandler:^(int64_t msgID) {
				msg.messageID = msgID;
				[chatTranscript addMessages:@[ msg ] endOfTranscript:YES];
			}];
		}
		else
		{
			int64_t msgID = OSAtomicDecrement64(&_tmpMsgID);
			
			msg.messageID = msgID;
			
			[chatTranscript addMessages:@[ msg ] endOfTranscript:YES];
		}
	}];
}

- (void)setLocalAvatar:(NSImage *)image
{
	[_chatTranscript setLocalAvatar:image];
}

- (NSUInteger)messagesCount
{
	return [_chatTranscript messagesCount];
}



/*
** TCChatViewController - Focus
*/
#pragma mark - TCChatViewController - Focus

- (void)makeFirstResponder
{
	[self.view.window makeFirstResponder:_userField];
}



/*
** TCChatViewController - TCBuddyObserver
*/
#pragma mark - TCChatViewController - TCBuddyObserver

- (void)buddy:(TCBuddy *)buddy information:(SMInfo *)info
{
	if (info.kind == SMInfoInfo)
	{
		switch (info.code)
		{
			case TCBuddyEventProfileAvatar:
			{
				TCImage *tcAvatar = (TCImage *)info.context;
				NSImage *avatar = [tcAvatar imageRepresentation];
				
				if (!avatar)
					return;
				
				[_chatTranscript setRemoteAvatar:avatar];

				break;
			}
				
			case TCBuddyEventStatus:
			{
				TCStatus	status = (TCStatus)[(NSNumber *)info.context intValue];
				NSString	*statusStr = @"";
				
				// Render status.
				switch (status)
				{
					case TCStatusOffline:
						statusStr = NSLocalizedString(@"bd_status_offline", @"");
						break;
						
					case TCStatusAvailable:
						statusStr = NSLocalizedString(@"bd_status_available", @"");
						break;
						
					case TCStatusAway:
						statusStr = NSLocalizedString(@"bd_status_away", @"");
						break;
						
					case TCStatusXA:
						statusStr = NSLocalizedString(@"bd_status_xa", @"");
						break;
				}
				
				// Show status change.
				[_chatTranscript appendStatus:statusStr];
				
				break;
			}
		
			case TCBuddyEventMessage:
			{
				NSArray *messages = [buddy popMessages];
				
				// Save messages.
				if (_configuration.saveTranscript)
				{
					NSMutableArray *outMessages = [[NSMutableArray alloc] init];

					void (^handleMessage)(id sblock, NSUInteger index) = ^(id sblock, NSUInteger index) {
					
						void (^sHandleMessage)(id sblock, NSUInteger index) = sblock;
						
						if (index >= messages.count)
						{
							[_chatTranscript addMessages:outMessages endOfTranscript:YES];
						}
						else
						{
							TCChatMessage *msg = [[TCChatMessage alloc] init];
							
							msg.message = messages[index];
							msg.side = TCChatMessageSideRemote;
							msg.timestamp = [NSDate timeIntervalSinceReferenceDate];
							
							[_configuration addTranscriptForBuddyIdentifier:buddy.identifier message:msg completionHandler:^(int64_t msgID) {
								msg.messageID = msgID;
								[outMessages addObject:msg];
								sHandleMessage(sHandleMessage, index + 1);
							}];
						}
					};
					
					// Convert & save messages.
					handleMessage(handleMessage, 0);
				}
				else
				{
					NSMutableArray *outMessages = [[NSMutableArray alloc] init];

					for (NSString *message in messages)
					{
						TCChatMessage *msg = [[TCChatMessage alloc] init];

						msg.message = message;
						msg.side = TCChatMessageSideRemote;
						msg.timestamp = [NSDate timeIntervalSinceReferenceDate];
						msg.messageID = OSAtomicDecrement64(&_tmpMsgID);
						
						[outMessages addObject:msg];
					}
					
					[_chatTranscript addMessages:outMessages endOfTranscript:YES];
				}
				
				break;
			}
		}
	}
}

@end
