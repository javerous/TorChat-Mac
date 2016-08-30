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


NS_ASSUME_NONNULL_BEGIN


/*
** TCChatEntry
*/
#pragma mark - TCChatEntry

@interface TCChatEntry : NSObject

@property (strong, nonatomic) TCBuddy				*buddy;
@property (strong, nonatomic) TCChatViewController	*viewController;

@property (strong, nonatomic, nullable) NSString	*lastMessage;

@property (strong, nonatomic) TCButtonContext		*buttonContext;

@end

@implementation TCChatEntry

@end



/*
** TCChatWindowController - Private
*/
#pragma mark - TCChatWindowController - Private

@interface TCChatWindowController () <TCCoreManagerObserver, TCBuddyObserver>
{
	id <TCConfigApp> _configuration;
	TCCoreManager	*_core;
	
	NSMutableArray	<TCChatEntry *> *_chatEntries;
	NSView			*_currentView;

	__weak TCBuddy *_selectedBuddy;
	
	NSMutableSet	*_buddies;
}

@property (strong, nonatomic) IBOutlet NSSplitView		*splitView;

@property (strong, nonatomic) IBOutlet NSView			*userView;
@property (strong, nonatomic) IBOutlet NSTableView		*userList;
@property (strong, nonatomic) IBOutlet NSProgressIndicator *userListLoading;

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

- (instancetype)initWithConfiguration:(id <TCConfigApp>)configuration coreManager:(TCCoreManager *)coreMananager
{
	self = [super initWithWindow:nil];
	
	if (self)
	{
		// Hold parameters.
		_configuration = configuration;
		_core = coreMananager;
		
		// Containers
		_chatEntries = [[NSMutableArray alloc] init];
		_buddies = [[NSMutableSet alloc] init];
		
		// Observe.
		[_core addObserver:self];
		
		// Get current buddies.
		NSArray *buddies = _core.buddies;
		
		for (TCBuddy *buddy in buddies)
		{
			[_buddies addObject:buddy];
			[buddy addObserver:self];
		}
	}
	
	return self;
}



/*
** TCChatWindowController - NSWindowController + NSWindowDelegate
*/
#pragma mark - TCChatWindowController - NSWindowController + NSWindowDelegate

- (nullable NSString *)windowNibName
{
	return @"ChatWindow";
}

- (id)owner
{
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// Place window.
	NSString *windowFrame = [_configuration generalSettingValueForKey:@"window-frame-chat"];
	
	if (windowFrame)
		[self.window setFrameFromString:windowFrame];
	else
		[self.window center];

	// Load transcripted buddies.
	[_userListLoading startAnimation:nil];

	[_configuration transcriptBuddiesIdentifiersWithCompletionHandler:^(NSArray *buddiesIdentifiers) {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			for (NSString *buddyIdentifier in buddiesIdentifiers)
			{
				TCBuddy *buddy = [_core buddyWithIdentifier:buddyIdentifier];
				
				if (!buddy)
					continue;
				
				[self _addChatWithBuddy:buddy select:NO];
			}
			
			[_userListLoading stopAnimation:nil];
		});
	}];
}

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	NSInteger index = _userList.selectedRow;
	
	if (index < 0 || index >= _chatEntries.count)
		return;
	
	// Clean last message.
	TCChatEntry *entry = _chatEntries[(NSUInteger)index];
	
	entry.lastMessage = nil;
	
	[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}



/*
** TCChatWindowController - Synchronize
*/
#pragma mark - TCChatWindowController - Synchronize

- (void)synchronizeWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[_configuration setGeneralSettingValue:self.window.stringWithSavedFrame forKey:@"window-frame-chat"];
		
		handler();

	});
}



/*
** TCChatWindowController - IBAction
*/
#pragma mark - TCChatWindowController - IBAction

