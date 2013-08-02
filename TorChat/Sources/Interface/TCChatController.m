/*
 *  TCChatController.m
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



#import "TCChatController.h"

#import "TCChatTalk.h"
#import "TCChatView.h"
#import "TCChatCell.h"
#import "TCButton.h"
#import "TCValue.h"



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

// -- Drag & Frop --
#define TCChatPBType		@"com.sourcemac.torchat.chat"



/*
** TCChatController - Private
*/
#pragma mark - TCChatController - Private

@interface TCChatController ()
{	
	NSMutableArray			*_windows;
	TCChatWindowController	*_currentWindow;
	
	NSMutableDictionary		*_identifiers;
	dispatch_queue_t		_localQueue;
}

// -- Window --
- (void)closedWindowController:(TCChatWindowController *)controller;

- (void)popChatContent:(NSDictionary *)content withIdentifier:(NSString *)identifier fromFrame:(NSRect)frame;
- (void)moveIdentifier:(NSString *)identifier toWindowController:(TCChatWindowController *)controller atIndex:(NSUInteger)index;

@end



/*
** TCChatWindowController - Private
*/
#pragma mark - TCChatWindowController - Private

@interface TCChatWindowController () <TCChatViewDelegate>
{
	BOOL				_multiChatMode;
	
	NSMutableArray		*_identifiers;
	NSMutableDictionary	*_identifiers_content;
	
	NSTrackingArea		*_trakingArea;
	NSInteger			_trakingRow;
	
	TCButton			*_closeButton;
	
	NSString			*_selectedIdentifier;
}

+ (TCChatWindowController *)chatWindowController;

// -- Events --
- (void)mouseOverRow:(NSInteger)index;

// -- Tools --
- (void)showChats;
- (void)_setMultiChatMode:(BOOL)multichat animated:(BOOL)animated;
- (void)_loadChatView:(TCChatView *)view;
- (void)_updateTitle;

- (void)popChatContent:(NSDictionary *)content withIdentifier:(NSString *)identifier fromFrame:(NSRect)frame;
- (void)moveIdentifier:(NSString *)identifier toWindowController:(TCChatWindowController *)controller atIndex:(NSUInteger)index;

// -- Chat --
- (void)startChatWithIdentifier:(NSString *)identifier name:(NSString *)name localAvatar:(NSImage *)lavatar remoteAvatar:(NSImage *)ravatar context:(id)context delegate:(id <TCChatControllerDelegate>)delegate;
- (void)selectChatWithIdentifier:(NSString *)identifier;
- (void)stopChatWithIdentifier:(NSString *)identifier;

- (void)_selectChatWithIdentifier:(NSString *)identifier;

// -- Content --
- (void)receiveMessage:(NSString *)message forIdentifier:(NSString *)identifier;
- (void)receiveError:(NSString *)error forIdentifier:(NSString *)identifier;
- (void)receiveStatus:(NSString *)status forIdentifier:(NSString *)identifier;

- (void)setLocalAvatar:(NSImage *)image forIdentifier:(NSString *)identifier;
- (void)setRemoteAvatar:(NSImage *)image forIdentifier:(NSString *)identifier;

@end



/*
** TCChatController
*/
#pragma mark - TCChatController

@implementation TCChatController


/*
** TCChatController - Instance
*/
#pragma mark - TCChatController - Instance

+ (TCChatController *)sharedController
{
	static TCChatController	*shr;
	static dispatch_once_t	onceToken;
	
	dispatch_once(&onceToken, ^{
		
		shr = [[TCChatController alloc] init];
	});
	
	return shr;
}

- (id)init
{
	self = [super init];

	if (self)
	{
		// Create dispatch queue
		_localQueue = dispatch_queue_create("com.torchat.cocoa.chatcontroller.local", DISPATCH_QUEUE_SERIAL);
		
		// Containers
		_windows = [[NSMutableArray alloc] init];
		_identifiers = [[NSMutableDictionary alloc] init];
	}

	return self;
}



/*
** TCChatController - Window
*/
#pragma mark - TCChatController - Window

- (void)closedWindowController:(TCChatWindowController *)controller
{
	dispatch_async(_localQueue, ^{
		
		NSMutableArray *items = [NSMutableArray array];
		
		// Remove from array
		[_windows removeObject:controller];
		
		// Clean cache association
		for (NSString *identifier in _identifiers)
		{
			if ([_identifiers objectForKey:identifier] == controller)
				[items addObject:identifier];
		}
		
		[_identifiers removeObjectsForKeys:items];
		
		// Remove from current
		if (_currentWindow == controller)
			_currentWindow = nil;
	});
}

