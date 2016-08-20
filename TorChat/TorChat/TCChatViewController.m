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

#import <SMFoundation/SMFoundation.h>

#import "TCChatViewController.h"

#import "TCChatTranscriptViewController.h"

#import "TCThemesManager.h"

#import "TCThreePartImageView.h"

#import "TCChatMessage.h"
#import "TCChatStatus.h"

#import "TCImage.h"
#import "TCBuddy.h"


NS_ASSUME_NONNULL_BEGIN


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
	
	int64_t		_topFetchedMsgID;
	int64_t		_transcriptFirstMsgID;
	int64_t		_transcriptLastMsgID;
	int64_t		_tmpMsgID;
	
	NSDateFormatter *_timestampFormater;
	
	NSNumber	*_topMessageTimestamp;
	NSNumber	*_bottomMessageTimestamp;
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

- (instancetype)initWithBuddy:(TCBuddy *)buddy configuration:(id <TCConfigApp>)config
{
	self = [super initWithNibName:@"ChatView" bundle:nil];

	if (self)
	{
		// Hold parameters.
		_buddy = buddy;
		_configuration = config;
		
		// Init date formatter.
		_timestampFormater = [[NSDateFormatter alloc] init];
		
		_timestampFormater.dateStyle = NSDateFormatterMediumStyle;
		_timestampFormater.timeStyle = NSDateFormatterMediumStyle;
		
		// Get theme to use.
		TCTheme *theme = [[TCThemesManager sharedManager] themeForIdentifier:config.themeIdentifier];
		
		if (!theme)
		{
			NSArray *themes = [[TCThemesManager sharedManager] themes];
			
			theme = [themes firstObject];
		}
		
		// Create trasncript controller.
		_chatTranscript = [[TCChatTranscriptViewController alloc] initWithTheme:theme];
		
		// Containers.
		_erroredMessages = [[NSMutableDictionary alloc] init];
		
		// Init IDs.
		_topFetchedMsgID = -1;
		
		if ([_configuration transcriptMessagesIDBoundariesForBuddyIdentifier:buddy.identifier firstMessageID:&_transcriptFirstMsgID lastMessageID:&_transcriptLastMsgID] == NO)
		{
			NSString *timestampString = [_timestampFormater stringFromDate:[NSDate date]];
			
			[_chatTranscript addItems:@[ [[TCChatStatus alloc] initWithStatus:timestampString] ] endOfTranscript:NO];
			
			_transcriptFirstMsgID = -1;
			_transcriptLastMsgID = -1;
		}
		
		_tmpMsgID = -2;
		
		// Observe buddy change.
		[buddy addObserver:self];
		
		// Add pending messages.
		[self handleRemoteMessages:[buddy popMessages]];
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
	_backView.startCap = (NSImage *)[NSImage imageNamed:@"back_send_field"];
	_backView.centerFill = (NSImage *)[NSImage imageNamed:@"back_send_field"];
	_backView.endCap = (NSImage *)[NSImage imageNamed:@"back_send_field"];
	
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

			[alert beginSheetModalForWindow:(NSWindow *)strongSelf.view.window completionHandler:^(NSModalResponse returnCode) {
				if (returnCode == NSAlertFirstButtonReturn)
				{
					// > Remove message.
					[strongErroredMessages removeObjectForKey:@(messageID)];
					[strongSelf->_configuration transcriptRemoveMessageForID:messageID];
					[controller removeMessageID:messageID];

					// > Resent message.
					[strongSelf handleLocalMessage:message];
				}
			}];
		});
	};
	
	_chatTranscript.transcriptScrollHandler = ^(TCChatTranscriptViewController *controller, CGFloat scrollOffset) {
		[weakSelf _fetchSavedTranscript];
	};
}

- (void)viewDidLayout
{
	[self _fetchSavedTranscript];
}

- (void)makeFirstResponder
{
	[self.view.window makeFirstResponder:_userField];
}



/*
** TCChatViewController - IBAction
*/
#pragma mark - TCChatViewController - IBAction

