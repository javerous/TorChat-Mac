/*
 *  TCBuddiesController.mm
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



#import "TCBuddiesController.h"

#import "TCConfig.h"
#import "TCCocoaBuddy.h"
#import "TCBuddyInfoController.h"
#import "TCBuddyCell.h"
#import "TCButton.h"

#import "TCFilesCommon.h"
#import "TCFilesController.h"

#import "TCLogsController.h"

#import "TCTorManager.h"
#import "TCDropButton.h"

#include "TCController.h"
#import "TCBuddy.h"
#include "TCString.h"
#include "TCImage.h"
#include "TCNumber.h"



/*
** TCBuddiesController - Private
*/
#pragma mark - TCBuddiesController - Private

@interface TCBuddiesController () <TCControllerDelegate>
{
	id <TCConfig>		_configuration;
	TCController		*control;
	
	dispatch_queue_t	mainQueue;
	
	NSMutableArray		*buddies;
	id					lastSelected;
	
	BOOL				running;
	
	NSDictionary		*infos;
}

- (void)doAvatarDrop:(NSImage *)avatar;

- (void)updateStatusUI:(int)status;
- (void)updateTitleUI;

@end



/*
** TCBuddiesController
*/
#pragma mark - TCBuddiesController

@implementation TCBuddiesController


/*
** TCBuddiesController - Constructor & Destuctor
*/
#pragma mark - TCBuddiesController - Constructor & Destuctor

+ (TCBuddiesController *)sharedController
{
	static dispatch_once_t		pred;
	static TCBuddiesController	*instance = nil;
		
	dispatch_once(&pred, ^{
		instance = [[TCBuddiesController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
		// Build an event dispatch queue
		mainQueue = dispatch_queue_create("com.torchat.cocoa.buddies.main", DISPATCH_QUEUE_SERIAL);
		
		// Build array of cocoa buddy
		buddies = [[NSMutableArray alloc] init];
		
		// Observe file events
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileCancel:) name:TCFileCellCancelNotify object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyStatusChanged:) name:TCCocoaBuddyChangedStatusNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyAvatarChanged:) name:TCCocoaBuddyChangedAvatarNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyNameChanged:) name:TCCocoaBuddyChangedNameNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyAliasChanged:) name:TCCocoaBuddyChangedAliasNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyBlockedChanged:) name:TCCocoaBuddyChangedBlockedNotification object:nil];

		// Load interface bundle
		[[NSBundle mainBundle] loadNibNamed:@"BuddiesWindow" owner:self topLevelObjects:nil];
	}
	return self;
}

- (void)dealloc
{
	TCDebugLog("TCBuddieController dealloc");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)awakeFromNib
{	
	// Place Window
	[_mainWindow center];
	[_mainWindow setFrameAutosaveName:@"BuddiesWindow"];
	
	// Configure table view
	[_tableView setTarget:self];
	[_tableView setDoubleAction:@selector(tableViewDoubleClick:)];
}



/*
** TCBuddiesController - Running
*/
#pragma mark - TCBuddiesController - Running

