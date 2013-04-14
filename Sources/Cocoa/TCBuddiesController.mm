/*
 *  TCBuddiesController.mm
 *
 *  Copyright 2011 Avérous Julien-Pierre
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
#import "TCImageExtension.h"
#import "TCDropButton.h"

#include "TCController.h"
#include "TCBuddy.h"
#include "TCString.h"
#include "TCImage.h"
#include "TCNumber.h"



/*
** TCBuddiesController - Private
*/
#pragma mark -
#pragma mark TCBuddiesController - Private

@interface TCBuddiesController ()

- (void)doAvatarDrop:(NSImage *)avatar;

//- (void)reloadBuddyList:(BOOL)reselect;

- (void)updateStatusUI:(int)status;
- (void)updateTitleUI;

- (void)initDelegate;

@end



/*
** TCBuddiesController
*/
#pragma mark -
#pragma mark TCBuddiesController

@implementation TCBuddiesController


/*
** TCBuddiesController - Constructor & Destuctor
*/
#pragma mark -
#pragma mark TCBuddiesController - Constructor & Destuctor

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
	if ((self = [super init]))
	{
		// Build an event dispatch queue
		mainQueue = dispatch_queue_create("com.torchat.cocoa.buddies.main", NULL);
		
		// Build array of cocoa buddy
		buddies = [[NSMutableArray alloc] init];
		
		// Observe file events
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileCancel:) name:TCFileCellCancelNotify object:nil];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyStatusChanged:) name:TCCocoaBuddyChangedStatusNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyAvatarChanged:) name:TCCocoaBuddyChangedAvatarNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyNameChanged:) name:TCCocoaBuddyChangedNameNotification object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(buddyAliasChanged:) name:TCCocoaBuddyChangedAliasNotification object:nil];


		// Load interface bundle
		[NSBundle loadNibNamed:@"Buddies" owner:self];
	}
	return self;
}

- (void)dealloc
{
	TCDebugLog("TCBuddieController dealloc");
	
	[buddies release];
	
	control->release();
	config->release();
	
	dispatch_release(mainQueue);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}

- (void)awakeFromNib
{	
	// Place Window
	[mainWindow center];
	[mainWindow setFrameAutosaveName:@"BuddiesWindow"];
	
	// Configure table view
	[tableView setTarget:self];
	[tableView setDoubleAction:@selector(tableViewDoubleClick:)];
}



/*
** TCBuddiesController - Running
*/
#pragma mark -
#pragma mark TCBuddiesController - Running

- (void)startWithConfig:(TCConfig *)aConfig
{
	TCImage		*tavatar;
	NSImage		*avatar;
	
	if (!aConfig)
	{
		NSBeep();
		[NSApp terminate:self];
		return;
	}
	
	if (running)
		return;
	
	running = YES;
	
	// Hold the config
	aConfig->retain();
	config = aConfig;
	
	// Load tor
	if (config->get_mode() == tc_config_basic && [[TCTorManager sharedManager] isRunning] == NO)
		[[TCTorManager sharedManager] startWithConfig:config];
	
	// Build controller
	control = new TCController(config);
	
	
	// -- Init window content --
	
	// > Show load indicator
	[indicator startAnimation:self];

	// > Init title
	[self updateTitleUI];
	
	// > Init status
	[self updateStatusUI:control->status()];
	
	// > Init avatar
	tavatar = control->profileAvatar();
	avatar = [[NSImage alloc] initWithTCImage:tavatar];
	
	if ([[avatar representations] count] > 0)
		[imAvatar setImage:avatar];
	else
	{
		NSImage *img = [NSImage imageNamed:NSImageNameUser];
		
		[img setSize:NSMakeSize(64, 64)];
		 
		[imAvatar setImage:img];
	}
	
	[avatar release];
	tavatar->release();
	
	// > Init table file drag
	[tableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	[tableView setDraggingSourceOperationMask:NSDragOperationAll forLocal:NO];
	
	// > Redirect avatar drop
	[imAvatar setDropTarget:self withSelector:@selector(doAvatarDrop:)];

	
	// Show the window
	[mainWindow makeKeyAndOrderFront:self];
	
	// Init delegate
	[self initDelegate];
	
	// Start the controller
	control->start();
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
	[tableView reloadData];
	
	// Clean controller
	if (control)
	{
		control->setDelegate(NULL, NULL);
		
		control->stop();
		
		control->release();
		
		control = NULL;
	}
	
	// Clean config
	if (config)
	{
		config->release();
		config = NULL;
	}
	
	// Set status to offline
	[imStatus selectItemWithTag:-2];
	[self updateTitleUI];
	
	// Update status
	running = NO;
}



/*
** TCBuddiesController - TableView
*/
#pragma mark -
#pragma mark TCBuddiesController - TableView

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
	NSInteger	row = [tableView selectedRow];
	
	[imRemove setEnabled:(row >= 0)];

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
	NSInteger		row = [tableView clickedRow];
	TCCocoaBuddy	*buddy;

	if (row < 0 || row >= [buddies count])
		return;
	
	buddy = [buddies objectAtIndex:(NSUInteger)row];
	
	[buddy openChatWindow];
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
#pragma mark -
#pragma mark TCBuddiesController - Buddy

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
		
		// Release
		[temp_av release];
		[temp_aw release];
		[temp_xa release];
		[temp_off release];
		
		// Reload table
		[tableView reloadData];
	});
}

