/*
 *  TCBuddyInfoWindowsController.m
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

#import "TCBuddyInfoWindowsController.h"

#import "TCLogsManager.h"
#import "TCCoreManager.h"

#import "TCDragImageView.h"
#import "TCKeyedText.h"
#import "TCDebugLog.h"

#import "TCBuddy.h"
#import "TCImage.h"


/*
** Defines
*/
#pragma mark - Defines

#define BICInfoPeerClient		@"PeerClient"
#define BICInfoPeerVersion		@"PeerVersion"
#define BICInfoProfileName		@"ProfileName"
#define BICInfoProfileText		@"ProfileText"
#define BICInfoIsBlocked		@"IsBlocked"



/*
** TCBuddyInfoWindowsController - Private
*/
#pragma mark - TCBuddyInfoWindowsController - Private

@interface TCBuddyInfoWindowsController () <TCCoreManagerObserver>
{
	NSMutableArray		*_windowsControllers;
	dispatch_queue_t	_localQueue;
	TCCoreManager		*_coreManager;
}

@end



/*
** TCBuddyInfoWindowController - Private
*/
#pragma mark - TCBuddyInfoWindowController - Private

@interface TCBuddyInfoWindowController : NSWindowController <TCLogsObserver, TCBuddyObserver, TCCoreManagerObserver, NSWindowDelegate>
{
	NSMutableArray			*_logs;
	
	NSMutableDictionary		*_infos;
	
	NSDateFormatter			*_dateFormatter;
	
	TCBuddyInfoWindowsController *_windowsController;
	TCCoreManager *_coreManager;
}

// -- Properties --
@property (strong, nonatomic) IBOutlet NSSegmentedControl	*toolBar;
@property (strong, nonatomic) IBOutlet NSTabView			*views;

@property (strong, nonatomic) IBOutlet TCDragImageView		*avatarView;
@property (strong, nonatomic) IBOutlet NSImageView			*statusView;
@property (strong, nonatomic) IBOutlet NSTextField			*addressField;
@property (strong, nonatomic) IBOutlet NSTextField			*aliasField;

@property (strong, nonatomic) IBOutlet NSTextView			*notesField;

@property (strong, nonatomic) IBOutlet NSTableView			*logTable;

@property (strong, nonatomic) IBOutlet NSTextView			*infoView;

@property (strong, readonly, nonatomic) TCBuddy	*buddy;

// -- Instance --
- (id)initWithWindowsController:(TCBuddyInfoWindowsController *)windowsController buddy:(TCBuddy *)buddy coreManager:(TCCoreManager *)coreManager;

// -- IBAction --
- (IBAction)doToolBar:(id)sender;

@end



/*
** TCBuddyInfoWindowsController
*/
#pragma mark - TCBuddyInfoWindowsController

@implementation TCBuddyInfoWindowsController


/*
** TCBuddyInfoWindowsController - Instance
*/
#pragma mark - TCBuddyInfoWindowsController - Instance

- (instancetype)initWithCoreManager:(TCCoreManager *)coreManager;
{
	self = [super init];
	
	if (self)
	{
		if (!coreManager)
			return nil;
		
		_coreManager = coreManager;
		_windowsControllers = [[NSMutableArray alloc] init];
		_localQueue = dispatch_queue_create("com.torchat.app.buddy-info-window-controller.global", DISPATCH_QUEUE_SERIAL);
		
		[_coreManager addObserver:self];
	}
	
	return self;
}

- (void)dealloc
{
	[_coreManager removeObserver:self];
}



/*
** TCBuddyInfoWindowsController - Tools
*/
#pragma mark - TCBuddyInfoWindowsController - Tools

- (void)showInfoForBuddy:(TCBuddy *)buddy
{
	dispatch_async(_localQueue, ^{
		
		TCBuddyInfoWindowController *ctrl = nil;
		
		// Search already existing controller.
		for (TCBuddyInfoWindowController *aCtrl in _windowsControllers)
		{
			if (aCtrl.buddy == buddy)
			{
				ctrl = aCtrl;
				break;
			}
		}
		
		// Create new controller.
		if (!ctrl)
		{
			ctrl = [[TCBuddyInfoWindowController alloc] initWithWindowsController:self buddy:buddy coreManager:_coreManager];
		
			if (ctrl)
				[_windowsControllers addObject:ctrl];
		}
		
		// Show it.
		dispatch_async(dispatch_get_main_queue(), ^{
			[ctrl showWindow:nil];
		});
	});
}