- (void)startWithConfiguration:(id <TCConfig>)configuration
{
	TCImage		*tavatar;
	NSImage		*avatar;
	
	if (!configuration)
	{
		NSBeep();
		[NSApp terminate:self];
		return;
	}
	
	if (running)
		return;
	
	running = YES;
	
	// Hold the config
	_configuration = configuration;
	
	// Load tor
	if ([_configuration mode] == tc_config_basic && [[TCTorManager sharedManager] isRunning] == NO)
		[[TCTorManager sharedManager] startWithConfiguration:_configuration];
	
	// Build controller
	control = [[TCController alloc] initWithConfiguration:_configuration];
	
	
	// -- Init window content --
	// > Show load indicator
	[_indicator startAnimation:self];

	// > Init title
	[self updateTitleUI];
	
	// > Init status
	[self updateStatusUI:[control status]];
	
	// > Init avatar
	tavatar = [control profileAvatar];
	avatar = [tavatar imageRepresentation];
	
	if ([[avatar representations] count] > 0)
		[_imAvatar setImage:avatar];
	else
	{
		NSImage *img = [NSImage imageNamed:NSImageNameUser];
		
		[img setSize:NSMakeSize(64, 64)];
		 
		[_imAvatar setImage:img];
	}
		
	// > Init table file drag
	[_tableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	[_tableView setDraggingSourceOperationMask:NSDragOperationAll forLocal:NO];
	
	// > Redirect avatar drop
	[_imAvatar setDropTarget:self withSelector:@selector(doAvatarDrop:)];

	
	// Show the window
	[_mainWindow makeKeyAndOrderFront:self];
	
	// Init delegate
	control.delegate = self;
	
	// Start the controller
	[control start];
}

- (void)stop
{
	if (!running)
		return;
	
	// Clean buddies
	for (TCCocoaBuddy *buddy in buddies)
	{
		// Yield the handled core item
		[buddy yieldCore];
		
		// Inform the info controller that we un-hold this buddy
		[TCBuddyInfoController removingBuddy:buddy];
	}
	
	[buddies removeAllObjects];
	[_tableView reloadData];
	
	// Clean controller
	if (control)
	{
		control.delegate = nil;
		
		[control stop];
		
		control = nil;
	}
	
	// Set status to offline
	[_imStatus selectItemWithTag:-2];
	[self updateTitleUI];
	
	// Update status
	running = NO;
}



/*
** TCBuddiesController - Blocked Buddies
*/
#pragma mark - TCBuddiesController - Blocked Buddies

- (BOOL)addBlockedBuddy:(NSString *)address
{
	// Add
	return [control addBlockedBuddy:address];
}

- (BOOL)removeBlockedBuddy:(NSString *)address
{
	// Remove
	return [control removeBlockedBuddy:address];
}



/*
** TCBuddiesController - TableView
*/
#pragma mark - TCBuddiesController - TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[buddies count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (rowIndex < 0 || rowIndex >= [buddies count])
		return nil;
	
	NSString		*identifier = [aTableColumn identifier];
	TCCocoaBuddy	*buddy = [buddies objectAtIndex:(NSUInteger)rowIndex];
	
	if ([identifier isEqualToString:@"state"])
	{
		if ([buddy blocked])
			return [NSImage imageNamed:@"blocked_buddy"];
		
		switch ([buddy status])
		{
			case tcbuddy_status_offline:
				return [NSImage imageNamed:@"stat_offline"];
				
			case tcbuddy_status_available:
				return [NSImage imageNamed:@"stat_online"];
				
			case tcbuddy_status_away:
				return [NSImage imageNamed:@"stat_away"];
				
			case tcbuddy_status_xa:
				return [NSImage imageNamed:@"stat_xa"];
		}
	}
	else if ([identifier isEqualToString:@"name"])
	{
		return [NSDictionary dictionaryWithObjectsAndKeys:	[buddy address],	TCBuddyCellAddressKey,
															[buddy finalName],	TCBuddyCellNameKey,
															nil];
		
		
	}
	else if ([identifier isEqualToString:@"avatar"])
	{
		return [buddy profileAvatar];
	}

	return nil;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger	row = [_tableView selectedRow];
	
	[_imRemove setEnabled:(row >= 0)];

	// Hold current selection (not perfect)
	if (row >= 0 && row < [buddies count])
		lastSelected = [buddies objectAtIndex:(NSUInteger)row];
	else
		lastSelected = nil;
	
	// Notify
	id				obj = (row >= 0 ? [buddies objectAtIndex:(NSUInteger)row] : [NSNull null]);
	NSDictionary	*content = [NSDictionary dictionaryWithObject:obj forKey:TCBuddiesControllerBuddyKey];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerSelectChanged object:self userInfo:content];	
}

- (void)tableViewDoubleClick:(id)sender
{
	NSInteger		row = [_tableView clickedRow];
	TCCocoaBuddy	*buddy;

	if (row < 0 || row >= [buddies count])
		return;
	
	buddy = [buddies objectAtIndex:(NSUInteger)row];
	
	[buddy startChatAndSelect:YES];
}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	if (operation == NSTableViewDropOn)
		return NSDragOperationMove;
	else
		return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
	NSPasteboard	*pboard = [info draggingPasteboard];
	NSArray			*types = [pboard types];
	NSArray			*fileList = [pboard propertyListForType:NSFilenamesPboardType];
	
	if (row < 0 || row >= [buddies count])
		return NO;
	
	TCCocoaBuddy	*buddy = [buddies objectAtIndex:(NSUInteger)row];
	
	if ([types containsObject:NSFilenamesPboardType])
	{
		NSFileManager *mng = [NSFileManager defaultManager];
		
		for (NSString *fileName in fileList)
		{
			BOOL isDirectory = NO;
			
			if ([mng fileExistsAtPath:fileName isDirectory:&isDirectory])
			{
				if (isDirectory)
					continue;
				
				[buddy sendFile:fileName];
			}
		}
		
		return YES;
	}
	
	return NO;
}



