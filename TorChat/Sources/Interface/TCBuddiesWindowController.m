/*
 *  TCBuddiesController.m
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


#import "TCBuddiesWindowController.h"

// -- Core --
#import "TCCoreManager.h"
#import "TCConfig.h"
#import "TCBuddy.h"
#import "TCImage.h"

// > Tools
#import "TCDebugLog.h"

// -- Interface --
// > Controllers
#import "TCBuddyInfoWindowController.h"
#import "TCChatWindowController.h"
#import "TCFilesWindowController.h"

// > Cells
#import "TCBuddyCellView.h"

// > Views
#import "TCButton.h"
#import "TCDropButton.h"
#import "TCThreePartImageView.h"

// > Managers
#import "TCLogsManager.h"
#import "TCTorManager.h"

// > Components
#import "TCFilesCommon.h"



/*
** TCBuddiesController - Private
*/
#pragma mark - TCBuddiesController - Private

@interface TCBuddiesWindowController () <TCCoreManagerDelegate, TCDropButtonDelegate, TCBuddyDelegate, TCChatWindowControllerDelegate>
{
	id <TCConfig>		_configuration;
	TCCoreManager		*_control;
	
	dispatch_queue_t	_localQueue;
	dispatch_queue_t	_noticeQueue;

	NSMutableArray		*_buddies;
	id					_lastSelected;
	
	BOOL				_running;
	
	NSDictionary		*_infos;
}

// -- Properties --
@property (strong, nonatomic) IBOutlet NSProgressIndicator	*indicator;
@property (strong, nonatomic) IBOutlet NSTableView			*tableView;
@property (strong, nonatomic) IBOutlet NSPopUpButton		*imTitle;
@property (strong, nonatomic) IBOutlet NSButton				*imRemove;
@property (strong, nonatomic) IBOutlet NSPopUpButton		*imStatus;
@property (strong, nonatomic) IBOutlet NSImageView			*imStatusImage;
@property (strong, nonatomic) IBOutlet TCDropButton			*imAvatar;
@property (strong, nonatomic) IBOutlet TCThreePartImageView *barView;

@property (strong, nonatomic) IBOutlet NSWindow				*addWindow;
@property (strong, nonatomic) IBOutlet NSTextField			*addNameField;
@property (strong, nonatomic) IBOutlet NSTextField			*addAddressField;
@property (strong, nonatomic) IBOutlet NSTextView			*addNotesField;

@property (strong, nonatomic) IBOutlet NSWindow				*profileWindow;
@property (strong, nonatomic) IBOutlet NSTextField			*profileName;
@property (strong, nonatomic) IBOutlet NSTextView			*profileText;

// -- IBAction --
- (IBAction)doStatus:(id)sender;
- (IBAction)doAvatar:(id)sender;
- (IBAction)doTitle:(id)sender;


- (IBAction)doAddOk:(id)sender;
- (IBAction)doAddCancel:(id)sender;

- (IBAction)doProfileOk:(id)sender;
- (IBAction)doProfileCancel:(id)sender;

// -- Helpers --
- (void)updateStatusUI:(int)status;
- (void)updateTitleUI;

@end



/*
** TCBuddiesController
*/
#pragma mark - TCBuddiesController

@implementation TCBuddiesWindowController


/*
** TCBuddiesController - Constructor & Destuctor
*/
#pragma mark - TCBuddiesController - Constructor & Destuctor

