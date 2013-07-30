/*
 *  TCPrefController.mm
 *
 *  Copyright 2012 Avérous Julien-Pierre
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



#import "TCPrefController.h"

#import "TCMainController.h"
#import "TCBuddiesController.h"

#include "TCConfig.h"



/*
** TCPrefController - Private
*/
#pragma mark - TCPrefController - Private

@interface TCPrefController ()
{
	TCPrefView	*currentView;
}

- (void)loadViewIdentifier:(NSString *)identifier animated:(BOOL)animated;

@end



/*
** TCPrefView - Private
*/
#pragma mark - TCPrefView - Private

@interface TCPrefView ()

@property (strong, nonatomic) id <TCConfig> config;

- (void)loadConfig;
- (void)saveConfig;

@end



/*
** TCPrefView_Network - Private
*/
#pragma mark - TCPrefView_Network - Private

@interface TCPrefView_Network ()
{
	BOOL changes;
}

@end



/*
** TCPrefController
*/
#pragma mark - TCPrefController

@implementation TCPrefController


/*
** TCPrefController - Constructor & Destructor
*/
#pragma mark - TCPrefController - Constructor & Destructor

+ (TCPrefController *)sharedController
{
	static dispatch_once_t	pred;
	static TCPrefController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCPrefController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super init];
	
    if (self)
	{
        // Load the nib
		[[NSBundle mainBundle] loadNibNamed:@"PreferencesWindow" owner:self topLevelObjects:nil];
    }
    
    return self;
}

- (void)awakeFromNib
{	
	// Place Window
	[_mainWindow center];
	[_mainWindow setFrameAutosaveName:@"PreferencesWindow"];
	
	// Select the default view
	[self loadViewIdentifier:@"general" animated:NO];
}



/*
** TCPrefController - Tools
*/
#pragma mark - TCPrefController - Tools

- (void)showWindow
{
	// Show window
	[_mainWindow makeKeyAndOrderFront:self];
}

- (void)loadViewIdentifier:(NSString *)identifier animated:(BOOL)animated
{
	TCPrefView		*view = nil;
	id <TCConfig>	config = [[TCMainController sharedController] config];

	if ([identifier isEqualToString:@"general"])
		view = _generalView;
	else if ([identifier isEqualToString:@"network"])
		view = _networkView;
	else if ([identifier isEqualToString:@"buddies"])
		view = _buddiesView;
	
	if (!view)
		return;
	
	// Check if the toolbar item is well selected
	if ([[[_mainWindow toolbar] selectedItemIdentifier] isEqualToString:identifier] == NO)
		[[_mainWindow toolbar] setSelectedItemIdentifier:identifier];
	
	// Save current view config
	currentView.config = config;
	[currentView saveConfig];
	
	// Load new view config
	view.config = config;
	[view loadConfig];
		
	// Load view
	if (animated)
	{
		NSRect	rect = [_mainWindow frame];
		NSSize	csize = [[_mainWindow contentView] frame].size;
		NSSize	size = [view frame].size;
		CGFloat	previous = rect.size.height;
		
		rect.size.width = (rect.size.width - csize.width) + size.width;
		rect.size.height = (rect.size.height - csize.height) + size.height;
				
		rect.origin.y += (previous - rect.size.height);
		
		[NSAnimationContext beginGrouping];
		{
			[[NSAnimationContext currentContext] setDuration:0.125];
			
			[[[_mainWindow contentView] animator] replaceSubview:currentView with:view];
			[[_mainWindow animator] setFrame:rect display:YES];
		}
		[NSAnimationContext endGrouping];
	}
	else
	{
		[currentView removeFromSuperview];
		[[_mainWindow contentView] addSubview:view];
	}
	
	// Hold the current view
	currentView = view;
}



/*
** TCPrefController - IBAction
*/
#pragma mark - TCPrefController - IBAction

- (IBAction)doToolbarItem:(id)sender
{
	NSToolbarItem	*item = sender;
	NSString		*identifier = [item itemIdentifier];
	
	[self loadViewIdentifier:identifier animated:YES];
}



/*
** TCPrefController - NSWindow
*/
#pragma mark - TCPrefController - NSWindow

- (void)windowWillClose:(NSNotification *)notification
{
	id <TCConfig> config = [[TCMainController sharedController] config];

	currentView.config = config;
	
	[currentView saveConfig];
}

@end



/*
** TCPrefView
*/
#pragma mark - TCPrefView

@implementation TCPrefView


/*
** TCPrefView - Config
*/
#pragma mark - TCPrefView - Config

- (void)loadConfig
{
	// Must be redefined
}