- (void)showedWindowController:(TCChatWindowController *)controller
{
	dispatch_async(_localQueue, ^{
		_currentWindow = controller;
	});
}

- (void)popChatContent:(NSDictionary *)content withIdentifier:(NSString *)identifier fromFrame:(NSRect)frame
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController	*ctrl = [TCChatWindowController chatWindowController];
		
		// Store the controller
		[_windows addObject:ctrl];

		_currentWindow = ctrl;
		
		// Cache the controller for this identifier
		[_identifiers setObject:ctrl forKey:identifier];
		
		// Do the drop in the window controller
		[ctrl popChatContent:content withIdentifier:identifier fromFrame:frame];
	});
}

- (void)moveIdentifier:(NSString *)identifier toWindowController:(TCChatWindowController *)controller atIndex:(NSUInteger)index
{
	if (!identifier || !controller)
		return;

	dispatch_async(_localQueue, ^{

		TCChatWindowController *current = [_identifiers objectForKey:identifier];
		
		if (!current)
			return;
		
		// Move identifier and content from windows controller
		[current moveIdentifier:identifier toWindowController:controller atIndex:index];
		
		// Update cache
		[_identifiers setObject:controller forKey:identifier];
	});
}



/*
** TCChatController - Chat
*/
#pragma mark - TCChatController - Chat

- (void)startChatWithIdentifier:(NSString *)identifier name:(NSString *)name localAvatar:(NSImage *)lavatar remoteAvatar:(NSImage *)ravatar context:(id)context delegate:(id <TCChatControllerDelegate>)delegate
{
	if (!identifier)
		return;
			
	// Start the chat
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController *ctrl = [_identifiers objectForKey:identifier];
		
		// If we have already a window, don't need to do anything
		if (ctrl)
			return;
		
		if (_currentWindow)
			ctrl = _currentWindow;
		else if ([_windows count] > 0)
			ctrl = [_windows lastObject];
		else
		{
			ctrl = [TCChatWindowController chatWindowController];
			
			[_windows addObject:ctrl];
			
			[ctrl showChats]; // We want this behaviour ?
		}
		
		if (ctrl)
		{
			// Hold current window controller
			_currentWindow = ctrl;
			
			// Cache the controller for this identifier
			[_identifiers setObject:ctrl forKey:identifier];
			
			// Start the chat in the controller
			[ctrl startChatWithIdentifier:identifier name:name localAvatar:lavatar remoteAvatar:ravatar context:context delegate:delegate];
		}
	});
}

- (void)selectChatWithIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController *ctrl = [_identifiers objectForKey:identifier];
		
		if (!ctrl)
			return;
	
		// Select the chat
		[ctrl selectChatWithIdentifier:identifier];
		
		// Show
		[ctrl showChats];
	});
}

- (void)stopChatWithIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController *ctrl = [_identifiers objectForKey:identifier];

		if (!ctrl)
			return;
		
		[ctrl stopChatWithIdentifier:identifier];
		
		[_identifiers removeObjectForKey:identifier];
	});
}



/*
** TCChatController - Content
*/
#pragma mark - TCChatController - Content

- (void)receiveMessage:(NSString *)message forIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
	
		TCChatWindowController	*ctrl = [_identifiers objectForKey:identifier];
		
		if (!ctrl)
			return;
		
		[ctrl receiveMessage:message forIdentifier:identifier];
	});
}

- (void)receiveError:(NSString *)error forIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController	*ctrl = [_identifiers objectForKey:identifier];
		
		if (!ctrl)
			return;
		
		[ctrl receiveError:error forIdentifier:identifier];
	});
}

- (void)receiveStatus:(NSString *)status forIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController	*ctrl = [_identifiers objectForKey:identifier];
		
		if (!ctrl)
			return;
		
		[ctrl receiveStatus:status forIdentifier:identifier];
	});
}

- (void)setLocalAvatar:(NSImage *)image forIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController	*ctrl = [_identifiers objectForKey:identifier];
		
		if (!ctrl)
			return;
		
		[ctrl setLocalAvatar:image forIdentifier:identifier];
	});
}