+ (TCBuddiesWindowController *)sharedController
{
	static dispatch_once_t		pred;
	static TCBuddiesWindowController	*instance = nil;
		
	dispatch_once(&pred, ^{
		instance = [[TCBuddiesWindowController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super initWithWindowNibName:@"BuddiesWindow"];
	
	if (self)
	{
		// Build an event dispatch queue
		_localQueue = dispatch_queue_create("com.torchat.cocoa.buddies.local", DISPATCH_QUEUE_SERIAL);
		_noticeQueue = dispatch_queue_create("com.torchat.cocoa.buddies.notice", DISPATCH_QUEUE_SERIAL);

		// Build array of cocoa buddy
		_buddies = [[NSMutableArray alloc] init];
		
		// Observe file events
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(fileCancel:) name:TCFileCancelNotification object:nil];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog("TCBuddieController dealloc");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
	// Place Window.
	[self.window center];
	[self.window setFrameAutosaveName:@"BuddiesWindow"];
	
	// Configure table view.
	[_tableView setTarget:self];
	[_tableView setDoubleAction:@selector(tableViewDoubleClick:)];
	
	// Configura bar.
	_barView.startCap = [NSImage imageNamed:@"bar"];
	_barView.centerFill = [NSImage imageNamed:@"bar"];
	_barView.endCap = [NSImage imageNamed:@"bar"];
}



/*
** TCBuddiesController - Running
*/
#pragma mark - TCBuddiesController - Running

- (void)startWithConfiguration:(id <TCConfig>)configuration
{
	NSImage *avatar;
	
	if (!configuration)
	{
		NSBeep();
		[NSApp terminate:self];
		return;
	}
	
	if (_running)
		return;
	
	_running = YES;
	
	// Load window.
	[self window];
	
	// Hold the config
	_configuration = configuration;
	
	// Load tor
	if ([_configuration mode] == tc_config_basic && [[TCTorManager sharedManager] isRunning] == NO)
		[[TCTorManager sharedManager] startWithConfiguration:_configuration];
	
	// Build controller
	_control = [[TCCoreManager alloc] initWithConfiguration:_configuration];
	
	
	// -- Init window content --
	// > Show load indicator
	[_indicator startAnimation:self];

	// > Init title
	[self updateTitleUI];
	
	// > Init status
	[self updateStatusUI:[_control status]];
	
	// > Init avatar
	avatar = [[_control profileAvatar] imageRepresentation];
	
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
	[_tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	
	// > Redirect avatar drop
	[_imAvatar setDelegate:self];

	// Show the window
	[self showWindow:nil];
	
	// Init delegate
	_control.delegate = self;
	
	// Start the controller
	[_control start];
}

- (void)stop
{
	if (!_running)
		return;
	
	// Clean buddies
	for (TCBuddy *buddy in _buddies)
	{
		buddy.delegate = nil;
		
		// Inform the info controller that we un-hold this buddy.
		dispatch_async(_noticeQueue, ^{
			[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesWindowControllerRemovedBuddy object:self userInfo:@{ @"buddy" : buddy }];
		});
	}
	
	[_buddies removeAllObjects];
	[_tableView reloadData];
	
	// Clean controller
	if (_control)
	{
		_control.delegate = nil;
		
		[_control stop];
		
		_control = nil;
	}
	
	// Set status to offline
	[_imStatus selectItemWithTag:0];
	[self updateTitleUI];
	
	// Update status
	_running = NO;
}



/*
** TCBuddiesController - Blocked Buddies
*/
#pragma mark - TCBuddiesController - Blocked Buddies

- (BOOL)addBlockedBuddy:(NSString *)address
{
	// Add
	return [_control addBlockedBuddy:address];
}

- (BOOL)removeBlockedBuddy:(NSString *)address
{
	// Remove
	return [_control removeBlockedBuddy:address];
}



/*
** TCBuddiesController - TableView
*/
#pragma mark - TCBuddiesController - TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[_buddies count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	TCBuddyCellView	*cellView = nil;
	TCBuddy			*buddy = [_buddies objectAtIndex:(NSUInteger)rowIndex];
	NSString		*name = [buddy finalName];
	
	if ([name length] > 0)
		cellView = [tableView makeViewWithIdentifier:@"buddy_name" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"buddy_address" owner:self];
	
	[cellView setBuddy:buddy];
	
	return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger	row = [_tableView selectedRow];
	
	[_imRemove setEnabled:(row >= 0)];

	// Hold current selection (not perfect).
	if (row >= 0 && row < [_buddies count])
		_lastSelected = [_buddies objectAtIndex:(NSUInteger)row];
	else
		_lastSelected = nil;
	
	// Notify.
	id obj = (row >= 0 ? [_buddies objectAtIndex:(NSUInteger)row] : [NSNull null]);
	
	dispatch_async(_noticeQueue, ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesWindowControllerSelectChanged object:self userInfo:@{ TCBuddiesWindowControllerBuddyKey : obj }];
	});
}

- (void)tableViewDoubleClick:(id)sender
{
	NSInteger	row = [_tableView clickedRow];
	TCBuddy		*buddy;

	// Get the double-clicked button
	if (row < 0 || row >= [_buddies count])
		return;
	
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	
	// Open a chat window.
	[self startChatForBuddy:buddy select:YES];
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
	if (row < 0 || row >= [_buddies count])
		return NO;
	
	TCBuddy			*buddy = [_buddies objectAtIndex:(NSUInteger)row];
	NSPasteboard	*pboard = [info draggingPasteboard];
	NSArray			*types = [pboard types];
	
	if ([types containsObject:NSFilenamesPboardType])
	{
		NSFileManager	*mng = [NSFileManager defaultManager];
		NSArray			*fileList = [pboard propertyListForType:NSFilenamesPboardType];

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
** TCBuddiesController - TCCoreManagerDelegate
*/
#pragma mark - TCBuddiesController - TCCoreManagerDelegate

- (void)torchatManager:(TCCoreManager *)manager information:(TCInfo *)info
{
	// Log the item
	[[TCLogsManager sharedManager] addGlobalLogEntry:[info render]];
	
	// Action information
	switch (info.infoCode)
	{
		case tccore_notify_started:
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[_indicator stopAnimation:self];
			});
			
			break;
		}
			
		case tccore_notify_stoped:
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateStatusUI:-2];
			});
			
			break;
		}
			
		case tccore_notify_status:
		{
			tcstatus	status = (tcstatus)[(NSNumber *)info.context intValue];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[self updateStatusUI:status];
			});
			
			break;
		}
			
		case tccore_notify_profile_avatar:
		{
			TCImage	*tcFinal = (TCImage *)info.context;
			NSImage	*final = [tcFinal imageRepresentation];
			
			if (!final)
				final = [NSImage imageNamed:NSImageNameUser];
						
			// Change image.
			dispatch_async(dispatch_get_main_queue(), ^{
				[_imAvatar setImage:final];
			});
			
			// Set the new avatar to the chat window.
			[[TCChatWindowController sharedController] setLocalAvatar:final forIdentifier:[_configuration selfAddress]];
			
			// Notify the change.
			dispatch_async(_noticeQueue, ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesWindowControllerAvatarChanged object:manager userInfo:@{ @"avatar" : final }];
			});
			
			break;
		}
			
		case tccore_notify_profile_name:
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				// Update Title
				[self updateTitleUI];
			});
			
			break;
		}
			
		case tccore_notify_profile_text:
			break;
			
		case tccore_notify_buddy_new:
		{
			TCBuddy *buddy = (TCBuddy *)info.context;
			
			buddy.delegate = self;
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				[_buddies addObject:buddy];
				
				[[TCChatWindowController sharedController] setLocalAvatar:[_imAvatar image] forIdentifier:[buddy address]];
				
				[self reloadBuddy:nil];
			});
			
			break;
		}
			
		case tccore_notify_client_new:
			break;
			
		case tccore_notify_client_started:
			break;
			
		case tccore_notify_client_stoped:
			break;
	}
}