/*
** TCBuddiesController - Buddy
*/
#pragma mark - TCBuddiesController - Buddy

- (void)buddyStatusChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Sort buddies by status
		NSUInteger		i, cnt = [buddies count];
		NSMutableArray	*temp_off = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_av = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_aw = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_xa = [[NSMutableArray alloc] initWithCapacity:cnt];
		
		for (i = 0; i < cnt; i++)
		{
			TCCocoaBuddy *buddy = [buddies objectAtIndex:i];
			
			switch ([buddy status])
			{
				case tcbuddy_status_offline:
					[temp_off addObject:buddy];
					break;
					
				case tcbuddy_status_available:
					[temp_av addObject:buddy];
					break;
					
				case tcbuddy_status_away:
					[temp_aw addObject:buddy];
					break;
					
				case tcbuddy_status_xa:
					[temp_xa addObject:buddy];
					break;
			}
		}
		
		[buddies removeAllObjects];
		
		[buddies addObjectsFromArray:temp_av];
		[buddies addObjectsFromArray:temp_aw];
		[buddies addObjectsFromArray:temp_xa];
		[buddies addObjectsFromArray:temp_off];

		// Reload table
		[_tableView reloadData];
	});
}

- (void)buddyAvatarChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{

		// Reload table
		[_tableView reloadData];
	});
}

- (void)buddyNameChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Reload table
		[_tableView reloadData];
	});
}

- (void)buddyAliasChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Reload table
		[_tableView reloadData];
	});
}

- (void)buddyBlockedChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Reload table
		[_tableView reloadData];
	});
}



/*
** TCBuddiesController - TControllerDelegate
*/
#pragma mark - TCBuddiesController - TControllerDelegate

- (void)torchatController:(TCController *)controller information:(const TCInfo *)info
{
	// Log the item
	[[TCLogsController sharedController] addGlobalLogEntry:[NSString stringWithUTF8String:info->render().c_str()]];
	
	// Action information
	switch (info->infoCode())
	{
		case tcctrl_notify_started:
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[_indicator stopAnimation:self];
			});
			
			break;
		}
			
		case tcctrl_notify_stoped:
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateStatusUI:-2];
			});
			
			break;
		}
			
		case tcctrl_notify_status:
		{
			TCNumber			*nbr = dynamic_cast<TCNumber *>(info->context());
			tccontroller_status	status = (tccontroller_status)nbr->uint8Value();
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateStatusUI:status];
			});
			
			break;
		}
			
		case tcctrl_notify_profile_avatar:
		{
			TCImage *image = (__bridge TCImage *)(info->context());
			NSImage	*final = [image imageRepresentation];
			
			if ([[final representations] count] == 0)
			{
				final = [NSImage imageNamed:NSImageNameUser];
				
				[final setSize:NSMakeSize(64, 64)];
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				NSDictionary *uinfo = [NSDictionary dictionaryWithObject:final forKey:@"avatar"];
				
				[_imAvatar setImage:final];
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerAvatarChanged object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcctrl_notify_profile_name:
		{
			// TCString *name = dynamic_cast<TCString *>(info->context());
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				// Reload table
				[_tableView reloadData];
				
				// Update Title
				[self updateTitleUI];
			});
			
			break;
		}
			
		case tcctrl_notify_profile_text:
		{
			// TCString *text = dynamic_cast<TCString *>(info->context());
			
			break;
		}
			
		case tcctrl_notify_buddy_new:
		{
			TCBuddy			*buddy = (__bridge TCBuddy *)info->context();
			TCCocoaBuddy	*obuddy = [[TCCocoaBuddy alloc] initWithBuddy:buddy];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				[buddies addObject:obuddy];
				
				[obuddy setLocalAvatar:[_imAvatar image]];
				
				[_tableView reloadData];
			});
			
			break;
		}
			
		case tcctrl_notify_client_new:
			break;
			
		case tcctrl_notify_client_started:
			break;
			
		case tcctrl_notify_client_stoped:
			break;
	}
}



/*
** TCBuddiesController - Files Notification
*/
#pragma mark - TCBuddiesController - Files Notification