- (IBAction)closeAction:(id)sender
{
	NSInteger index = [_userList rowForView:sender];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if (index < 0 || index >= _chatEntries.count)
			return;

		// Get selected view.
		TCChatEntry *entry = _chatEntries[(NSUInteger)index];
		
		if (entry.viewController == nil)
			return;
		
		// Validate the close if more than 0 message, as any close will delete the full conversation.
		TCChatViewController	*viewCtrl = entry.viewController;
		TCBuddy					*buddy = entry.buddy;
		
		if (viewCtrl.messagesCount > 0)
		{
			NSAlert *alert = [[NSAlert alloc] init];
			
			alert.messageText = NSLocalizedString(@"chat_want_close", @"");
			alert.informativeText = NSLocalizedString(@"chat_want_close_info", @"");
			
			[alert addButtonWithTitle:NSLocalizedString(@"chat_close", @"")];
			[alert addButtonWithTitle:NSLocalizedString(@"chat_cancel", @"")];
			
			[alert beginSheetModalForWindow:(NSWindow *)self.window completionHandler:^(NSModalResponse returnCode) {
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
** TCChatWindowController - Chat
*/
#pragma mark - TCChatWindowController - Chat

- (void)openChatWithBuddy:(nullable TCBuddy *)abuddy select:(BOOL)select
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCBuddy *buddy = abuddy;
		
		if (!buddy)
		{
			if (_selectedBuddy)
				buddy = _selectedBuddy;
			else if (_chatEntries.count > 0)
				buddy = _chatEntries[0].buddy;
		}
		
		[self _openChatWithBuddy:buddy select:select];
	});
}

- (void)_openChatWithBuddy:(nullable TCBuddy *)buddy select:(BOOL)select
{
	// > main queue <
	
	// Show window.
	[self showWindow:nil];
	
	if (!buddy)
		return;
	
	// Add chat.
	[self _addChatWithBuddy:buddy select:select];
}

- (void)_addChatWithBuddy:(TCBuddy *)buddy select:(BOOL)select
{
	// > main queue <
	
	NSAssert(buddy, @"buddy is nil");
	
	// Add view if necessary.
	if ([self _chatEntryForBuddy:buddy index:nil] == nil)
	{
		TCChatEntry *entry = [[TCChatEntry alloc] init];
		
		entry.buddy = buddy;
		entry.buttonContext = [TCButton createEmptyContext];
		
		[_chatEntries addObject:entry];
		[_userList reloadData];
	}
	
	// Select this chat if it's the first one.
	if (select)
		[self _selectChatWithBuddy:buddy];
}

- (void)closeChatWithBuddy:(TCBuddy *)buddy
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Search chat entry.
		NSUInteger index = NSNotFound;

		if ([self _chatEntryForBuddy:buddy index:&index] == nil)
			return;
		
		// Remove from view.
		[_chatEntries removeObjectAtIndex:index];
		[_userList reloadData];
		
		// Update selection.
		TCBuddy *selectedBuddy = _selectedBuddy;
		
		if (selectedBuddy == buddy)
		{
			NSUInteger nindex = index;
			
			if (_chatEntries.count == 0)
			{
				[self _showChatViewController:nil];
				
				_selectedBuddy = nil;
			}
			else
			{
				if (nindex >= _chatEntries.count)
					nindex = _chatEntries.count - 1;
				
				[self _selectChatWithBuddy:_chatEntries[nindex].buddy];
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
	return (NSInteger)_chatEntries.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Get associated buddy.
	
	if (rowIndex >= _chatEntries.count)
		return nil;
	
	// Get item.
	TCChatEntry	*entry = _chatEntries[(NSUInteger)rowIndex];
	TCBuddy		*buddy = entry.buddy;
	NSString	*lastMessage = entry.lastMessage;

	// Select the right view.
	TCChatCellView	*cellView = nil;
	
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
	NSString *name = buddy.finalName;
	
	if (name)
		rowContent[TCChatCellNameKey] = name;
	
	if (lastMessage)
		rowContent[TCChatCellChatTextKey] = lastMessage;
	
	// > Set close button status.
	NSPoint windowMouseLocation = self.window.mouseLocationOutsideOfEventStream;
	NSPoint mouseLocation = [tableView convertPoint:windowMouseLocation fromView:nil];

	rowContent[TCChatCellCloseKey] = @([tableView rowAtPoint:mouseLocation] == rowIndex);
		
	// Set content.
	cellView.content = rowContent;
	
	// Set action.
	__weak TCChatWindowController *weakSelf = self;
	
	if (cellView.closeButton.actionHandler == nil)
	{
		cellView.closeButton.actionHandler = ^(TCButton *button) {
			[weakSelf closeAction:button];
		};
	}
	
	// Set context.
	cellView.closeButton.context = entry.buttonContext;
	
	return cellView;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger rowIndex = _userList.selectedRow;

	if (rowIndex < 0 || rowIndex >= _chatEntries.count)
		return;
	
	TCChatEntry *entry = _chatEntries[(NSUInteger)rowIndex];

	[self _selectChatWithBuddy:entry.buddy];
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
				
				dispatch_async(dispatch_get_main_queue(), ^{
					for (TCChatEntry *entry in _chatEntries)
					{
						TCChatViewController *viewCtrl = entry.viewController;

						[viewCtrl setLocalAvatar:avatar];
					}
				});
				
				break;
			}
				
			case TCCoreEventBuddyNew:
			{
				TCBuddy *buddy = (TCBuddy *)info.context;
				
				[buddy addObserver:self];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[_buddies addObject:buddy];
				});

				break;
			}
				
			case TCCoreEventBuddyRemove:
			{
				TCBuddy *buddy = (TCBuddy *)info.context;
				
				[buddy removeObserver:self];
				
				dispatch_async(dispatch_get_main_queue(), ^{
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
					break;
				
				// Update table view.
				dispatch_async(dispatch_get_main_queue(), ^{
					
					NSUInteger	index = NSNotFound;
					TCChatEntry	*entry = [self _chatEntryForBuddy:buddy index:&index];
					
					if (!entry)
						return;
					
					[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
				});
				
				break;
			}
				
			case TCBuddyEventMessage:
			{
				NSString *message = info.context;
				
				if (!message)
					break;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					
					// Start a chat UI.
					[self _openChatWithBuddy:buddy select:(self.window.isVisible == NO)];
					
					// Show as unread if necessary.
					if (buddy != _selectedBuddy || self.window.keyWindow == NO)
					{
						NSUInteger	index = NSNotFound;
						TCChatEntry	*entry = [self _chatEntryForBuddy:buddy index:&index];
						
						if (entry)
						{
							entry.lastMessage = message;
							
							[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
						}
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
	// > main queue <
	
	NSAssert(buddy, @"buddy is nil");
	
	if (_selectedBuddy == buddy)
		return;
	
	// Search entry.
	NSUInteger	index = NSNotFound;
	TCChatEntry *entry = [self _chatEntryForBuddy:buddy index:&index];
	
	if (entry == nil)
		return;
	
	TCChatViewController *viewCtrl = entry.viewController;
	
	// Create view controler if necessary.
	if (viewCtrl == nil)
	{
		 // > Build chat view.
		 viewCtrl = [TCChatViewController chatViewWithBuddy:buddy configuration:_configuration];
		 
		 if (!viewCtrl)
			 return;
		
		entry.viewController = viewCtrl;
		
		 // > Configure view controller.
		 NSImage *localAvatar = [_core.profileAvatar imageRepresentation];
		 
		 if (!localAvatar)
			 localAvatar = [NSImage imageNamed:NSImageNameUser];
		 
		 [viewCtrl setLocalAvatar:localAvatar];
	}
	
	// Hold selection.
	_selectedBuddy = buddy;
	
	// Update selection.
	if (_userList.selectedRow != index)
		[_userList selectRowIndexes:[NSIndexSet indexSetWithIndex:index] byExtendingSelection:NO];
	
	// Show view.
	[self _showChatViewController:viewCtrl];
	
	// Clean unread.
	entry.lastMessage = nil;
	
	[_userList reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)_showChatViewController:(nullable TCChatViewController *)viewCtrl
{
	// > main queue <
	
	// Remove current view
	[_currentView removeFromSuperview];
	
	if (!viewCtrl)
		return;
	
	NSAssert(_chatView, @"add a chat controller on a window not loaded");

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

- (nullable TCChatEntry *)_chatEntryForBuddy:(TCBuddy *)buddy index:(nullable NSUInteger *)index
{
	// > main queue <
	
	NSAssert(buddy, @"buddy is nil");
	
	NSUInteger findex = [_chatEntries indexOfObjectPassingTest:^BOOL(TCChatEntry * _Nonnull entry, NSUInteger idx, BOOL * _Nonnull stop) {
		
		TCBuddy *tBuddy = entry.buddy;
		
		*stop = (tBuddy == buddy);
		
		return (tBuddy == buddy);
	}];
	
	if (findex == NSNotFound)
		return nil;
	
	if (index)
		*index = findex;
	
	return _chatEntries[findex];
}

@end


NS_ASSUME_NONNULL_END