/*
** TCBuddiesController - TCBuddyDelegate
*/
#pragma mark - TCBuddiesController - TCBuddyDelegate

- (void)buddy:(TCBuddy *)aBuddy event:(const TCInfo *)info
{
	// Add the error in the error manager
	[[TCLogsManager sharedManager] addBuddyLogEntryFromAddress:[aBuddy address] name:[aBuddy finalName] andText:[info render]];
	
	dispatch_async(_localQueue, ^{
		
		// Actions
		switch ((tcbuddy_info)info.infoCode)
		{
			case tcbuddy_notify_connected_tor:
				break;
				
			case tcbuddy_notify_connected_buddy:
				break;
				
			case tcbuddy_notify_disconnected:
			{
				// Rebuid buddy list.
				[self buddyStatusChanged];
				
				// Reload buddies table.
				dispatch_async(dispatch_get_main_queue(), ^{
					[self reloadBuddy:aBuddy];
				});
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:aBuddy userInfo:@{ @"status" : @(tcstatus_offline) }];
				});
				
				break;
			}
				
			case tcbuddy_notify_identified:
				break;
				
			case tcbuddy_notify_status:
			{
				tcstatus  status = (tcstatus)[(NSNumber *)info.context intValue];
				NSString		*statusStr = @"";
				
				// Send status to chat window.
				switch (status)
				{
					case tcstatus_offline:
						statusStr = NSLocalizedString(@"bd_status_offline", @"");
						break;
						
					case tcstatus_available:
						statusStr = NSLocalizedString(@"bd_status_available", @"");
						break;
						
					case tcstatus_away:
						statusStr = NSLocalizedString(@"bd_status_away", @"");
						break;
						
					case tcstatus_xa:
						statusStr = NSLocalizedString(@"bd_status_xa", @"");
						break;
				}
				
				[[TCChatWindowController sharedController] receiveStatus:statusStr forIdentifier:[aBuddy address]];
				
				// Reload buddies table.
				dispatch_async(dispatch_get_main_queue(), ^{
					[self reloadBuddy:aBuddy];
				});
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:aBuddy userInfo:@{ @"status" : info.context }];
				});
				
				break;
			}
				
			case tcbuddy_notify_profile_avatar:
			{
				TCImage *tcAvatar = (TCImage *)info.context;
				NSImage *avatar = [tcAvatar imageRepresentation];
				
				if (!avatar)
					return;
				
				// Reload table.
				dispatch_async(dispatch_get_main_queue(), ^{
					[self reloadBuddy:aBuddy];
				});
				
				// Set the new avatar to the chat window.
				[[TCChatWindowController sharedController] setRemoteAvatar:avatar forIdentifier:[aBuddy address]];
				
				// Notify of the new avatar.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedAvatarNotification object:aBuddy userInfo:@{ @"avatar" : avatar }];
				});
				
				break;
			}
				
			case tcbuddy_notify_profile_text:
			{
				NSString *text = info.context;
				
				if (!text)
					return;
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedTextNotification object:aBuddy userInfo:@{ @"text" : text }];
				});
				
				break;
			}
				
			case tcbuddy_notify_profile_name:
			{
				NSString *name = info.context;
				
				if (!name)
					return;
				
				// Reload table.
				dispatch_async(dispatch_get_main_queue(), ^{
					[self reloadBuddy:aBuddy];
				});
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedNameNotification object:aBuddy userInfo:@{ @"name" : name }];
				});
				
				break;
			}
				
			case tcbuddy_notify_message:
			{
				TCChatWindowController *chatController = [TCChatWindowController sharedController];
				
				// Start a chat UI.
				[self startChatForBuddy:aBuddy select:([chatController.window isKeyWindow] == NO)];
				
				// Add the message.
				[chatController receiveMessage:info.context forIdentifier:[aBuddy address]];
				
				break;
			}
				
			case tcbuddy_notify_alias:
			{
				NSString *alias =info.context;
				
				if (!alias)
					return;
				
				// Reload table.
				dispatch_async(dispatch_get_main_queue(), ^{
					[self reloadBuddy:aBuddy];
				});
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedAliasNotification object:aBuddy userInfo:@{ @"alias" : alias }];
				});
				
				break;
			}
				
			case tcbuddy_notify_notes:
				break;
				
			case tcbuddy_notify_blocked:
			{
				NSNumber *blocked = info.context;
				
				if (!blocked)
					return;
				
				// Reload table.
				dispatch_async(dispatch_get_main_queue(), ^{
					[self reloadBuddy:aBuddy];
				});
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedBlockedNotification object:aBuddy userInfo:@{ @"blocked" : blocked }];
				});
				
				break;
			}
				
			case tcbuddy_notify_version:
			{
				NSString *version = info.context;
				
				if (!version)
					return;
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerVersionNotification object:aBuddy userInfo:@{ @"version" : version }];
				});
				
				break;
			}
				
			case tcbuddy_notify_client:
			{
				NSString *client = info.context;
				
				if (!client)
					return;
				
				// Notify.
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerClientNotification object:self userInfo:@{ @"client" : client }];
				});
				
				break;
			}
				
			case tcbuddy_notify_file_send_start:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[[TCFilesWindowController sharedController] startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyAddress:[aBuddy address] buddyName:[aBuddy finalName] transfertWay:tcfile_upload fileSize:[finfo fileSizeTotal]];
				
				break;
			}
				
			case tcbuddy_notify_file_send_running:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[[TCFilesWindowController sharedController] setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case tcbuddy_notify_file_send_finish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesWindowController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_upload_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case tcbuddy_notify_file_send_stoped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesWindowController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_upload_stoped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_start:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[[TCFilesWindowController sharedController] startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyAddress:[aBuddy address] buddyName:[aBuddy finalName] transfertWay:tcfile_download fileSize:[finfo fileSizeTotal]];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_running:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[[TCFilesWindowController sharedController] setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_finish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesWindowController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_download_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_stoped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesWindowController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_download_stoped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case tcbuddy_error_resolve_tor:
				break;
				
			case tcbuddy_error_connect_tor:
				break;
				
			case tcbuddy_error_socket:
				break;
				
			case tcbuddy_error_socks:
				break;
				
			case tcbuddy_error_too_messages:
				break;
				
			case tcbuddy_error_message_offline:
			{
				NSString	*key = NSLocalizedString(@"bd_error_offline", "");
				NSString	*message = info.context;
				NSString	*full;
				
				if (message)
					full = [[NSString alloc] initWithFormat:key, message];
				else
					full = [[NSString alloc] initWithFormat:key, @"-"];
				
				// Add the error
				[[TCChatWindowController sharedController] receiveError:full forIdentifier:[aBuddy address]];
				
				break;
			}
				
			case tcbuddy_error_message_blocked:
			{
				NSString	*key = NSLocalizedString(@"bd_error_blocked", "");
				NSString	*message = (NSString *)info.context;
				NSString	*full;
				
				if (message)
					full = [[NSString alloc] initWithFormat:key, message];
				else
					full = [[NSString alloc] initWithFormat:key, @"-"];
				
				// Add the error
				[[TCChatWindowController sharedController] receiveError:full forIdentifier:[aBuddy address]];
				
				break;
			}
				
			case tcbuddy_error_send_file:
				break;
				
			case tcbuddy_error_receive_file:
				break;
				
			case tcbuddy_error_file_offline:
				break;
				
			case tcbuddy_error_file_blocked:
				break;
				
			case tcbuddy_error_parse:
				break;
		}
	});
}



