/*
 *  TCChatWindowController.m
 *
 *  Copyright 2014 Avérous Julien-Pierre
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



#import "TCChatWindowController.h"

#import "TCChatViewController.h"
#import "TCButton.h"
#import "TCValue.h"

#import "TCChatCellView.h"



/*
** Defines
*/
#pragma mark - Defines

// -- Row info --
#define TCChatViewKey		@"view"
#define TCChatDelegateKey	@"delegate"
#define TCChatContextKey	@"context"
#define TCChatAvatarKey		@"avatar"
#define TCChatNameKey		@"name"
#define TCChatLastChatKey	@"last_chat"



/*
** TCChatWindowController - Private
*/
#pragma mark - TCChatWindowController - Private

@interface TCChatWindowController () <TCChatViewDelegate>
{	
	NSMutableArray			*_identifiers;
	NSMutableDictionary		*_identifiersContent;
	
	NSString				*_selectedIdentifier;
	
	NSView					*_currentView;
}

@property (strong, nonatomic) IBOutlet NSSplitView		*splitView;
@property (strong, nonatomic) IBOutlet NSTableView		*userList;
@property (strong, nonatomic) IBOutlet NSView			*userView;
@property (strong, nonatomic) IBOutlet NSView			*chatView;

@end



/*
** TCChatWindowController
*/
#pragma mark - TCChatWindowController

@implementation TCChatWindowController


/*
** TCChatWindowController - Instance
*/
#pragma mark - TCChatWindowController - Instance

+ (TCChatWindowController *)sharedController
{
	static TCChatWindowController	*shr;
	static dispatch_once_t	onceToken;
	
	dispatch_once(&onceToken, ^{
		shr = [[TCChatWindowController alloc] init];
	});
	
	return shr;
}

- (id)init
{
	self = [super initWithWindowNibName:@"ChatWindow"];

	if (self)
	{
		// Containers
		_identifiers = [[NSMutableArray alloc] init];
		_identifiersContent = [[NSMutableDictionary alloc] init];
	}

	return self;
}



/*
** TCChatWindowController - NSWindowController
*/
#pragma mark - TCChatWindowController - NSWindowController

- (void)windowDidLoad
{
	[self.window center];
	[self setWindowFrameAutosaveName:@"ChatWindow"];
}



/*
** TCChatWindowController - IBAction
*/
#pragma mark - TCChatWindowController - IBAction

- (IBAction)closeAction:(id)sender
{
	NSInteger index = [_userList rowForView:sender];
	
	if (index < 0 || index >= [_identifiers count])
		return;

	NSString *identifier = [_identifiers objectAtIndex:(NSUInteger)index];

	// Validate the close if more than 0 message, as any close will delete the full conversation.
	TCChatViewController *view = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatViewKey];

	if ([view messagesCount] > 0)
	{
		NSAlert *alert = [NSAlert alertWithMessageText:NSLocalizedString(@"chat_want_close", @"") defaultButton:NSLocalizedString(@"chat_close", @"") alternateButton:NSLocalizedString(@"chat_cancel", @"") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"chat_want_close_info", @"")];
		
		[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
			if (returnCode == NSFileHandlingPanelOKButton)
				[[TCChatWindowController sharedController] stopChatWithIdentifier:identifier];
		}];
	}
	else
		[[TCChatWindowController sharedController] stopChatWithIdentifier:identifier];

}



/*
** TCChatWindowController - Window
*/
#pragma mark - TCChatWindowController - Window

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	NSInteger index;
	
	// Clean the selected unread messages content
	index = [_userList selectedRow];
	
	if (index >= 0 && index < [_identifiers count])
	{
		NSString			*identifier;
		NSMutableDictionary	*content;
		
		identifier = [_identifiers objectAtIndex:(NSUInteger)index];
		content = [_identifiersContent objectForKey:identifier];
		
		// Clean unread
		[content removeObjectForKey:TCChatLastChatKey];
		[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
	}
}



/*
** TCChatWindowController - Chat
*/
#pragma mark - TCChatWindowController - Chat