- (void)setRemoteAvatar:(NSImage *)image forIdentifier:(NSString *)identifier
{
	dispatch_async(_localQueue, ^{
		
		TCChatWindowController	*ctrl = [_identifiers objectForKey:identifier];
		
		if (!ctrl)
			return;
		
		[ctrl setRemoteAvatar:image forIdentifier:identifier];
	});
}

@end



/*
** TCChatWindowController
*/
#pragma mark - TCChatWindowController

@implementation TCChatWindowController


/*
** TCChatWindowController - Property
*/
#pragma mark - TCChatWindowController - Property


/*
** TCChatWindowController - Instance
*/
#pragma mark - TCChatWindowController - Instance

+ (TCChatWindowController *)chatWindowController
{
	if (dispatch_get_current_queue() == dispatch_get_main_queue())
	{
		return [[TCChatWindowController alloc] init];
	}
	else
	{
		__block TCChatWindowController *result = nil;

		dispatch_sync(dispatch_get_main_queue(), ^{
			result = [[TCChatWindowController alloc] init];
		});
		
		return result;
	}
}

- (id)init
{
	self = [super initWithWindowNibName:@"ChatWindow"];

	if (self)
	{
		// Inits
		_multiChatMode = YES;
		
		_trakingRow = -1;
		
		// Create containers
		_identifiers = [[NSMutableArray alloc] init];
		_identifiers_content = [[NSMutableDictionary alloc] init];
	}

	return self;
}

- (void)awakeFromNib
{
	[self.window center];
	[self setWindowFrameAutosaveName:@"ChatWindow"];
	
	// Cancel multichat mode
	[self _setMultiChatMode:NO animated:NO];
	
	// Activate tracking on UserList
	_trakingArea= [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:self userInfo:nil];
							   
	[_userList addTrackingArea:_trakingArea];
	
	// Build close button
	_closeButton = [[TCButton alloc] init];
	
	[_closeButton setImage:[NSImage imageNamed:@"file_stop"]];
	[_closeButton setRollOverImage:[NSImage imageNamed:@"file_stop_rollover"]];
	[_closeButton setPushImage:[NSImage imageNamed:@"file_stop_pushed"]];
	[_closeButton setTarget:self];
	[_closeButton setAction:@selector(closeAction:)];
	[_closeButton setHidden:YES];
	[_closeButton setFrame:NSMakeRect(0, 0, 14, 14)];
	
	[_userList addSubview:_closeButton];
	
	// Activate pb type
	[_userList registerForDraggedTypes:[NSArray arrayWithObject:TCChatPBType]];
	
	_userList.dropDelegate = self;
}

- (void)dealloc
{
	TCDebugLog("TCChatWindowController Dealloc");

	[_userList removeTrackingArea:_trakingArea];
}



/*
** TCChatWindowController - Events
*/
#pragma mark - TCChatWindowController - Events

- (void)mouseEntered:(NSEvent *)theEvent
{
}

- (void)mouseExited:(NSEvent *)theEvent
{
	[self mouseOverRow:-1];
}

- (void)mouseMoved:(NSEvent *)theEvent
{
	NSInteger index = [_userList rowAtPoint:[_userList convertPoint:[theEvent locationInWindow] fromView:nil]];
	
	[self mouseOverRow:index];
}

- (void)mouseOverRow:(NSInteger)index
{
	NSInteger lindex;
	
	if (index == _trakingRow)
		return;

	lindex = _trakingRow;
	_trakingRow = index;
	
	if (lindex != -1)
		[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)lindex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
	
	if (_trakingRow != -1)
	{		
		[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)_trakingRow] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		
		[_closeButton setHidden:NO];
	}
	else
		[_closeButton setHidden:YES];
}

- (void)closeAction:(id)sender
{	
	if (_trakingRow < 0 || _trakingRow >= [_identifiers count])
		return;
	
	NSString *identifier = [_identifiers objectAtIndex:(NSUInteger)_trakingRow];
	
	[[TCChatController sharedController] stopChatWithIdentifier:identifier];
}



/*
** TCChatWindowController - Tools
*/
#pragma mark - TCChatWindowController - Tools

- (void)showChats
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self showWindow:self];
	});
}