/*
** TCBuddiesController - TCDropButtonDelegate
*/
#pragma mark - TCBuddiesController - TCDropButtonDelegate

- (void)dropButton:(TCDropButton *)button doppedImage:(NSImage *)avatar
{
	if (!avatar)
		return;
	
	TCImage *image = [[TCImage alloc] initWithImage:avatar];
	
	[_control setProfileAvatar:image];
}



/*
** TCBuddiesController - TCDropButtonDelegate
*/
#pragma mark - TCBuddiesController - TCDropButtonDelegate

- (void)chatSendMessage:(NSString *)message identifier:(NSString *)identifier context:(id)context
{
	TCBuddy *buddy = context;
	
	if (!buddy || !message)
		return;
	
	[buddy sendMessage:message];
}



/*
** TCBuddiesController - Notifications
*/
#pragma mark - TCBuddiesController - Notifications

- (void)fileCancel:(NSNotification *)notice
{
	NSDictionary	*info = [notice userInfo];
	NSString		*uuid = [info objectForKey:@"uuid"];
	NSString		*address = [info objectForKey:@"address"];
	tcfile_way		way = (tcfile_way)[[info objectForKey:@"way"] intValue];
	
	// Search the buddy associated with this transfert
	for (TCBuddy *buddy in _buddies)
	{
		if ([[buddy address] isEqualToString:address])
		{
			// Change the file status
			[[TCFilesWindowController sharedController] setStatus:tcfile_status_cancel andTextStatus:NSLocalizedString(@"file_canceling", @"") forFileTransfert:uuid withWay:way];
			
			// Canceling the transfert
			if (way == tcfile_upload)
				[buddy fileCancelOfUUID:uuid way:tcbuddy_file_send];
			else if (way == tcfile_download)
				[buddy fileCancelOfUUID:uuid way:tcbuddy_file_receive];
			
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
		case 0:
			[_control stop];
			[self updateStatusUI:-2];
			break;
			
		case 1:
			[_control setStatus:tcstatus_available];
			break;
			
		case 2:
			[_control setStatus:tcstatus_away];
			break;
			
		case 3:
			[_control setStatus:tcstatus_xa];
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

		[self dropButton:nil doppedImage:avatar];
	}
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
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	NSString	*address;
	
	if (row < 0 || row >= [_buddies count])
		return;
	
	// Get the buddy address
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	address = [buddy address];
	
	// Inform the info controller that we are removing this buddy
	dispatch_async(_noticeQueue, ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesWindowControllerRemovedBuddy object:self userInfo:@{ @"buddy" : buddy }];
	});
	
	// Remove the buddy from interface side
	buddy.delegate = nil;
	[_buddies removeObjectAtIndex:(NSUInteger)row];
	[_tableView reloadData];
	
	// Remove the buddy from the controller
	[_control removeBuddy:address];
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
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	
	if (row < 0 || row >= [_buddies count])
		return;

	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	
	[self startChatForBuddy:buddy select:YES];
}