- (IBAction)textAction:(id)sender
{
	NSString *message = _userField.stringValue;

	_userField.stringValue = @"";

	[self handleLocalMessage:message];
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
				TCStatus		status = (TCStatus)[(NSNumber *)info.context intValue];
				TCChatStatus	*chatStatus = [[TCChatStatus alloc] initWithStatus:@""];
				
				// Render status.
				switch (status)
				{
					case TCStatusOffline:
						chatStatus.status = NSLocalizedString(@"bd_status_offline", @"");
						break;
						
					case TCStatusAvailable:
						chatStatus.status = NSLocalizedString(@"bd_status_available", @"");
						break;
						
					case TCStatusAway:
						chatStatus.status = NSLocalizedString(@"bd_status_away", @"");
						break;
						
					case TCStatusXA:
						chatStatus.status = NSLocalizedString(@"bd_status_xa", @"");
						break;
				}
				
				// Show status change.
				[_chatTranscript addItems:@[ chatStatus ] endOfTranscript:YES];
				
				break;
			}
				
			case TCBuddyEventMessage:
			{
				[self handleRemoteMessages:[buddy popMessages]];
				break;
			}
		}
	}
}



/*
** TCChatViewController - Content
*/
#pragma mark - TCChatViewController - Content

- (void)setLocalAvatar:(NSImage *)image
{
	[_chatTranscript setLocalAvatar:image];
}

- (NSUInteger)messagesCount
{
	return [_chatTranscript messagesCount];
}



/*
** TCChatViewController - Helpers
*/
#pragma mark - TCChatViewController - Helpers

- (void)handleLocalMessage:(NSString *)message
{
	TCBuddy *buddy = _buddy;
	
	if (!buddy)
		return;
	
	// Create local message.
	TCChatMessage *msg = [[TCChatMessage alloc] init];

	msg.message = message;
	msg.timestamp = [NSDate timeIntervalSinceReferenceDate];
	msg.side = TCChatMessageSideLocal;
	
	// Send message.
	[buddy sendMessage:message completionHanndler:^(SMInfo *info) {
		
		// Set send error.
		if (info.kind == SMInfoError)
		{
			if (info.code == TCBuddyErrorMessageOffline)
				msg.error = @"chat_error_send_offline";
			else if (info.code == TCBuddyErrorMessageBlocked)
				msg.error = @"chat_error_send_blocked";
		}
		
		// Snippet to handle message.
		void (^handleMessageWithID)(int64_t msgID) = ^(int64_t msgID) {
			
			msg.messageID = msgID;
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				[self _handleMessages:@[ msg ] endOfTranscript:YES];
				
				if (msg.error)
					_erroredMessages[@(msgID)] = msg;
			});
		};
		
		// Handle message.
		if (_configuration.saveTranscript)
			[_configuration addTranscriptForBuddyIdentifier:buddy.identifier message:msg completionHandler:handleMessageWithID];
		else
			handleMessageWithID(OSAtomicDecrement64(&_tmpMsgID));
	}];
}

- (void)handleRemoteMessages:(NSArray *)messages
{
	TCBuddy *buddy = _buddy;
	
	if (!buddy || messages.count == 0)
		return;
	
	// Save messages.
	if (_configuration.saveTranscript)
	{
		dispatch_group_t	group = dispatch_group_create();
		NSMutableArray		*outMessages = [[NSMutableArray alloc] init];
		
		for (NSString *message in messages)
		{
			TCChatMessage *msg = [[TCChatMessage alloc] init];
			
			msg.message = message;
			msg.side = TCChatMessageSideRemote;
			msg.timestamp = [NSDate timeIntervalSinceReferenceDate];
			
			[outMessages addObject:msg];

			dispatch_group_enter(group);
			
			[_configuration addTranscriptForBuddyIdentifier:buddy.identifier message:msg completionHandler:^(int64_t msgID) {
				msg.messageID = msgID;
				dispatch_group_leave(group);
			}];
		}
		
		dispatch_group_notify(group, dispatch_get_main_queue(), ^{
			[self _handleMessages:outMessages endOfTranscript:YES];
		});
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
		
		dispatch_async(dispatch_get_main_queue(), ^{
			[self _handleMessages:outMessages endOfTranscript:YES];
		});
	}
}