- (void)_setMultiChatMode:(BOOL)multichat animated:(BOOL)animated
{
	// > Main Queue <
	
	NSRect	list_rect;
	NSRect	win_rect;
	
	// Check mode
	if (multichat == _multiChatMode)
		return;
	
	_multiChatMode = multichat;
	
	// Get current sizes
	list_rect = [_userList frame];
	win_rect = [self.window frame];
	
	// Compute new size
	if (multichat)
	{
		win_rect.origin.x -= list_rect.size.width + [_splitView dividerThickness];
		win_rect.size.width += list_rect.size.width + [_splitView dividerThickness];
		
		if (win_rect.origin.x < 0)
			win_rect.origin.x = 0;
	}
	else
	{
		win_rect.origin.x += list_rect.size.width + [_splitView dividerThickness];
		win_rect.size.width -= list_rect.size.width + [_splitView dividerThickness];
	}
	
	[_splitView setAutoresizingMask:NSViewMinXMargin];
	[self.window setFrame:win_rect display:YES animate:animated];
	[_splitView setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
}

- (void)_loadChatView:(TCChatView *)view
{
	// > Main Queue <
	
	NSArray *subviews = [_chatView subviews];
	NSRect	crect, vrect;
	
	// Remove current view
	if ([subviews count] > 0)
	{
		NSView *vw = [subviews objectAtIndex:0];
		
		[vw removeFromSuperview];
	}
	
	// Add the new one
	vrect = [_chatView frame];
	crect = NSMakeRect(0, 0, vrect.size.width, vrect.size.height);

	[view.view setFrame:crect];
	
	[_chatView addSubview:view.view];
	
	// Select the field (XXX direct or call a method ?)
	[view.userField becomeFirstResponder];
	
	// Update title
	[self _updateTitle];
}

- (void)_updateTitle
{
	// > Main Queue <
	
	NSString *name = @"-";
	NSString *dname = @"";
	
	// Get selection name
	if (_selectedIdentifier)
	{
		NSDictionary	*content;
		TCChatView		*view;

		content = [_identifiers_content objectForKey:_selectedIdentifier];
		view = [content objectForKey:TCChatViewKey];
		
		name = view.name;
		dname = [NSString stringWithFormat:@" — %@", name];
	}
	
	// Update title
	if ([_identifiers count] <= 1)
		[self.window setTitle:name];
	else
		[self.window setTitle:[NSString stringWithFormat:@"TorChat (%ld %@)%@", [_identifiers count], NSLocalizedString(@"chats_count", @""), dname]];

}

- (void)popChatContent:(NSDictionary *)content withIdentifier:(NSString *)identifier fromFrame:(NSRect)frame
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSRect		nrect;
		NSRect		vrect;
		CGFloat		dw, dh;
		TCChatView	*view;
		
		view = [content objectForKey:TCChatViewKey];
		
		// Update delegate
		view.delegate = self;
				
		// Compute final state
		vrect = [view.view bounds];
		
		dw = vrect.size.width - frame.size.width;
		dh = vrect.size.height - frame.size.height;
		
		// XXX we should take the size of the window title bar in the computation (window frame height - content frame height).
		nrect = NSMakeRect(frame.origin.x - dw / 2.0, frame.origin.y - dh / 2.0, frame.size.width + dw, frame.size.height + dh);
		
		// Add identifier
		[_identifiers_content setObject:content forKey:identifier];
		[_identifiers addObject:identifier];
		
		// Reload table
		[_userList reloadData];

		// Select row (and load view with delegate)
		[self _selectChatWithIdentifier:identifier];
		
		// Update title
		[self _updateTitle];
				
		// Set the initial state
		[self.window setFrame:frame display:NO];
		[self.window setAlphaValue:0.7];
		[self showWindow:self];
		
		// Animate to finale state
		[NSAnimationContext beginGrouping];
		{
			[[NSAnimationContext currentContext] setDuration:0.2];
			
			[[self.window animator] setFrame:nrect display:YES];
			[[self.window animator] setAlphaValue:1.0];
		}
		[NSAnimationContext endGrouping];
	});
}

- (void)moveIdentifier:(NSString *)identifier toWindowController:(TCChatWindowController *)controller atIndex:(NSUInteger)index
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSDictionary	*content = [_identifiers_content objectForKey:identifier];
		TCChatView		*view;
		
		if (!content)
			return;
		
		// Add identifier to target controller
		[controller->_identifiers_content setObject:content forKey:identifier];
		[controller->_identifiers insertObject:identifier atIndex:index];
		
		// Update delegate
		view = [content objectForKey:TCChatViewKey];
		view.delegate = controller;
		
		// Remove from ourself
		[self stopChatWithIdentifier:identifier];
		
		// Select the item
		[controller->_userList reloadData];
		[controller->_userList selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
		[controller showWindow:self];
		
		// Update title
		[controller _updateTitle];
	});
}