- (void)closeInfoForBuddy:(TCBuddy *)buddy
{
	if (!buddy)
		return;
	
	dispatch_async(_localQueue, ^{
		
		NSUInteger i, cnt = [_windowsControllers count];
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddyInfoWindowController *ctrl = [_windowsControllers objectAtIndex:i];
			
			if (ctrl.buddy == buddy)
			{
				[[TCLogsManager sharedManager] removeObserverForKey:ctrl.buddy.address];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[ctrl.window orderOut:nil];
				});
				
				[_windowsControllers removeObjectAtIndex:i];
				
				return;
			}
		}
	});
}



/*
** TCBuddyInfoWindowsController - TCCoreManagerObserver
*/
#pragma mark - TCBuddyInfoWindowsController - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(TCInfo *)info
{
	// Handle buddy remove.
	if (info.kind == TCInfoInfo && info.code == TCCoreEventBuddyRemove)
	{
		TCBuddy *buddy = info.context;

		[self closeInfoForBuddy:buddy];
	}
}

@end



/*
** TCBuddyInfoWindowController
*/
#pragma mark - TCBuddyInfoWindowController

@implementation TCBuddyInfoWindowController


/*
** TCBuddyInfoWindowController - Instance
*/
#pragma mark - TCBuddyInfoWindowController - Instance