- (IBAction)doSendFile:(id)sender
{
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	
	if (row < 0 || row >= [_buddies count])
		return;
	
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	
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
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	
	if (row < 0 || row >= [_buddies count])
		return;
	
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
		
	if ([buddy blocked])
		[_control removeBlockedBuddy:[buddy address]];
	else
		[_control addBlockedBuddy:[buddy address]];
}

- (IBAction)doEditProfile:(id)sender
{
	NSString *tname = [_control profileName];
	NSString *ttext = [_control profileText];
	
	[_profileName setStringValue:tname];
	[[[_profileText textStorage] mutableString] setString:ttext];
	
	[NSApp beginSheet:_profileWindow modalForWindow:self.window modalDelegate:nil didEndSelector:NULL contextInfo:NULL];
}

- (IBAction)doAddOk:(id)sender
{
	NSString *notes = [[_addNotesField textStorage] mutableString];

	// Add the buddy to the controller. Notification will add it on our interface.
	[_control addBuddy:[_addNameField stringValue] address:[_addAddressField stringValue] comment:notes];
	
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
	
	[_control setProfileName:name];
	
	dispatch_async(_noticeQueue, ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesWindowControllerNameChanged object:self userInfo:@{ @"name" : name }];
	});
	
	// -- Hold text --
	NSString *text = [[_profileText textStorage] mutableString];
	
	[_control setProfileText:text];
	
	dispatch_async(_noticeQueue, ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:TCBuddiesWindowControllerTextChanged object:self userInfo:@{ @"text" : text }];
	});
}