- (void)_handleMessages:(NSArray *)messages endOfTranscript:(BOOL)endOfTranscript
{
	// > main queue <
	
#define TCMessageDeltaTimestamp (15.0 * 60.0) // 15 minutes
	
	if (messages.count == 0)
		return;
	
	NSMutableArray *result = [[NSMutableArray alloc] init];
	
	// > Snippet to add timestamp.
	void (^insertTimestamp)(NSTimeInterval timestamp, NSUInteger index) = ^(NSTimeInterval timestamp, NSUInteger index) {
		
		NSDate			*date = [NSDate dateWithTimeIntervalSinceReferenceDate:timestamp];
		TCChatStatus	*status = [[TCChatStatus alloc] initWithStatus:[_timestampFormater stringFromDate:date]];
		
		if (index == NSNotFound)
			[result addObject:status];
		else
			[result insertObject:status atIndex:index];
	};
	
	
	// > List messages.
	__block NSNumber *lastTimestamp = nil;
	
	[messages enumerateObjectsUsingBlock:^(TCChatMessage * _Nonnull msg, NSUInteger idx, BOOL * _Nonnull stop) {
		
		// >> Add timestamp if necessary.
		if (lastTimestamp)
		{
			if (msg.timestamp - [lastTimestamp doubleValue] >= TCMessageDeltaTimestamp)
				insertTimestamp(msg.timestamp, NSNotFound);
		}
		
		lastTimestamp = @(msg.timestamp);
		
		// >> Add message.
		[result addObject:msg];
	}];
	
	// > Handle top & bottom join timestamp.
	TCChatMessage *firstMsg = [messages firstObject];
	TCChatMessage *lastMsg = [messages lastObject];
	
	if (endOfTranscript == YES)
	{
		if (_bottomMessageTimestamp)
		{
			if (firstMsg.timestamp - [_bottomMessageTimestamp doubleValue] >= TCMessageDeltaTimestamp)
				insertTimestamp(firstMsg.timestamp, 0);
		}
		
		_bottomMessageTimestamp = @(lastMsg.timestamp);
		
		if (!_topMessageTimestamp)
			_topMessageTimestamp = @(firstMsg.timestamp);
	}
	else
	{
		if (_topMessageTimestamp)
		{
			if ([_topMessageTimestamp doubleValue] - lastMsg.timestamp >= TCMessageDeltaTimestamp)
				insertTimestamp([_topMessageTimestamp doubleValue], NSNotFound);
		}
		
		_topMessageTimestamp = @(firstMsg.timestamp);
		
		if (!_bottomMessageTimestamp)
			_bottomMessageTimestamp = @(lastMsg.timestamp);
	}
	
	
	// Show messages & timestamp.
	[_chatTranscript addItems:result endOfTranscript:endOfTranscript];
}

- (void)_fetchSavedTranscript
{
	// > main queue <
	
	TCBuddy *buddy = _buddy;
	
	if (!buddy)
		return;
	
	// Check IDs.
	if (_topFetchedMsgID == -1)
		_topFetchedMsgID = _transcriptLastMsgID + 1;

	if (_topFetchedMsgID <= _transcriptFirstMsgID)
		return;
	
	// Handle requests.
	if (_isFetchingTranscript)
	{
		_pendingFetchTranscript = YES;
		return;
	}
	
	// Check if we need to fetch messages.
	NSUInteger currentMsgCount = [_chatTranscript messagesCount];
	NSUInteger fillMsgCount = [_chatTranscript maxMessagesCountToFillHeight:_transcriptView.frame.size.height];
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
		
		if (scrollOffset >= [_chatTranscript maxHeightForMessagesCount:5])
			return;
		
		fetchLimit = 10;
	}
	
	_isFetchingTranscript = YES;
	
	// Fetch messages.
	[_configuration transcriptMessagesForBuddyIdentifier:buddy.identifier beforeMessageID:@(_topFetchedMsgID) limit:fetchLimit completionHandler:^(NSArray * _Nullable messages) {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			// > Unset fetching lock.
			_isFetchingTranscript = NO;

			if (messages.count == 0)
				return;
			
			// > Handle top message.
			TCChatMessage *topMsg = [messages firstObject];
			
			_topFetchedMsgID = topMsg.messageID;

			
			// > Handle errors.
			for (TCChatMessage *msg in messages)
			{
				if (msg.error)
					_erroredMessages[@(msg.messageID)] = msg;
			}
			
			// > Add messages transcript view.
			[self _handleMessages:(NSArray *)messages endOfTranscript:NO];
			
			// > Add top timetamp.
			if (_topFetchedMsgID <= _transcriptFirstMsgID)
			{
				NSDate		*timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:topMsg.timestamp];
				NSString	*timestampString = [_timestampFormater stringFromDate:timestamp];
				
				[_chatTranscript addItems:@[ [[TCChatStatus alloc] initWithStatus:timestampString] ] endOfTranscript:NO];
			}
			
			// > Re-fetch if pending.
			if (_pendingFetchTranscript)
			{
				_pendingFetchTranscript = NO;
				[self _fetchSavedTranscript];
			}
		});
	}];
}

@end


NS_ASSUME_NONNULL_END