- (id)initWithWindowsController:(TCBuddyInfoWindowsController *)windowsController buddy:(TCBuddy *)buddy coreManager:(TCCoreManager *)coreManager
{
	self = [super initWithWindowNibName:@"BuddyInfoWindow"];
	
	if (self)
	{
		if (!windowsController || !buddy)
			return nil;
		
		_windowsController = windowsController;
		_buddy = buddy;
		_coreManager = coreManager;
		
		// Containers.
		_logs = [[NSMutableArray alloc] init];
		_infos = [[NSMutableDictionary alloc] init];
		
		// Date formatter.
		_dateFormatter = [[NSDateFormatter alloc] init];
		
		[_dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[_dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
		
		// Register for logs.
		[[TCLogsManager sharedManager] addObserver:self forKey:_buddy.address];
		
		// Register for informations.
		[_buddy addObserver:self];
		[_coreManager addObserver:self];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"(%p) TCBuddyInfoWindowController dealloc", self);
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[[TCLogsManager sharedManager] removeObserverForKey:_buddy.address];
	
	self.window.delegate = nil;
	_logTable.delegate = nil;
	_logTable.dataSource = nil;
	_views.delegate = nil;
	
	_addressField.delegate = nil;
	_aliasField.delegate = nil;
	_notesField.delegate = nil;
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	// -- Configure Window --
	self.window.delegate = self;
	[self.window center];
	[self setWindowFrameAutosaveName:@"InfoWindow"];

	// -- Configure content --
	// Name.
	NSString *name = [_buddy profileName];
	
	if ([name length] == 0)
		name = [_buddy lastProfileName];
	
	[self setInfo:name withKey:BICInfoProfileName];
	
	// Avatar.
	TCImage *tcImage = [_buddy profileAvatar];
	NSImage *image = [tcImage imageRepresentation];
	
	if (!image)
		image = [NSImage imageNamed:NSImageNameUser];
	
	[_avatarView setImage:image];
	[_avatarView setName:_buddy.address];

	// Address.
	[_addressField setStringValue:_buddy.address];
	
	// Alias.
	[_aliasField setStringValue:_buddy.alias];
	[_aliasField.cell setPlaceholderString:name];
	
	// Notes.
	[[_notesField.textStorage mutableString] setString:_buddy.notes];
	
	[self updateStatus:_buddy.status];
	
	// Profile.
	[self setInfo:[_buddy profileText] withKey:BICInfoProfileText];
	
	// Peer.
	[self setInfo:[_buddy peerClient] withKey:BICInfoPeerClient];
	[self setInfo:[_buddy peerVersion] withKey:BICInfoPeerVersion];
	
	// Blocked.
	if ([_buddy blocked])
		[self setInfo:NSLocalizedString(@"bdi_yes", @"") withKey:BICInfoIsBlocked];
	else
		[self setInfo:NSLocalizedString(@"bdi_no", @"") withKey:BICInfoIsBlocked];
	
	// Update content.
	[self updateInfoView];
	[self updateToolbar];
}



/*
** TCBuddyInfoWindowController - IBAction
*/
#pragma mark - TCBuddyInfoWindowController - IBAction

- (IBAction)doToolBar:(id)sender
{
	NSInteger index = [_toolBar selectedSegment];
			
	[_views selectTabViewItemAtIndex:index];
}



/*
** TCBuddyInfoWindowController - Tools
*/
#pragma mark - TCBuddyInfoWindowController - Tools

- (void)updateToolbar
{
	NSSize		sz = self.window.frame.size;
	NSInteger	i, count = [_toolBar segmentCount];
	CGFloat		swidth = sz.width / count;
	
	for (i = 0; i < count; i++)
		[_toolBar setWidth:swidth forSegment:i];
}



/*
** TCBuddyInfoWindowController - NSWindowDelegate
*/
#pragma mark - TCBuddyInfoWindowController - NSWindowDelegate

- (void)windowWillClose:(NSNotification *)notification
{	
	[[TCLogsManager sharedManager] removeObserverForKey:self.buddy.address];
	
	[_windowsController closeInfoForBuddy:self.buddy];
}

- (void)windowDidResize:(NSNotification *)notification
{
	[self updateToolbar];
}



/*
** TCBuddyInfoWindowController - NSTableView
*/
#pragma mark - TCBuddyInfoWindowController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{	
	return (NSInteger)[_logs count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{	
	if (rowIndex < 0 || rowIndex >= [_logs count])
		return nil;
	
	TCLogEntry	*entry = [_logs objectAtIndex:(NSUInteger)rowIndex];
	NSString	*identifier = aTableColumn.identifier;

	if ([identifier isEqualToString:@"kind"])
	{
		switch (entry.kind)
		{
			case TCLogError:
				return [NSImage imageNamed:NSImageNameStatusUnavailable];
			case TCLogWarning:
				return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
			case TCLogInfo:
				return [NSImage imageNamed:NSImageNameStatusNone];
		}
	}
	else if ([identifier isEqualToString:@"date"])
		return [_dateFormatter stringFromDate:entry.timestamp];
	else if ([identifier isEqualToString:@"message"])
		return entry.message;
	
	return entry.message;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}



/*
** TCBuddyInfoWindowController - NSTextView/Field
*/
#pragma mark - TCBuddyInfoWindowController - NSTextView/Field

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	
	if (object == _aliasField)
	{
		[_buddy setAlias:[_aliasField stringValue]];
	}
}

- (void)textDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	
	if (object == _notesField)
	{
		[_buddy setNotes:[[_notesField textStorage] mutableString]];
	}
}

- (void)setInfo:(NSString *)info withKey:(NSString *)key
{
	if ([key length] == 0)
		return;

	if ([info length] == 0)
	{
		[_infos removeObjectForKey:key];
		return;
	}
	
	[_infos setValue:info forKey:key];
}

- (void)updateInfoView
{
	TCKeyedText	*keyed = [[TCKeyedText alloc] initWithKeySize:100];
	NSString	*value;

	// Add profile name
	value = [_infos objectForKey:BICInfoProfileName];
	if (value)
		[keyed addLineWithKey:NSLocalizedString(@"bdi_profile_name", @"") andContent:value];
	
	// Add peer client
	value = [_infos objectForKey:BICInfoPeerClient];
	if (value)
		[keyed addLineWithKey:NSLocalizedString(@"bdi_peer_client", @"") andContent:value];
	
	// Add peer version
	value = [_infos objectForKey:BICInfoPeerVersion];
	if (value)
		[keyed addLineWithKey:NSLocalizedString(@"bdi_peer_version", @"") andContent:value];
	
	// Add profile text
	value = [_infos objectForKey:BICInfoProfileText];
	if (value)
		[keyed addLineWithKey:NSLocalizedString(@"bdi_profile_text", @"") andContent:value];
	
	// Add blocked text
	value = [_infos objectForKey:BICInfoIsBlocked];
	if (value)
		[keyed addLineWithKey:NSLocalizedString(@"bdi_isblocked", @"") andContent:value];

	// Show table
	[[_infoView textStorage] setAttributedString:[keyed renderedText]];
}
	 
- (void)updateStatus:(TCStatus)status
{
	switch (status)
	{
		case TCStatusAvailable:
			[_statusView setImage:[NSImage imageNamed:@"stat_online"]];
			break;
			
		case TCStatusAway:
			[_statusView setImage:[NSImage imageNamed:@"stat_away"]];
			break;
			
		case TCStatusOffline:
			[_statusView setImage:[NSImage imageNamed:@"stat_offline"]];
			break;
			
		case TCStatusXA:
			[_statusView setImage:[NSImage imageNamed:@"stat_xa"]];
			break;
	}
}


/*
** TCBuddyInfoWindowController - TCLogsObserver
*/
#pragma mark - TCBuddyInfoWindowController - TCLogsObserver

- (void)logManager:(TCLogsManager *)manager updateForKey:(NSString *)key withEntries:(NSArray *)entries
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[_logs addObjectsFromArray:entries];
		[_logTable reloadData];
	});
}



