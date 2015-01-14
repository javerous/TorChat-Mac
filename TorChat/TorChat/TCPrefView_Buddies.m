//
//  TCPrefsView_Buddies.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2015 SourceMac. All rights reserved.
//

#import "TCPrefView_Buddies.h"

#import "TCBuddiesWindowController.h"



/*
** TCPrefView_Buddies - Private
*/
#pragma mark - TCPrefView_Buddies - Private

@interface TCPrefView_Buddies ()

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
	
	// Register notifications.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyBlockedChanged:) name:TCCocoaBuddyChangedBlockedNotification object:nil];
}

- (void)saveConfig
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
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
	
	[[NSApplication sharedApplication] beginSheet:_addBlockedWindow modalForWindow:self.view.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)doAddBlockedCancel:(id)sender
{
	// Close
	[[NSApplication sharedApplication] endSheet:_addBlockedWindow];
	[_addBlockedWindow orderOut:self];
}

- (IBAction)doAddBlockedOK:(id)sender
{
	NSString *address;
	
	if (!self.config)
		return;
	
	address = [_addBlockedField stringValue];
	
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
}

- (IBAction)doRemoveBlockedUser:(id)sender
{
	if (!self.config)
		return;
	
	NSArray			*blocked = [self.config blockedBuddies];
	NSIndexSet		*set = [_tableView selectedRowIndexes];
	NSMutableArray	*removes = [NSMutableArray arrayWithCapacity:[set count]];
	NSUInteger		index = [set firstIndex];
	
	// Resolve indexes
	while (index != NSNotFound)
	{
		// Add to address to remove
		NSString *address = blocked[index];
		
		[removes addObject:address];
		
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
}



/*
** TCPrefView_Buddies - TableView Delegate
*/
#pragma mark - TCPrefView_Buddies - TableView Delegate

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