- (void)saveConfig
{
	// Must be redefined
}

@end



/*
** TCPrefView_General
*/
#pragma mark - TCPrefView_General

@implementation TCPrefView_General


/*
** TCPrefView_General - IBAction
*/
#pragma mark - TCPrefView_General - IBAction

- (IBAction)doDownload:(id)sender
{	
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:NO];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setCanCreateDirectories:YES];
	[openDlg setAllowsMultipleSelection:NO];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray		*urls = [openDlg URLs];
		NSURL		*url = [urls objectAtIndex:0];
		
		if (self.config)
		{
			[_downloadField setStringValue:[[url path] lastPathComponent]];
			
			[self.config setDownloadFolder:[url path]];
		}
		else
			NSBeep();
	}
}



/*
** TCPrefView_General - Config
*/
#pragma mark - TCPrefView_General - IBAction

- (void)loadConfig
{
	if (!self.config)
		return;
		
	[_downloadField setStringValue:[[self.config downloadFolder] lastPathComponent]];
	
	[[_clientNameField cell] setPlaceholderString:[self.config clientName:tc_config_get_default]];
	[[_clientVersionField cell] setPlaceholderString:[self.config clientVersion:tc_config_get_default]];

	[_clientNameField setStringValue:[self.config clientName:tc_config_get_defined]];
	[_clientVersionField setStringValue:[self.config clientVersion:tc_config_get_defined]];
}

- (void)saveConfig
{
	[self.config setClientName:[_clientNameField stringValue]];
	[self.config setClientVersion:[_clientVersionField stringValue]];
}

@end



/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@implementation TCPrefView_Network


/*
** TCPrefView_Network - TextField Delegate
*/
#pragma mark - TCPrefView_Network - TextField Delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	changes = YES;
}



/*
** TCPrefView_Network - Config
*/
#pragma mark - TCPrefView_Network - IBAction

- (void)loadConfig
{
	tc_config_mode mode;
	
	if (!self.config)
		return;
		
	mode = [self.config mode];
	
	// Set mode
	if (mode == tc_config_basic)
	{		
		[_imAddressField setEnabled:NO];
		[_imPortField setEnabled:NO];
		[_torAddressField setEnabled:NO];
		[_torPortField setEnabled:NO];
	}
	else if (mode == tc_config_advanced)
	{		
		[_imAddressField setEnabled:YES];
		[_imPortField setEnabled:YES];
		[_torAddressField setEnabled:YES];
		[_torPortField setEnabled:YES];
	}
	
	// Set value field
	[_imAddressField setStringValue:[self.config selfAddress]];
	[_imPortField setStringValue:[@([self.config clientPort]) description]];
	[_torAddressField setStringValue:[self.config torAddress]];
	[_torPortField setStringValue:[@([self.config torPort]) description]];
}

- (void)saveConfig
{	
	 if (!self.config)
		 return;
	 
	if ([self.config mode] == tc_config_advanced)
	{
		// Set config value
		[self.config setSelfAddress:[_imAddressField stringValue]];
		[self.config setClientPort:(uint16_t)[[_imPortField stringValue] intValue]];
		[self.config setTorAddress:[_torAddressField stringValue]];
		[self.config setTorPort:(uint16_t)[[_torPortField stringValue] intValue]];
		
		// Reload config
		if (changes)
		{
			[[TCBuddiesController sharedController] stop];
			[[TCBuddiesController sharedController] startWithConfiguration:self.config];
			
			changes = NO;
		}
	 }
}

@end



/*
** TCPrefView_Buddies
*/
#pragma mark - TCPrefView_Buddies

@implementation TCPrefView_Buddies


/*
** TCPrefView_Buddies - Config
*/
#pragma mark - TCPrefView_Buddies - Config

- (void)loadConfig
{
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
	
	[[NSApplication sharedApplication] beginSheet:_addBlockedWindow modalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}


- (IBAction)doAddBlockedCancel:(id)sender
{
	// Close
	[[NSApplication sharedApplication] endSheet:_addBlockedWindow];
	[_addBlockedWindow orderOut:self];
}

- (IBAction)doAddBlockedOK:(id)sender
{
	NSString	*address;
	
	if (!self.config)
		return;
	
	address = [_addBlockedField stringValue];
	
	// Add on controller
	// XXX Here, we break the fact that config is local to this view,
	//	and it will not necessarily the one used by the controller in the future.
	//	Try to find a better solution.
	if ([[TCBuddiesController sharedController] addBlockedBuddy:address] == NO)
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
		[[TCBuddiesController sharedController] removeBlockedBuddy:remove];
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