/*
** TCBuddyInfoWindowController - TCBuddyObserver
*/
#pragma mark - TCBuddyInfoWindowController - TCBuddyObserver

- (void)buddy:(TCBuddy *)buddy information:(TCInfo *)info
{
	if (info.kind == TCInfoInfo)
	{
		switch (info.code)
		{
			case TCBuddyEventProfileAvatar:
			{
				TCImage *tcAvatar = (TCImage *)info.context;
				NSImage *avatar = [tcAvatar imageRepresentation];
				
				if (!avatar)
					break;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[_avatarView setImage:avatar];
				});
				
				break;
			}
				
			case TCBuddyEventProfileName:
			{
				NSString *name = info.context;
				
				if (!name)
					break;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					
					[self setInfo:name withKey:BICInfoProfileName];
					[self updateInfoView];
					
					[[_aliasField cell] setPlaceholderString:name];
				});
				
				break;
			}
			
			case TCBuddyEventProfileText:
			{
				NSString *text = info.context;
				
				if (!text)
					break;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self setInfo:text withKey:BICInfoProfileText];
					[self updateInfoView];
				});
				
				break;
			}
			
			case TCBuddyEventDisconnected:
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					[self updateStatus:TCStatusOffline];
				});
				
				break;
			}
				
			case TCBuddyEventStatus:
			{
				TCStatus status = (TCStatus)[(NSNumber *)info.context intValue];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self updateStatus:status];
				});
				
				break;
			}
				
			case TCBuddyEventClient:
			{
				NSString *client = info.context;
				
				if (!client)
					return;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self setInfo:client withKey:BICInfoPeerClient];
					[self updateInfoView];
				});
				
				break;
			}
				
			case TCBuddyEventVersion:
			{
				NSString *version = info.context;
				
				if (!version)
					return;
				
				dispatch_async(dispatch_get_main_queue(), ^{
					[self setInfo:version withKey:BICInfoPeerVersion];
					[self updateInfoView];
				});
				
				break;
			}
		}
	}
}



/*
** TCBuddyInfoWindowController - TCCoreManagerObserver
*/
#pragma mark - TCBuddyInfoWindowController - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(TCInfo *)info
{
	if (info.kind == TCInfoInfo && (info.code == TCCoreEventBuddyBlocked || info.code == TCCoreEventBuddyUnblocked))
	{
		TCBuddy *buddy = info.context;
		BOOL	blocked = buddy.blocked;
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (blocked)
				[self setInfo:NSLocalizedString(@"bdi_yes", @"") withKey:BICInfoIsBlocked];
			else
				[self setInfo:NSLocalizedString(@"bdi_no", @"") withKey:BICInfoIsBlocked];
			
			[self updateInfoView];
		});
	}
}

@end
