<<<<<<< HEAD
//
//  TCPrefsView_Buddies.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2015 SourceMac. All rights reserved.
//

#import "TCPrefView_Buddies.h"

#import "TCBuddiesWindowController.h"

=======
/*
 *  TCPrefView_Buddies.m
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

#import "TCPrefView_Buddies.h"

#import "TCCoreManager.h"
>>>>>>> javerous/master


/*
** TCPrefView_Buddies - Private
*/
#pragma mark - TCPrefView_Buddies - Private

<<<<<<< HEAD
@interface TCPrefView_Buddies ()
=======
@interface TCPrefView_Buddies () <TCCoreManagerObserver>
>>>>>>> javerous/master

@property (strong, nonatomic) IBOutlet NSTableView	*tableView;
@property (strong, nonatomic) IBOutlet NSButton		*removeButton;

@property (strong, nonatomic) IBOutlet NSWindow		*addBlockedWindow;
@property (strong, nonatomic) IBOutlet NSTextField	*addBlockedField;

- (IBAction)doAddBlockedUser:(id)sender;
- (IBAction)doRemoveBlockedUser:(id)sender;

- (IBAction)doAddBlockedCancel:(id)sender;
- (IBAction)doAddBlockedOK:(id)sender;

@end



/*
** TCPrefView_Buddies
*/
#pragma mark - TCPrefView_Buddies

@implementation TCPrefView_Buddies


/*
** TCPrefView_Buddies - Instance
*/
#pragma mark - TCPrefView_Buddies - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_Buddies" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}



/*
** TCPrefView_Buddies - TCPrefView
*/
#pragma mark - TCPrefView_Buddies - TCPrefView

- (void)loadConfig
{
	// Load view.
	[self view];
	
<<<<<<< HEAD
	// Register notifications.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyBlockedChanged:) name:TCCocoaBuddyChangedBlockedNotification object:nil];
}

- (void)saveConfig
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
=======
	// Observe core info.
	[self.core addObserver:self];
}

- (BOOL)saveConfig
{
	[self.core removeObserver:self];
	
	return NO;
>>>>>>> javerous/master
}



/*
** TCPrefView_Buddies - IBAction
*/
#pragma mark - TCPrefView_Buddies - IBAction

- (IBAction)doAddBlockedUser:(id)sender
{
	if (!self.config)
		return;
	
	// Show add window
	[_addBlockedField setStringValue:@""];
	
<<<<<<< HEAD
	[[NSApplication sharedApplication] beginSheet:_addBlockedWindow modalForWindow:self.view.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
=======
	[self.view.window beginSheet:_addBlockedWindow completionHandler:nil];
>>>>>>> javerous/master
}


- (IBAction)doAddBlockedCancel:(id)sender
{
<<<<<<< HEAD
	// Close
	[[NSApplication sharedApplication] endSheet:_addBlockedWindow];
	[_addBlockedWindow orderOut:self];
=======
	[self.view.window endSheet:_addBlockedWindow];
>>>>>>> javerous/master
}

- (IBAction)doAddBlockedOK:(id)sender
{
	NSString *address;
	
	if (!self.config)
		return;
	
	address = [_addBlockedField stringValue];
	
<<<<<<< HEAD
	// Add on controller
	// XXX Here, we break the fact that config is local to this view,
	//	and it will not necessarily the one used by the controller in the future.
	//	Try to find a better solution.
	if ([[TCBuddiesWindowController sharedController] addBlockedBuddy:address] == NO)
	{
		NSBeep();
	}
	else
	{
		// Reload
		[_tableView reloadData];
		
		// Close
		[[NSApplication sharedApplication] endSheet:_addBlockedWindow];
		[_addBlockedWindow orderOut:self];
	}
=======
	// Add on blocked list.
	if ([self.core addBlockedBuddy:address] == NO)
	{
		NSBeep();
		return;
	}
	
	// Reload list.
	[_tableView reloadData];
		
	// Close.
	[self.view.window endSheet:_addBlockedWindow];
>>>>>>> javerous/master
}

- (IBAction)doRemoveBlockedUser:(id)sender
{
	if (!self.config)
		return;
	
	NSArray			*blocked = [self.config blockedBuddies];
	NSIndexSet		*set = [_tableView selectedRowIndexes];
	NSMutableArray	*removes = [NSMutableArray arrayWithCapacity:[set count]];
	NSUInteger		index = [set firstIndex];
	
<<<<<<< HEAD
	// Resolve indexes
	while (index != NSNotFound)
	{
		// Add to address to remove
=======
	// Resolve indexes.
	while (index != NSNotFound)
	{
		// Add to address to remove.
>>>>>>> javerous/master
		NSString *address = blocked[index];
		
		[removes addObject:address];
		
<<<<<<< HEAD
		// Next index
		index = [set indexGreaterThanIndex:index];
	}
	
	// Remove
	for (NSString *remove in removes)
	{
		// Remove on controller
		// XXX Here, we break the fact that config is local to this view,
		//	and it will not necessarily the one used by the controller in the future.
		//	Try to find a better solution.
		[[TCBuddiesWindowController sharedController] removeBlockedBuddy:remove];
	}
	
	// Reload list
	[_tableView reloadData];
}

- (void)buddyBlockedChanged:(NSNotification *)notice
{
	// Reload list
	[_tableView reloadData];
=======
		// Next index.
		index = [set indexGreaterThanIndex:index];
	}
	
	// Remove from blocked list.
	for (NSString *remove in removes)
		[self.core removeBlockedBuddy:remove];
	
	// Reload list.
	[_tableView reloadData];
}


/*
** TCPrefView_Buddies - TCCoreManagerObserver
*/
#pragma mark - TCPrefView_Buddies - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(TCInfo *)info
{
	if (info.kind == TCInfoInfo && (info.code == TCCoreEventBuddyBlocked || info.code == TCCoreEventBuddyUnblocked))
	{
		dispatch_async(dispatch_get_main_queue(), ^{
			[_tableView reloadData];
		});
	}
>>>>>>> javerous/master
}



/*
<<<<<<< HEAD
** TCPrefView_Buddies - TableView Delegate
*/
#pragma mark - TCPrefView_Buddies - TableView Delegate
=======
** TCPrefView_Buddies - NSTableViewDelegate
*/
#pragma mark - TCPrefView_Buddies - NSTableViewDelegate
>>>>>>> javerous/master

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (!self.config)
		return 0;
	
	return (NSInteger)[[self.config blockedBuddies] count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (!self.config)
		return nil;
	
	NSArray *blocked = [self.config blockedBuddies];
	
	if (rowIndex < 0 || rowIndex >= [blocked count])
		return nil;
	
	return blocked[(NSUInteger)rowIndex];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSIndexSet *set = [_tableView selectedRowIndexes];
	
	if ([set count] > 0)
		[_removeButton setEnabled:YES];
	else
		[_removeButton setEnabled:NO];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

@end