- (IBAction)doProfileCancel:(id)sender
{
	[NSApp endSheet:_profileWindow];
	[_profileWindow orderOut:self];
}



/*
** TCBuddiesController - Tools
*/
#pragma mark - TCBuddiesController - Tools

- (void)buddyStatusChanged
{
	dispatch_async(dispatch_get_main_queue(), ^{

		// Sort buddies by status
		NSUInteger		i, cnt = [_buddies count];
		NSMutableArray	*temp_off = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_av = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_aw = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_xa = [[NSMutableArray alloc] initWithCapacity:cnt];
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy *buddy = [_buddies objectAtIndex:i];
			
			switch ([buddy status])
			{
				case tcstatus_offline:
					[temp_off addObject:buddy];
					break;
					
				case tcstatus_available:
					[temp_av addObject:buddy];
					break;
					
				case tcstatus_away:
					[temp_aw addObject:buddy];
					break;
					
				case tcstatus_xa:
					[temp_xa addObject:buddy];
					break;
			}
		}
		
		[_buddies removeAllObjects];
		
		[_buddies addObjectsFromArray:temp_av];
		[_buddies addObjectsFromArray:temp_aw];
		[_buddies addObjectsFromArray:temp_xa];
		[_buddies addObjectsFromArray:temp_off];
		
		// Reload table
		[self reloadBuddy:nil];
	});
}

- (void)startChatForBuddy:(TCBuddy *)buddy select:(BOOL)select
{
	if (!buddy)
		return;
	
	TCChatWindowController	*chatCtrl = [TCChatWindowController sharedController];
	NSString				*identifier;
	
	identifier = [buddy address];
	
	// Start chat.
	TCImage *tcImage = [buddy profileAvatar];
	NSImage	*image = [tcImage imageRepresentation];
	
	if (!image)
		image = [NSImage imageNamed:NSImageNameUser];
	
	[chatCtrl startChatWithIdentifier:identifier name:[buddy finalName] localAvatar:[_imAvatar image] remoteAvatar:image context:buddy delegate:self];
		
	// Select it.
	if (select)
		[chatCtrl selectChatWithIdentifier:identifier];
}

- (TCBuddy *)selectedBuddy
{
	NSInteger row = [_tableView selectedRow];
	
	if (row < 0 || row >= [_buddies count])
		return nil;
	
	return [_buddies objectAtIndex:(NSUInteger)row];
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
				content = [_control profileName];
				
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
}

- (void)reloadBuddy:(TCBuddy *)buddy
{
	if (buddy)
	{
		NSUInteger index = [_buddies indexOfObjectIdenticalTo:buddy];
		
		if (index != NSNotFound)
			[_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		else
			[self reloadBuddy:nil];
	}
	else
	{
		NSInteger index = [_tableView selectedRow];
		
		[_tableView reloadData];
		
		if (index != NSNotFound)
			[_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] byExtendingSelection:NO];
	}
}

@end