- (void)buddyAvatarChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{

		// Reload table
		[tableView reloadData];
	});
}

- (void)buddyNameChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Reload table
		[tableView reloadData];
	});
}

- (void)buddyAliasChanged:(NSNotification *)notice
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Reload table
		[tableView reloadData];
	});
}



/*
** TCBuddiesController - Files Notification
*/
#pragma mark -
#pragma mark TCBuddiesController - Files Notification

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
#pragma mark -
#pragma mark TCBuddiesController - IBAction

- (IBAction)doStatus:(id)sender
{
	// Change status
	switch ([imStatus selectedTag])
	{
		case -2:
			control->stop();
			[self updateStatusUI:-2];
			break;
			
		case 0:
			control->setStatus(tccontroller_available);
			break;
			
		case 1:
			control->setStatus(tccontroller_away);
			break;
			
		case 2:
			control->setStatus(tccontroller_xa);
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
		
		[avatar release];
	}
}

- (void)doAvatarDrop:(NSImage *)avatar
{
	TCImage *image = [avatar createTCImage];
	
	if (!image)
		return;
	
	control->setProfileAvatar(image);
	
	image->release();
}

- (IBAction)doTitle:(id)sender
{
	NSMenuItem	*selected = [imTitle selectedItem];
	NSInteger	tag = [selected tag];
	
	if (!selected)
	{
		NSBeep();
		return;
	}
	
	switch (tag)
	{
		case 0:
			config->set_mode_title(tc_config_title_name);
			break;
			
		case 1:
			config->set_mode_title(tc_config_title_address);
			break;
			
		case 3:
			[self doEditProfile:sender];			
			break;
	}
	
	[self updateTitleUI];
}

- (IBAction)doRemove:(id)sender
{
	NSInteger		row = [tableView selectedRow];
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
	[tableView reloadData];
	
	// Remove the buddy from the controller
	std::string addr([address UTF8String]);
					 
	control->removeBuddy(addr);
}

- (IBAction)doAdd:(id)sender
{
	[addNameField setStringValue:@""];
	[addAddressField setStringValue:@""];
	[[[addNotesField textStorage] mutableString] setString:@""];
	
	[addNameField becomeFirstResponder];
	
	[addWindow center];
	[addWindow makeKeyAndOrderFront:sender];
}

- (IBAction)doChat:(id)sender
{
	NSInteger		row = [tableView selectedRow];
	TCCocoaBuddy	*buddy;
	
	if (row < 0 || row >= [buddies count])
		return;

	buddy = [buddies objectAtIndex:(NSUInteger)row];
	
	[buddy openChatWindow];
}