- (void)startChatWithIdentifier:(NSString *)identifier name:(NSString *)name localAvatar:(NSImage *)lavatar remoteAvatar:(NSImage *)ravatar context:(id)context delegate:(id <TCChatWindowControllerDelegate>)delegate
{
	if (!identifier)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSMutableDictionary		*content = [_identifiersContent objectForKey:identifier];
		TCValue					*pdelegate = nil;
		TCChatViewController	*view;
		
		// No need to start a chat if already started.
		if (content)
			return;
		
		// > Set weak delegate.
		if (delegate)
			pdelegate = [TCValue valueWithWeakObject:delegate];
		
		content = [NSMutableDictionary dictionary];
		
		if (pdelegate)
			[content setObject:pdelegate forKey:TCChatDelegateKey];
		
		// > Set context.
		if (context)
			[content setObject:context forKey:TCChatContextKey];
		
		// > Build chat view.
		view = [TCChatViewController chatViewWithIdentifier:identifier name:name delegate:self];
		
		if (!view)
			return;
		
		[content setObject:view forKey:TCChatViewKey];
		
		// > Hold name.
		if (name)
			[content setObject:name forKey:TCChatNameKey];
		
		// > Hold avatar.
		[view setLocalAvatar:lavatar];
		[view setRemoteAvatar:ravatar];
		
		if (ravatar)
			[content setObject:ravatar forKey:TCChatAvatarKey];
		
		// Add identifier.
		[_identifiersContent setObject:content forKey:identifier];
		[_identifiers addObject:identifier];
		
		// Reload table.
		[_userList reloadData];
		
		// Select this chat if it's the first one.
		if ([_identifiers count] == 1)
			[self _selectChatWithIdentifier:identifier];
		
		// Show window.
		[self showWindow:nil];
	});
}

- (void)stopChatWithIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if ([_identifiersContent objectForKey:identifier] == nil)
			return;
		
		NSUInteger index = [_identifiers indexOfObject:identifier];
		
		if (index == NSNotFound)
			return;
		
		// Remove item
		[_identifiersContent removeObjectForKey:identifier];
		[_identifiers removeObject:identifier];
		
		// Reload table
		[_userList reloadData];
		
		// Update selection
		if ([_selectedIdentifier isEqualToString:identifier])
		{
			NSUInteger nindex = index;
			
			if ([_identifiers count] == 0)
			{
				[self _loadChatView:nil];
				
				_selectedIdentifier = nil;
			}
			else
			{
				if (nindex >= [_identifiers count])
					nindex = [_identifiers count] - 1;
				
				[self _selectChatWithIdentifier:[_identifiers objectAtIndex:nindex]];
			}
		}
		else
			[self _selectChatWithIdentifier:_selectedIdentifier];
	});
}

- (void)selectChatWithIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Select the chat
		[self _selectChatWithIdentifier:identifier];
		
		// Show
		[self showWindow:self];
	});
}



/*
** TCChatWindowController - Content
*/
#pragma mark - TCChatWindowController - Content

- (void)receiveMessage:(NSString *)message forIdentifier:(NSString *)identifier
{
	if (!message)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatViewController	*view = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatViewKey];
		NSInteger				index = [_userList selectedRow];
		BOOL					setUnread = NO;
		
		if (!view)
			return;
		
		// Add message to view.
		[view receiveMessage:message];
		
		// Show window is not visible.
		if ([self.window isVisible] == NO)
			[self showWindow:nil];
		
		// Show as unread if needed.
		if (index >= 0 && index < [_identifiers count] && [[_identifiers objectAtIndex:(NSUInteger)index] isEqualToString:identifier] == NO)
		{
			setUnread = YES;
		}
		else if ([self.window isKeyWindow] == NO)
		{
			setUnread = YES;
		}
		
		if (setUnread)
		{
			NSMutableDictionary	*content = [_identifiersContent objectForKey:identifier];
			NSUInteger			cindex = [_identifiers indexOfObject:identifier];
			
			[content setObject:message forKey:TCChatLastChatKey];
			
			[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:cindex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		}
	});
}

- (void)receiveError:(NSString *)error forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatViewController *view = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatViewKey];
		
		if (!view)
			return;
		
		// Add error to view.
		[view receiveError:error];
	});
}

- (void)receiveStatus:(NSString *)status forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatViewController *view = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatViewKey];
		
		if (!view)
			return;
		
		// Add status to view.
		[view receiveStatus:status];
	});
}

- (void)setLocalAvatar:(NSImage *)image forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatViewController *view = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatViewKey];
		
		if (!view)
			return;
		
		// Update talk view.
		[view setLocalAvatar:image];
	});
}

