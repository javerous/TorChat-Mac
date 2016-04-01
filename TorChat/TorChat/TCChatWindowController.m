/*
 *  TCChatWindowController.m
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

#import <objc/runtime.h>

#import "TCChatWindowController.h"

#import "TCMainController.h"
#import "TCChatViewController.h"

#import "TCCoreManager.h"
#import "TCImage.h"

#import "TCButton.h"
#import "TCValue.h"

#import "TCChatCellView.h"



/*
** TCBuddy (TCChatWindowController)
*/
#pragma mark - TCBuddy (TCChatWindowController)

@interface TCBuddy (TCChatWindowController)

@property (strong, nonatomic) NSString *lastMessage;

@end

@implementation TCBuddy (TCChatWindowController)

- (void)setLastMessage:(NSString *)lastMessage
{
	objc_setAssociatedObject(self, @selector(lastMessage), lastMessage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)lastMessage
{
	return objc_getAssociatedObject(self, @selector(lastMessage));
}

@end



/*
** TCChatWindowController - Private
*/
#pragma mark - TCChatWindowController - Private

@interface TCChatWindowController () <TCCoreManagerObserver, TCBuddyObserver>
{
	dispatch_queue_t _localQueue;
	
	id <TCConfigApp>	_configuration;
	TCCoreManager		*_core;
	
	NSMutableArray	*_viewsCtrl;
	NSView			*_currentView;

	__weak TCBuddy *_selectedBuddy;
	
	NSMutableSet *_buddies;
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

+ (instancetype)sharedController
{
	static dispatch_once_t			onceToken;
	static TCChatWindowController	*shr;
	
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
		// Queues.
		_localQueue = dispatch_get_main_queue();
		
		// Containers
		_viewsCtrl = [[NSMutableArray alloc] init];
		_buddies = [[NSMutableSet alloc] init];
	}
	
	return self;
}



/*
** TCChatWindowController - Life
*/
#pragma mark - TCChatWindowController - Life

- (void)startWithConfiguration:(id <TCConfigApp>)configuration coreManager:(TCCoreManager *)coreMananager completionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	if (!handler)
		handler = ^{ };
	
	dispatch_group_async(group, _localQueue, ^{
		
		// Hold parameters.
		_configuration = configuration;
		_core = coreMananager;
		
		// Observe.
		[_core addObserver:self];
		
		// Get current buddies.
		NSArray *buddies = [_core buddies];
		
		for (TCBuddy *buddy in buddies)
		{
			[_buddies addObject:buddy];
			[buddy addObserver:self];
		}
		
		// Load transcripted buddies.
		dispatch_group_enter(group);
		
		[_configuration transcriptBuddiesIdentifiersWithCompletionHandler:^(NSArray *buddiesIdentifiers) {

			dispatch_group_async(group, _localQueue, ^{

				for (NSString *buddyIdentifier in buddiesIdentifiers)
				{
					TCBuddy *buddy = [coreMananager buddyWithIdentifier:buddyIdentifier];
					
					if (!buddy)
						continue;
					
					[self _addChatWithBuddy:buddy select:NO];
				}
			});
			
			dispatch_group_leave(group);
		}];
	});
	
	// Wait end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	if (!handler)
		handler = ^{ };
	
	dispatch_group_async(group, _localQueue, ^{
		
		// Close.
		[self close];
		
		// Remove observers.
		[_core removeObserver:self];
		
		for (TCBuddy *buddy in _buddies)
			[buddy removeObserver:self];
		
		// Unreference.
		_core = nil;
		_configuration = nil;
		
		// Clean containers.
		[_buddies removeAllObjects];
		[_viewsCtrl removeAllObjects];
	});
	
	// Wait end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
}



/*
** TCChatWindowController - NSWindowController
*/
#pragma mark - TCChatWindowController - NSWindowController

- (void)windowDidLoad
{
	// Configure window.
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
	
	dispatch_async(_localQueue, ^{
		
		if (index < 0 || index >= _viewsCtrl.count)
			return;

		// Get selected view.
		id item = _viewsCtrl[(NSUInteger)index];
		
		if ([item isKindOfClass:[TCChatViewController class]] == NO)
			return;
		
		// Validate the close if more than 0 message, as any close will delete the full conversation.
		TCChatViewController	*viewCtrl = item;
		TCBuddy					*buddy = viewCtrl.buddy;
		
		if (viewCtrl.messagesCount > 0)
		{
			NSAlert *alert = [[NSAlert alloc] init];
			
			alert.messageText = NSLocalizedString(@"chat_want_close", @"");
			alert.informativeText = NSLocalizedString(@"chat_want_close_info", @"");
			
			[alert addButtonWithTitle:NSLocalizedString(@"chat_close", @"")];
			[alert addButtonWithTitle:NSLocalizedString(@"chat_cancel", @"")];
			
			[alert beginSheetModalForWindow:self.window completionHandler:^(NSModalResponse returnCode) {
				if (returnCode == NSAlertFirstButtonReturn)
				{
					[self closeChatWithBuddy:buddy];
					[_configuration transcriptRemoveMessagesForBuddyIdentifier:buddy.identifier];
				}
			}];
		}
		else
			[self closeChatWithBuddy:buddy];
	});
}