- (IBAction)doSendFile:(id)sender
{
	NSInteger		row = [tableView selectedRow];
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

- (IBAction)doEditProfile:(id)sender
{
	TCString *tname = control->profileName();
	TCString *ttext = control->profileText();
	
	[profileName setStringValue:[NSString stringWithUTF8String:tname->content().c_str()]];
	[[[profileText textStorage] mutableString] setString:[NSString stringWithUTF8String:ttext->content().c_str()]];
	
	tname->release();
	ttext->release();
	
	[NSApp beginSheet:profileWindow modalForWindow:mainWindow modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)doAddOk:(id)sender
{
	NSString *notes = [[addNotesField textStorage] mutableString];
	
	std::string nameTxt([[addNameField stringValue] UTF8String]);
	std::string addressTxt([[addAddressField stringValue] UTF8String]);
	std::string notesTxt([notes UTF8String]);	
	
	// Add the buddy to the controller. Notification will add it on our interface.
	control->addBuddy(nameTxt, addressTxt, notesTxt);
	
	[addWindow orderOut:self];
}

- (IBAction)doAddCancel:(id)sender
{
	[addWindow orderOut:self];
}

- (IBAction)doProfileOk:(id)sender
{
	[NSApp endSheet:profileWindow];
	[profileWindow orderOut:self];
	
	// -- Hold name --
	NSString	*name = [profileName stringValue];
	const char	*cname = [name UTF8String];
	
	if (cname)
	{
		NSDictionary	*info = [NSDictionary dictionaryWithObject:name forKey:@"name"];
		TCString		*tname = new TCString(cname);
		
		control->setProfileName(tname);
		
		tname->release();
		
		[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerNameChanged object:self userInfo:info];
	}
	
	// -- Hold text --
	NSString	*text = [[profileText textStorage] mutableString];
	const char	*ctext = [text UTF8String];

	if (ctext)
	{
		NSDictionary	*info = [NSDictionary dictionaryWithObject:text forKey:@"text"];
		TCString		*ttext = new TCString(ctext);
		
		control->setProfileText(ttext);

		ttext->release();
		
		[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerTextChanged object:self userInfo:info];
	}
}

- (IBAction)doProfileCancel:(id)sender
{
	[NSApp endSheet:profileWindow];
	[profileWindow orderOut:self];
}

- (IBAction)showWindow:(id)sender
{
	[mainWindow makeKeyAndOrderFront:sender];
}



/*
** TCBuddiesController - Tools
*/
#pragma mark -
#pragma mark TCBuddiesController - Tools

- (TCCocoaBuddy *)selectedBuddy
{
	NSInteger row = [tableView selectedRow];
	
	if (row < 0 || row >= [buddies count])
		return nil;
	
	return [buddies objectAtIndex:(NSUInteger)row];
}

- (void)updateStatusUI:(int)status
{
	// Unselect old item
	for (NSMenuItem *item in [imStatus itemArray])
		[item setState:NSOffState];
	
	// Select the new item
	NSInteger index = [imStatus indexOfItemWithTag:status];
	
	if (index > -1)
	{
		NSMenuItem *select = [imStatus itemAtIndex:index];
		NSMenuItem *title = [imStatus itemAtIndex:0];
		
		[title setTitle:[select title]];
		[select setState:NSOnState];
		
		[imStatusImage setImage:[select image]];

		// Update popup-size
		NSSize	sz = [[select title] sizeWithAttributes:[NSDictionary dictionaryWithObject:[imStatus font] forKey:NSFontAttributeName]];
		NSRect	rect = [imStatus frame];
		
		rect.size.width = sz.width + 25;
		
		[imStatus setFrame:rect];
	}
}

- (void)updateTitleUI
{	
	NSString *content = @"-";
	
	if (config)
	{
		// Check the title to show
		switch (config->get_mode_title())
		{
			case tc_config_title_address:
			{
				content = [NSString stringWithUTF8String:config->get_self_address().c_str()];
				
				[[imTitle itemAtIndex:[imTitle indexOfItemWithTag:0]] setState:NSOffState];
				[[imTitle itemAtIndex:[imTitle indexOfItemWithTag:1]] setState:NSOnState];
				break;
			}
				
			case tc_config_title_name:
			{
				TCString *tname = control->profileName();
				
				content = [NSString stringWithUTF8String:tname->content().c_str()];
				
				if ([content length] == 0)
					content = @"-";
				
				tname->release();
				
				[[imTitle itemAtIndex:[imTitle indexOfItemWithTag:0]] setState:NSOnState];
				[[imTitle itemAtIndex:[imTitle indexOfItemWithTag:1]] setState:NSOffState];
				break;
			}
		}
	}
	else
	{
		[[imTitle itemAtIndex:[imTitle indexOfItemWithTag:0]] setState:NSOffState];
		[[imTitle itemAtIndex:[imTitle indexOfItemWithTag:1]] setState:NSOffState];
	}
	
	// Update popup-title
	[[imTitle itemAtIndex:0] setTitle:content];
	
	// Update popup-size
	NSSize	sz = [content sizeWithAttributes:[NSDictionary dictionaryWithObject:[imTitle font] forKey:NSFontAttributeName]];
	NSRect	rect = [imTitle frame];
	
	rect.size.width = sz.width + 14;
	
	
	[imTitle setFrame:rect];
}

- (void)initDelegate
{
	control->setDelegate(mainQueue, ^(TCController *controller, const TCInfo *info) {
		
		// Log the item
		[[TCLogsController sharedController] addGlobalLogEntry:[NSString stringWithUTF8String:info->render().c_str()]];
		
		// Action information
		switch (info->infoCode())
		{
			case tcctrl_notify_started:
			{
				dispatch_async(dispatch_get_main_queue(), ^{					
					[indicator stopAnimation:self];
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
				TCImage *image = dynamic_cast<TCImage *>(info->context());
				NSImage	*final = [[NSImage alloc] initWithTCImage:image];
				
				if ([[final representations] count] == 0)
				{
					[final release];
					
					final = [[NSImage imageNamed:NSImageNameUser] retain];
					
					[final setSize:NSMakeSize(64, 64)];
				}
					
				dispatch_async(dispatch_get_main_queue(), ^{
						
					NSDictionary *uinfo = [NSDictionary dictionaryWithObject:final forKey:@"avatar"];
					
					[imAvatar setImage:final];
	
					[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesControllerAvatarChanged object:self userInfo:uinfo];
					
					// Release
					[final release];
				});
				
				break;
			}
				
			case tcctrl_notify_profile_name:
			{
				// TCString *name = dynamic_cast<TCString *>(info->context());
								
				dispatch_async(dispatch_get_main_queue(), ^{
					
					// Reload table
					[tableView reloadData];
					
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
				TCBuddy			*buddy = dynamic_cast<TCBuddy *>(info->context());
				TCCocoaBuddy	*obuddy = [[TCCocoaBuddy alloc] initWithBuddy:buddy];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					
					[buddies addObject:obuddy];
					
					[obuddy setControllerAvatar:[imAvatar image]];
					[obuddy release];

					[tableView reloadData];
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
	});
}

@end