- (void)setRemoteAvatar:(NSImage *)image forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSMutableDictionary		*content = [_identifiersContent objectForKey:identifier];
		TCChatViewController	*view = [content objectForKey:TCChatViewKey];
		
		if (!content)
			return;
		
		// Update talk view.
		[view setRemoteAvatar:image];
		
		// Update user table.
		[content setObject:image forKey:TCChatAvatarKey];
		
		[_userList reloadData];
	});
}



/*
** TCChatWindowController - NSTableView
*/
#pragma mark - TCChatWindowController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[_identifiers count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	NSString		*identifier = _identifiers[(NSUInteger)rowIndex];
	NSDictionary	*content = _identifiersContent[identifier];
	TCChatCellView	*cellView = nil;
	
	// Select the right view.
	if (content[TCChatLastChatKey])
		cellView = [tableView makeViewWithIdentifier:@"chat_label" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"chat_no_label" owner:self];
	
	// Build cell content.
	NSMutableDictionary *rowContent = [[NSMutableDictionary alloc] init];
	
	if (content[TCChatAvatarKey])
		rowContent[TCChatCellAvatarKey] = content[TCChatAvatarKey];
	
	if (content[TCChatNameKey])
		rowContent[TCChatCellNameKey] = content[TCChatNameKey];
	
	if (content[TCChatLastChatKey])
		rowContent[TCChatCellChatTextKey] = content[TCChatLastChatKey];
	
	// > Set close button status.
	NSPoint windowMouseLocation = [self.window mouseLocationOutsideOfEventStream];
	NSPoint mouseLocation = [tableView convertPoint:windowMouseLocation fromView:nil];

	rowContent[TCChatCellCloseKey] = @([tableView rowAtPoint:mouseLocation] == rowIndex);
		
	// Set content.
	[cellView setContent:rowContent];
	
	return cellView;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger	index = [_userList selectedRow];
	NSString	*identifier;
	
	if (index < 0 || index >= [_identifiers count])
		return;
	
	identifier = [_identifiers objectAtIndex:(NSUInteger)index];
	
	[self _selectChatWithIdentifier:identifier];
}



/*
** TCChatWindowController - TCChatView
*/
#pragma mark - TCChatWindowController - TCChatView

- (void)chat:(TCChatViewController *)chat sendMessage:(NSString *)message
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSString	*identifier = chat.identifier;
		TCValue		*vdelegate = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatDelegateKey];
		id			context = [[_identifiersContent objectForKey:identifier] objectForKey:TCChatContextKey];
		id <TCChatWindowControllerDelegate>	delegate = [vdelegate object];
		
		if (!delegate)
			return;
		
		[delegate chatSendMessage:message identifier:identifier context:context];
	});
}



/*
** TCChatWindowController - Helpers
*/
#pragma mark - TCChatWindowController - Helpers

- (void)_loadChatView:(TCChatViewController *)view
{
	// > Main Queue <
	
	// Remove current view
	[_currentView removeFromSuperview];

	if (!view)
		return;
	
	// Load window if not loaded (else _chatView can eventually be nil).
	[self window];
	
	// Add the new one
	NSDictionary	*viewsDictionary;
	NSView			*content = view.view;
	
	[_chatView addSubview:content];
		
	viewsDictionary = NSDictionaryOfVariableBindings(content);
	
	[_chatView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[content]|" options:0 metrics:nil views:viewsDictionary]];
	[_chatView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[content]|" options:0 metrics:nil views:viewsDictionary]];
	
	_currentView = content;
	
	// Select the field (XXX direct or call a method ?)
	//[view becomeFirstResponder];
	
	[view makeFirstResponder];
}

- (void)_selectChatWithIdentifier:(NSString *)identifier
{
	// > Main Queue <
	
	if (!identifier)
		return;
	
	NSMutableDictionary	*content;
	NSUInteger			index;
	
	content = [_identifiersContent objectForKey:identifier];
	index = [_identifiers indexOfObject:identifier];
	
	if (!content || index == NSNotFound)
		return;
	
	// Update selection
	if ([_userList selectedRow] != index)
		[_userList selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	
	// Check not already loaded
	if ([identifier isEqualToString:_selectedIdentifier])
		return;

	// Hold selection
	_selectedIdentifier = identifier;
	
	// Load view
	[self _loadChatView:[content objectForKey:TCChatViewKey]];
	
	// Clean unread
	[content removeObjectForKey:TCChatLastChatKey];
	[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

@end