/*
** TCChatWindowController - Window
*/
#pragma mark - TCChatWindowController - Window

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	NSInteger index = [_userList selectedRow];
	
	if (index < 0 || index >= _viewsCtrl.count)
		return;
	
	// Clean last message.
	TCBuddy	*buddy = [self _buddyAtIndex:(NSUInteger)index];

	buddy.lastMessage = nil;
	
	[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}



/*
** TCChatWindowController - Chat
*/
#pragma mark - TCChatWindowController - Chat

- (void)openChatWithBuddy:(TCBuddy *)abuddy select:(BOOL)select
{
	dispatch_async(_localQueue, ^{
		
		TCBuddy *buddy = abuddy;
		
		if (!buddy)
		{
			if (_selectedBuddy)
				buddy = _selectedBuddy;
			else if (_viewsCtrl.count > 0)
				buddy = [self _buddyAtIndex:0];
		}
		
		if (!buddy)
			return;
		
		[self _openChatWithBuddy:buddy select:select];
	});
}

- (void)_openChatWithBuddy:(TCBuddy *)buddy select:(BOOL)select
{
	// > localQueue <
	
	// Show window.
	[self showWindow:nil];
	
	// Add chat.
	[self _addChatWithBuddy:buddy select:select];
}

- (void)_addChatWithBuddy:(TCBuddy *)buddy select:(BOOL)select
{
	// > localQueue <
	
	// Add view if necessary.
	if ([self _indexOfViewControllerForBuddy:buddy] == NSNotFound)
	{
		[_viewsCtrl addObject:buddy];
		[_userList reloadData];
	}
	
	// Select this chat if it's the first one.
	if (select)
		[self _selectChatWithBuddy:buddy];
}

- (void)closeChatWithBuddy:(TCBuddy *)buddy
{
	dispatch_async(_localQueue, ^{
		
		// Search view controller.
		NSUInteger index = [self _indexOfViewControllerForBuddy:buddy];
		
		if (index == NSNotFound)
			return;
		
		// Remove from view.
		[_viewsCtrl removeObjectAtIndex:index];
		[_userList reloadData];
		
		// Update selection.
		TCBuddy *selectedBuddy = _selectedBuddy;
		
		if (selectedBuddy == buddy)
		{
			NSUInteger nindex = index;
			
			if ([_viewsCtrl count] == 0)
			{
				[self _showChatViewController:nil];
				
				_selectedBuddy = nil;
			}
			else
			{
				if (nindex >= _viewsCtrl.count)
					nindex = _viewsCtrl.count - 1;
				
				[self _selectChatWithBuddy:[self _buddyAtIndex:nindex]];
			}
		}
		else
			[self _selectChatWithBuddy:selectedBuddy];
	});
}



/*
** TCChatWindowController - NSTableView
*/
#pragma mark - TCChatWindowController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)_viewsCtrl.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Get associated buddy.
	
	if (rowIndex >= _viewsCtrl.count)
		return nil;
	
	// Get item.
	TCBuddy *buddy = [self _buddyAtIndex:(NSUInteger)rowIndex];
	
	// Select the right view.
	TCChatCellView	*cellView = nil;
	NSString		*lastMessage = buddy.lastMessage;
	
	if (lastMessage)
		cellView = [tableView makeViewWithIdentifier:@"chat_label" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"chat_no_label" owner:self];
	
	// Build cell content.
	NSMutableDictionary *rowContent = [[NSMutableDictionary alloc] init];
	
	// > Avatar.
	NSImage *avatar = [buddy.profileAvatar imageRepresentation];
	
	if (avatar)
		rowContent[TCChatCellAvatarKey] = avatar;
	
	// > Name.
	NSString *name = [buddy finalName];
	
	if (name)
		rowContent[TCChatCellNameKey] = name;
	
	if (lastMessage)
		rowContent[TCChatCellChatTextKey] = lastMessage;
	
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
	NSInteger rowIndex = [_userList selectedRow];

	if (rowIndex < 0 || rowIndex >= _viewsCtrl.count)
		return;

	[self _selectChatWithBuddy:[self _buddyAtIndex:(NSUInteger)rowIndex]];
}



