/*
 *  TCPreferencesWindowController.m
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



#import "TCPreferencesWindowController.h"

#import "TCMainController.h"
#import "TCBuddiesWindowController.h"

#import "TCConfig.h"



/*
** TCPrefView
*/
#pragma mark - TCPrefView

@interface TCPrefView : NSView

@property (strong, nonatomic) id <TCConfig> config;

- (void)loadConfig;
- (void)saveConfig;

@end



/*
** TCPreferencesWindowController - Private
*/
#pragma mark - TCPreferencesWindowController - Private

@interface TCPreferencesWindowController ()
{
	TCPrefView	*_currentView;
}

@property (strong, nonatomic) IBOutlet TCPrefView	*generalView;
@property (strong, nonatomic) IBOutlet TCPrefView	*networkView;
@property (strong, nonatomic) IBOutlet TCPrefView	*buddiesView;

// -- IBAction --
- (IBAction)doToolbarItem:(id)sender;

// -- Helpers --
- (void)loadViewIdentifier:(NSString *)identifier animated:(BOOL)animated;

@end



/*
** TCPrefView_General
*/
#pragma mark - TCPrefView_General

@interface TCPrefView_General : TCPrefView

// -- Properties --
@property (strong, nonatomic) IBOutlet NSPathControl	*downloadPath;

@property (strong, nonatomic) IBOutlet NSTextField		*clientNameField;
@property (strong, nonatomic) IBOutlet NSTextField		*clientVersionField;


// -- IBAction --
- (IBAction)pathChanged:(id)sender;

@end



/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@interface TCPrefView_Network : TCPrefView
{
		BOOL changes;
}

@property (strong, nonatomic) IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*imPortField;
@property (strong, nonatomic) IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*torPortField;

@end



/*
** TCPrefView_Buddies
*/
#pragma mark - TCPrefView_Buddies

@interface TCPrefView_Buddies : TCPrefView

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
** TCPreferencesWindowController
*/
#pragma mark - TCPreferencesWindowController

@implementation TCPreferencesWindowController


/*
** TCPreferencesWindowController - Constructor & Destructor
*/
#pragma mark - TCPreferencesWindowController - Constructor & Destructor

+ (TCPreferencesWindowController *)sharedController
{
	static dispatch_once_t	pred;
	static TCPreferencesWindowController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCPreferencesWindowController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super initWithWindowNibName:@"PreferencesWindow"];
	
    if (self)
	{
    }
    
    return self;
}

- (void)windowDidLoad
{	
	// Place Window
	[self.window center];
	[self.window setFrameAutosaveName:@"PreferencesWindow"];
	
	// Select the default view
	[self loadViewIdentifier:@"general" animated:NO];
}



/*
** TCPreferencesWindowController - Tools
*/
#pragma mark - TCPreferencesWindowController - Tools

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
	if ([[[self.window toolbar] selectedItemIdentifier] isEqualToString:identifier] == NO)
		[[self.window toolbar] setSelectedItemIdentifier:identifier];
	
	// Save current view config
	_currentView.config = config;
	[_currentView saveConfig];
	
	// Load new view config
	view.config = config;
	[view loadConfig];
		
	// Load view
	if (animated)
	{
		NSRect	rect = [self.window frame];
		NSSize	csize = [[self.window contentView] frame].size;
		NSSize	size = [view frame].size;
		CGFloat	previous = rect.size.height;
		
		rect.size.width = (rect.size.width - csize.width) + size.width;
		rect.size.height = (rect.size.height - csize.height) + size.height;
				
		rect.origin.y += (previous - rect.size.height);
		
		[NSAnimationContext beginGrouping];
		{
			[[NSAnimationContext currentContext] setDuration:0.125];
			
			[[[self.window contentView] animator] replaceSubview:_currentView with:view];
			[[self.window animator] setFrame:rect display:YES];
		}
		[NSAnimationContext endGrouping];
	}
	else
	{
		[_currentView removeFromSuperview];
		[[self.window contentView] addSubview:view];
	}
	
	// Hold the current view
	_currentView = view;
}



/*
** TCPreferencesWindowController - IBAction
*/
#pragma mark - TCPreferencesWindowController - IBAction

- (IBAction)doToolbarItem:(id)sender
{
	NSToolbarItem	*item = sender;
	NSString		*identifier = [item itemIdentifier];
	
	[self loadViewIdentifier:identifier animated:YES];
}



/*
** TCPreferencesWindowController - NSWindow
*/
#pragma mark - TCPreferencesWindowController - NSWindow

- (void)windowWillClose:(NSNotification *)notification
{
	id <TCConfig> config = [[TCMainController sharedController] config];

	_currentView.config = config;
	
	[_currentView saveConfig];
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

- (IBAction)pathChanged:(id)sender
{
	NSString *path = [[_downloadPath URL] path];

	if (path)
		[self.config setDownloadFolder:path];
	else
		NSBeep();
}



/*
** TCPrefView_General - Config
*/
#pragma mark - TCPrefView_General - IBAction

- (void)loadConfig
{
	if (!self.config)
		return;

	// Download path.
	NSString *path = [self.config realPath:[self.config downloadFolder]];

	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	
	[_downloadPath setURL:[NSURL fileURLWithPath:path]];
	
	// Client info.
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
			[[TCBuddiesWindowController sharedController] stop];
			[[TCBuddiesWindowController sharedController] startWithConfiguration:self.config];
			
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