- (void)fileCancel:(NSNotification *)notice
{
	NSDictionary	*info = [notice userInfo];
	NSString		*uuid = [info objectForKey:@"uuid"];
	NSString		*address = [info objectForKey:@"address"];
	tcfile_way		way = (tcfile_way)[[info objectForKey:@"way"] intValue];
	
	// Search the buddy associated with this transfert
	for (TCCocoaBuddy *buddy in buddies)
	{
		if ([[buddy address] isEqualToString:address])
		{
			// Change the file status
			[[TCFilesController sharedController] setStatus:tcfile_status_cancel andTextStatus:NSLocalizedString(@"file_canceling", @"") forFileTransfert:uuid withWay:way];
			
			// Canceling the transfert
			if (way == tcfile_upload)
				[buddy cancelFileUpload:uuid];
			else if (way == tcfile_download)
				[buddy cancelFileDownload:uuid];
			
			return;
		}
	}
}



/*
** TCBuddiesController - IBAction
*/
#pragma mark - TCBuddiesController - IBAction

- (IBAction)doStatus:(id)sender
{
	// Change status
	switch ([_imStatus selectedTag])
	{
		case -2:
			[control stop];
			[self updateStatusUI:-2];
			break;
			
		case 0:
			[control setStatus:tccontroller_available];
			break;
			
		case 1:
			[control setStatus:tccontroller_away];
			break;
			
		case 2:
			[control setStatus:tccontroller_xa];
			break;
	}
}

- (IBAction)doAvatar:(id)sender
{
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:NO];
	[openDlg setAllowedFileTypes:[NSImage imageFileTypes]];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray	*urls = [openDlg URLs];
		NSImage *avatar = [[NSImage alloc] initWithContentsOfURL:[urls objectAtIndex:0]];

		[self doAvatarDrop:avatar];
	}
}

- (void)doAvatarDrop:(NSImage *)avatar
{
	TCImage *image = [[TCImage alloc] initWithImage:avatar];
	
	if (!image)
		return;
	
	[control setProfileAvatar:image];
}

- (IBAction)doTitle:(id)sender
{
	NSMenuItem	*selected = [_imTitle selectedItem];
	NSInteger	tag = [selected tag];
	
	if (!selected)
	{
		NSBeep();
		return;
	}
	
	switch (tag)
	{
		case 0:
			[_configuration setModeTitle:tc_config_title_name];
			break;
			
		case 1:
			[_configuration setModeTitle:tc_config_title_address];
			break;
			
		case 3:
			[self doEditProfile:sender];			
			break;
	}
	
	[self updateTitleUI];
}

- (IBAction)doRemove:(id)sender
{
	NSInteger		row = [_tableView selectedRow];
	TCCocoaBuddy	*buddy;
	NSString		*address;
	
	if (row < 0 || row >= [buddies count])
		return;
	
	// Get the buddy address
	buddy = [buddies objectAtIndex:(NSUInteger)row];
	address = [buddy address];
	
	// Inform the info controller that we are removing this buddy
	[TCBuddyInfoController removingBuddy:buddy];
	
	// Remove the buddy from interface side
	[buddy yieldCore];
	[buddies removeObjectAtIndex:(NSUInteger)row];
	[_tableView reloadData];
	
	// Remove the buddy from the controller
	[control removeBuddy:address];
}

- (IBAction)doAdd:(id)sender
{
	[_addNameField setStringValue:@""];
	[_addAddressField setStringValue:@""];
	[[[_addNotesField textStorage] mutableString] setString:@""];
	
	[_addNameField becomeFirstResponder];
	
	[_addWindow center];
	[_addWindow makeKeyAndOrderFront:sender];
}

- (IBAction)doChat:(id)sender
{
	NSInteger		row = [_tableView selectedRow];
	TCCocoaBuddy	*buddy;
	
	if (row < 0 || row >= [buddies count])
		return;

	buddy = [buddies objectAtIndex:(NSUInteger)row];
	
	[buddy startChatAndSelect:YES];
}

- (IBAction)doSendFile:(id)sender
{
	NSInteger		row = [_tableView selectedRow];
	TCCocoaBuddy	*buddy;
	
	if (row < 0 || row >= [buddies count])
		return;
	
	buddy = [buddies objectAtIndex:(NSUInteger)row];
	
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:YES];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray *urls = [openDlg URLs];

		for (NSURL *url in urls)
			[buddy sendFile:[url path]];
	}
}