/*
** TCChatWindowController - TCCoreManagerObserver
*/
#pragma mark - TCChatWindowController - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(SMInfo *)info
{
	if (info.kind == SMInfoInfo)
	{
		switch (info.code)
		{
			case TCCoreEventProfileAvatar:
			{
				NSImage	*avatar = [(TCImage *)info.context imageRepresentation];
				
				if (!avatar)
					avatar = [NSImage imageNamed:NSImageNameUser];
				
				dispatch_async(_localQueue, ^{
					for (id item in _viewsCtrl)
					{
						if ([item isKindOfClass:[TCChatViewController class]])
						{
							TCChatViewController *viewCtrl = item;
							
							[viewCtrl setLocalAvatar:avatar];
						}
					}
				});
				
				break;
			}
				
			case TCCoreEventBuddyNew:
			{
				TCBuddy *buddy = (TCBuddy *)info.context;
				
				[buddy addObserver:self];
				
				dispatch_async(_localQueue, ^{
					[_buddies addObject:buddy];
				});

				break;
			}
				
			case TCCoreEventBuddyRemove:
			{
				TCBuddy *buddy = (TCBuddy *)info.context;
				
				[buddy removeObserver:self];
				
				dispatch_async(_localQueue, ^{
					[_buddies removeObject:buddy];
				});
				
				break;
			}
		}
	}
}



/*
** TCChatWindowController - TCBuddyObserver
*/
#pragma mark - TCChatWindowController - TCBuddyObserver

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
				
				// Update table view.
				dispatch_async(_localQueue, ^{
					[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
				});
				
				break;
			}
				
			case TCBuddyEventMessage:
			{
				NSString *message = info.context;
				
				if (!message)
					break;
				
				dispatch_async(_localQueue, ^{
					
					// Start a chat UI.
					[self _openChatWithBuddy:buddy select:(self.window.isVisible == NO)];
					
					// Show as unread if necessary.
					if (buddy != _selectedBuddy || [self.window isKeyWindow] == NO)
					{
						NSUInteger index = [self _indexOfViewControllerForBuddy:buddy];

						buddy.lastMessage = message;
						
						if (index != NSNotFound)
							[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
					}
				});
				
				break;
			}
		}
	}
}



/*
** TCChatWindowController - Helpers
*/
#pragma mark - TCChatWindowController - Helpers

- (void)_selectChatWithBuddy:(TCBuddy *)buddy
{
	// > localQueue <
	
	if (!buddy)
		return;
	
	if (_selectedBuddy == buddy)
		return;
	
	// Search view.
	NSUInteger				index = [self _indexOfViewControllerForBuddy:buddy];
	TCChatViewController	*viewCtrl;

	if (index == NSNotFound)
		return;
	
	// Create view controler if necessayr.
	id item = _viewsCtrl[index];
	
	if ([item isKindOfClass:[TCBuddy class]])
	{
		 // > Build chat view.
		 viewCtrl = [TCChatViewController chatViewWithBuddy:buddy configuration:_configuration];
		 
		 if (!viewCtrl)
			 return;
		
		[_viewsCtrl replaceObjectAtIndex:index withObject:viewCtrl];
		
		 // > Configure view controller.
		 NSImage *localAvatar = [[_core profileAvatar] imageRepresentation];
		 
		 if (!localAvatar)
			 localAvatar = [NSImage imageNamed:NSImageNameUser];
		 
		 [viewCtrl setLocalAvatar:localAvatar];
	}
	else
		viewCtrl = item;
	
	// Hold selection.
	_selectedBuddy = buddy;
	
	// Update selection.
	if ([_userList selectedRow] != index)
		[_userList selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	
	// Show view.
	[self _showChatViewController:viewCtrl];
	
	// Clean unread.
	buddy.lastMessage = nil;
	
	[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)_showChatViewController:(TCChatViewController *)viewCtrl
{
	// > localQueue <
	
	// Remove current view
	[_currentView removeFromSuperview];
	
	if (!viewCtrl)
		return;
	
	// Load window if not loaded (else _chatView can eventually be nil).
	[self window];
	
	// Add the new one
	NSDictionary	*viewsDictionary;
	NSView			*content = viewCtrl.view;
	
	[_chatView addSubview:content];
	
	viewsDictionary = NSDictionaryOfVariableBindings(content);
	
	[_chatView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[content]|" options:0 metrics:nil views:viewsDictionary]];
	[_chatView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[content]|" options:0 metrics:nil views:viewsDictionary]];
	
	_currentView = content;
	
	[viewCtrl makeFirstResponder];
}

- (NSUInteger)_indexOfViewControllerForBuddy:(TCBuddy *)buddy
{
	// > localQueue <
	
	if (!buddy)
		return NSNotFound;
	
	return [_viewsCtrl indexOfObjectPassingTest:^BOOL(id _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		
		TCBuddy *tBuddy = [self _buddyAtIndex:idx];
		
		*stop = (tBuddy == buddy);
		
		return (tBuddy == buddy);
	}];
}

- (TCBuddy *)_buddyAtIndex:(NSUInteger)index
{
	// > localQueue <

	if (index >= [_viewsCtrl count])
		return nil;
	
	id item = _viewsCtrl[index];
	
	if ([item isKindOfClass:[TCChatViewController class]])
	{
		TCChatViewController *viewCtrl = item;

		return viewCtrl.buddy;
	}
	else
	{
		return item;
	}
}

@end
