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


/*
** TCPrefView_Buddies - Private
*/
#pragma mark - TCPrefView_Buddies - Private

@interface TCPrefView_Buddies () <TCCoreManagerObserver>

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
	
	// Observe core info.
	[self.core addObserver:self];
}

- (BOOL)saveConfig
{
	[self.core removeObserver:self];
	
	return NO;
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
	
	[self.view.window beginSheet:_addBlockedWindow completionHandler:nil];
}


- (IBAction)doAddBlockedCancel:(id)sender
{
	[self.view.window endSheet:_addBlockedWindow];
}

- (IBAction)doAddBlockedOK:(id)sender
{
	NSString *address;
	
	if (!self.config)
		return;
	
	address = [_addBlockedField stringValue];
	
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
}

- (IBAction)doRemoveBlockedUser:(id)sender
{
	if (!self.config)
		return;
	
	NSArray			*blocked = [self.config blockedBuddies];
	NSIndexSet		*set = [_tableView selectedRowIndexes];
	NSMutableArray	*removes = [NSMutableArray arrayWithCapacity:[set count]];
	NSUInteger		index = [set firstIndex];
	
	// Resolve indexes.
	while (index != NSNotFound)
	{
		// Add to address to remove.
		NSString *address = blocked[index];
		
		[removes addObject:address];
		
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
}



/*
** TCPrefView_Buddies - NSTableViewDelegate
*/
#pragma mark - TCPrefView_Buddies - NSTableViewDelegate

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