- (IBAction)doToggleBlock:(id)sender
{
	NSInteger		row = [_tableView selectedRow];
	TCCocoaBuddy	*buddy;
	
	if (row < 0 || row >= [buddies count])
		return;
	
	buddy = [buddies objectAtIndex:(NSUInteger)row];
		
	if ([buddy blocked])
		[control removeBlockedBuddy:[buddy address]];
	else
		[control addBlockedBuddy:[buddy address]];
}

- (IBAction)doEditProfile:(id)sender
{
	NSString *tname = [control profileName];
	NSString *ttext = [control profileText];
	
	[_profileName setStringValue:tname];
	[[[_profileText textStorage] mutableString] setString:ttext];
	
	[NSApp beginSheet:_profileWindow modalForWindow:_mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)doAddOk:(id)sender
{
	NSString *notes = [[_addNotesField textStorage] mutableString];

	// Add the buddy to the controller. Notification will add it on our interface.
	[control addBuddy:[_addNameField stringValue] address:[_addAddressField stringValue] comment:notes];
	
	[_addWindow orderOut:self];
}

- (IBAction)doAddCancel:(id)sender
{
	[_addWindow orderOut:self];
}

- (IBAction)doProfileOk:(id)sender
{
	[NSApp endSheet:_profileWindow];
	[_profileWindow orderOut:self];
	
	// -- Hold name --
	NSString *name = [_profileName stringValue];
	
	[control setProfileName:name];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerNameChanged object:self userInfo:@{ @"name" : name }];
	
	
	// -- Hold text --
	NSString *text = [[_profileText textStorage] mutableString];
	
	[control setProfileText:text];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerTextChanged object:self userInfo:@{ @"text" : text }];

}

- (IBAction)doProfileCancel:(id)sender
{
	[NSApp endSheet:_profileWindow];
	[_profileWindow orderOut:self];
}

- (IBAction)showWindow:(id)sender
{
	[_mainWindow makeKeyAndOrderFront:sender];
}



/*
** TCBuddiesController - Tools
*/
#pragma mark - TCBuddiesController - Tools

- (TCCocoaBuddy *)selectedBuddy
{
	NSInteger row = [_tableView selectedRow];
	
	if (row < 0 || row >= [buddies count])
		return nil;
	
	return [buddies objectAtIndex:(NSUInteger)row];
}

- (void)updateStatusUI:(int)status
{
	// Unselect old item
	for (NSMenuItem *item in [_imStatus itemArray])
		[item setState:NSOffState];
	
	// Select the new item
	NSInteger index = [_imStatus indexOfItemWithTag:status];
	
	if (index > -1)
	{
		NSMenuItem *select = [_imStatus itemAtIndex:index];
		NSMenuItem *title = [_imStatus itemAtIndex:0];
		
		[title setTitle:[select title]];
		[select setState:NSOnState];
		
		[_imStatusImage setImage:[select image]];

		// Update popup-size
		NSSize	sz = [[select title] sizeWithAttributes:[NSDictionary dictionaryWithObject:[_imStatus font] forKey:NSFontAttributeName]];
		NSRect	rect = [_imStatus frame];
		
		rect.size.width = sz.width + 25;
		
		[_imStatus setFrame:rect];
	}
}

- (void)updateTitleUI
{	
	NSString *content = @"-";
	
	if (_configuration)
	{
		// Check the title to show
		switch ([_configuration modeTitle])
		{
			case tc_config_title_address:
			{
				content = [_configuration selfAddress];
				
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]] setState:NSOffState];
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]] setState:NSOnState];
				break;
			}
				
			case tc_config_title_name:
			{
				content = [control profileName];
				
				if ([content length] == 0)
					content = @"-";
								
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]] setState:NSOnState];
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]] setState:NSOffState];
				break;
			}
		}
	}
	else
	{
		[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]] setState:NSOffState];
		[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]] setState:NSOffState];
	}
	
	// Update popup-title
	[[_imTitle itemAtIndex:0] setTitle:content];
	
	// Update popup-size
	NSSize	sz = [content sizeWithAttributes:[NSDictionary dictionaryWithObject:[_imTitle font] forKey:NSFontAttributeName]];
	NSRect	rect = [_imTitle frame];
	
	rect.size.width = sz.width + 14;
	
	[_imTitle setFrame:rect];
}

@end