/*
** TCChatWindowController - TCChatView Delegate
*/
#pragma mark - TCChatWindowController - TCChatView Delegate

- (void)chat:(TCChatView *)chat sendMessage:(NSString *)message
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSString	*identifier = chat.identifier;
		TCValue		*vdelegate = [[_identifiers_content objectForKey:identifier] objectForKey:TCChatDelegateKey];
		id			context = [[_identifiers_content objectForKey:identifier] objectForKey:TCChatContextKey];
		id <TCChatControllerDelegate>	delegate = [vdelegate object];

		if (!delegate)
			return;
		
		[delegate chatSendMessage:message identifier:identifier context:context];
	});
}



/*
** TCChatWindowController - Chat
*/
#pragma mark - TCChatWindowController - Chat

- (void)startChatWithIdentifier:(NSString *)identifier name:(NSString *)name localAvatar:(NSImage *)lavatar remoteAvatar:(NSImage *)ravatar context:(id)context delegate:(id <TCChatControllerDelegate>)delegate
{
	if (!identifier)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSMutableDictionary		*content = [_identifiers_content objectForKey:identifier];
		TCValue					*pdelegate = nil;
		TCChatView				*view;
		
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
		view = [TCChatView chatViewWithIdentifier:identifier name:name delegate:self];
		
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
		[_identifiers_content setObject:content forKey:identifier];
		[_identifiers addObject:identifier];
		
		// Reload table
		[_userList reloadData];
		
		// Activate multichat mode.
		if ([_identifiers count] == 2)
			[self _setMultiChatMode:YES animated:YES];
		
		// Update title.
		[self _updateTitle];
	});
}

- (void)selectChatWithIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self _selectChatWithIdentifier:identifier];
	});
}

- (void)_selectChatWithIdentifier:(NSString *)identifier
{
	// > Main Queue <
	
	if (!identifier)
		return;
	
	NSMutableDictionary	*content;
	NSUInteger			index;

	content = [_identifiers_content objectForKey:identifier];
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

- (void)stopChatWithIdentifier:(NSString *)identifier
{
	if (!identifier)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if ([_identifiers_content objectForKey:identifier] == nil)
			return;
		
		NSUInteger	index = [_identifiers indexOfObject:identifier];

		if (index == NSNotFound)
			return;
				
		// Remove item
		[_identifiers_content removeObjectForKey:identifier];
		[_identifiers removeObject:identifier];
				
		if ([_identifiers count] == 0)
			[self.window close];
		else
		{
			NSUInteger	nindex;

			// Reload table
			[_userList reloadData];
			
			// Update selection
			if ([_selectedIdentifier isEqualToString:identifier])
			{
				nindex = index;
			
				if (nindex >= [_identifiers count])
					nindex = [_identifiers count] - 1;
			
				[self _selectChatWithIdentifier:[_identifiers objectAtIndex:nindex]];
			}
			else
				[self _selectChatWithIdentifier:_selectedIdentifier];
			
			// Deactivate multichat mode
			if ([_identifiers count] == 1)
				[self _setMultiChatMode:NO animated:YES];
			
			// Update tracking
			[self mouseMoved:[NSApp currentEvent]];

			// Update title
			[self _updateTitle];
		}
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
		
		TCChatView	*view = [[_identifiers_content objectForKey:identifier] objectForKey:TCChatViewKey];
		NSInteger	index = [_userList selectedRow];
		BOOL		setUnread = NO;
		
		if (!view)
			return;
		
		// Add message to view
		[view receiveMessage:message];
		
		// Show as unread if needed
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
			NSMutableDictionary	*content = [_identifiers_content objectForKey:identifier];
			NSUInteger			cindex = [_identifiers indexOfObject:identifier];
			
			[content setObject:message forKey:TCChatLastChatKey];
			
			[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:cindex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		}
	});
}

- (void)receiveError:(NSString *)error forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatView *view = [[_identifiers_content objectForKey:identifier] objectForKey:TCChatViewKey];
		
		if (!view)
			return;
		
		[view receiveError:error];
	});
}

- (void)receiveStatus:(NSString *)status forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatView *view = [[_identifiers_content objectForKey:identifier] objectForKey:TCChatViewKey];
		
		if (!view)
			return;
		
		[view receiveStatus:status];
	});
}

- (void)setLocalAvatar:(NSImage *)image forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCChatView *view = [[_identifiers_content objectForKey:identifier] objectForKey:TCChatViewKey];
		
		if (!view)
			return;
		
		// Update talk view
		[view setLocalAvatar:image];
	});
}

- (void)setRemoteAvatar:(NSImage *)image forIdentifier:(NSString *)identifier
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		NSMutableDictionary	*content = [_identifiers_content objectForKey:identifier];
		TCChatView			*view = [content objectForKey:TCChatViewKey];
		
		if (!content)
			return;
		
		// Update talk view
		[view setRemoteAvatar:image];
		
		// Update user table
		[content setObject:image forKey:TCChatAvatarKey];
	
		[_userList reloadData];
	});
}



/*
** TCChatWindowController - SplitView Delegate
*/
#pragma mark - TCChatWindowController - SplitView Delegate

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMin ofSubviewAt:(NSInteger)dividerIndex
{
	// Should let some space for the close button. Not beautiful but...
	return 60;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMaximumPosition ofSubviewAt:(NSInteger)dividerIndex
{
	return [self.window frame].size.width - 300;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize
{
	NSSize	userSize = [_userView frame].size;
	NSSize	chatSize = [_chatView frame].size;
	NSSize	splitSize = [_splitView frame].size;
	
	chatSize.height = splitSize.height;
	userSize.height = splitSize.height;
	
	chatSize.width = splitSize.width - [_splitView dividerThickness] - userSize.width;
	
	[_userView setFrameSize:userSize];
	[_chatView setFrameSize:chatSize];
}



/*
** TCChatWindowController - NSWindow Delegate
*/
#pragma mark - TCChatWindowController - NSWindow Delegate

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize
{
	NSSize	wsize = [sender frame].size;
	NSSize	csize = [_chatView frame].size;
	
	CGFloat	deltaw = frameSize.width - wsize.width;
	CGFloat	deltah = frameSize.height - wsize.height;

	
	if (csize.width + deltaw < 300)
		wsize.width = [_userView frame].size.width + [_splitView dividerThickness] + 300;
	else
		wsize.width = frameSize.width;
	
	if (csize.height + deltah < 300)
		wsize.height = 300;
	else
		wsize.height = frameSize.height;
	
	// FIXME: we should backup this for futur re-opening. In the close + awake ?
	
	return wsize;
}

- (BOOL)windowShouldClose:(id)sender
{
	NSAlert *alert;
	
	if ([_identifiers count] <= 1)
		return YES;
	
	alert = [NSAlert alertWithMessageText:NSLocalizedString(@"chat_want_close", @"") defaultButton:NSLocalizedString(@"chat_close", @"") alternateButton:NSLocalizedString(@"chat_cancel", @"") otherButton:nil informativeTextWithFormat:NSLocalizedString(@"chat_want_close_info", @""), [_identifiers count]];

	[alert beginSheetModalForWindow:self.window modalDelegate:self didEndSelector:@selector(alertDidEnd:returnCode:contextInfo:) contextInfo:NULL];

	return NO;
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo
{
	if (returnCode == NSAlertDefaultReturn)
		[self.window close];
}

- (void)windowWillClose:(NSNotification *)notification
{	
	[[TCChatController sharedController] closedWindowController:self];
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	NSInteger index;

	// Hold the current chat window
	[[TCChatController sharedController] showedWindowController:self];
	
	// Clean the selected unread messages content
	index = [_userList selectedRow];
	
	if (index >= 0 && index < [_identifiers count])
	{
		NSString			*identifier;
		NSMutableDictionary	*content;
		
		identifier = [_identifiers objectAtIndex:(NSUInteger)index];
		content = [_identifiers_content objectForKey:identifier];

		// Clean unread
		[content removeObjectForKey:TCChatLastChatKey];
		[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
	}
}



/*
** TCChatWindowController - NSTableView Delegate
*/
#pragma mark - TCChatWindowController - NSTableView Delegate

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[_identifiers count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	NSString			*identifier;
	NSDictionary		*content;
	NSMutableDictionary *cell;
	id					value;

	if (rowIndex < 0 || rowIndex >= [_identifiers count])
		return nil;
		
	// Get row identifier
	identifier = [_identifiers objectAtIndex:(NSUInteger)rowIndex];
	
	if (!identifier)
		return nil;
	
	// Get row content
	content = [_identifiers_content objectForKey:identifier];
	
	// Build cell content
	cell = [NSMutableDictionary dictionary];
	
	// > Avatar
	value = [content objectForKey:TCChatAvatarKey];
	
	if (value)
		[cell setObject:value forKey:TCChatCellAvatarKey];
	
	// > Name
	value = [content objectForKey:TCChatNameKey];
	
	if (value)
		[cell setObject:value forKey:TCChatCellNameKey];
	
	// > Last chat
	value = [content objectForKey:TCChatLastChatKey];
	
	if (value && [value length] > 0)
		[cell setObject:value forKey:TCChatCellChatTextKey];
	
	// > Mouse Over
	if (_trakingRow == rowIndex)
	{
		[cell setObject:[NSNumber numberWithBool:YES] forKey:TCChatCellMouseOverKey];
		[cell setObject:_closeButton forKey:TCChatCellAccessoryKey];
	}
	
	return cell;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger			index = [_userList selectedRow];
	NSString			*identifier;

	if (index < 0 || index >= [_identifiers count])
		return;
	
	identifier = [_identifiers objectAtIndex:(NSUInteger)index];
	
	[self selectChatWithIdentifier:identifier];
}

- (BOOL)tableView:(NSTableView *)tv writeRowsWithIndexes:(NSIndexSet *)rowIndexes toPasteboard:(NSPasteboard *)pboard
{
	NSUInteger	index = [rowIndexes firstIndex];
	NSString	*identifier = [_identifiers objectAtIndex:index];
	
    [pboard declareTypes:[NSArray arrayWithObject:TCChatPBType] owner:self];
    [pboard setString:identifier forType:TCChatPBType];
	
    return YES;
}

- (NSDragOperation)tableView:(NSTableView *)tv validateDrop:(id <NSDraggingInfo>)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)op
{	
	if (op == NSTableViewDropAbove)
		return NSDragOperationEvery;
	
	return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id <NSDraggingInfo>)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard	*pboard = [info draggingPasteboard];
    NSString		*identifier = [pboard stringForType:TCChatPBType];
	NSUInteger		index = [_identifiers indexOfObject:identifier];
	
	if (index == NSNotFound)
	{
		// Dragging in another TCChatWindowController

		[[TCChatController sharedController] moveIdentifier:identifier toWindowController:self atIndex:(NSUInteger)row];
	}
	else
	{
		// Exchanging items
		
		[_identifiers insertObject:identifier atIndex:(NSUInteger)row];
		
		if (row <= index)
			[_identifiers removeObjectAtIndex:(index + 1)];
		else
			[_identifiers removeObjectAtIndex:index];
		
		[self _selectChatWithIdentifier:identifier];
		[_userList mouseMoved:[NSApp currentEvent]];
	}

	return YES;
}

- (NSImage *)tableView:(TCChatsTableView *)tableView dropImageForRow:(NSUInteger)row
{
	NSString			*identifier;
	NSDictionary		*content;
	TCChatView			*view;
	NSData				*pdfContent;
	NSImage				*result;
	
	if (row >= [_identifiers count])
		return [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
	
	// Get the chat view
	identifier = [_identifiers objectAtIndex:row];
	content = [_identifiers_content objectForKey:identifier];
	view = [content objectForKey:TCChatViewKey];
	
	// Generate snapshot (use of initWithFocusedViewRect is a problem when the view is not showed)
	pdfContent = [view.view dataWithPDFInsideRect:[view.view bounds]];
	
	if (!pdfContent)
		return [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];

	result = [[NSImage alloc] initWithData:pdfContent];
	
	[result setSize:NSMakeSize(150, 150)];

	// Add a frame
	[result lockFocus];
	{
		[[NSBezierPath bezierPathWithRect:NSMakeRect(0, 0, 150, 150)] stroke];
	}
	[result unlockFocus];

	
	return result;

}

- (void)tableView:(TCChatsTableView *)tableView droppedRow:(NSUInteger)row toFrame:(NSRect)frame
{
	NSString		*identifier;
	NSDictionary	*content;
	
	if (row >= [_identifiers count])
		return;
	
	identifier = [_identifiers objectAtIndex:row];
	content = [_identifiers_content objectForKey:identifier];
	
	// Drop the new window
	[[TCChatController sharedController] popChatContent:content withIdentifier:identifier fromFrame:frame];
	
	// Close the view
	[self stopChatWithIdentifier:identifier];
}

@end
