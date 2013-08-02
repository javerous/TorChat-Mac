/*
 *  TCBuddyInfoController.mm
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import "TCBuddyInfoController.h"

#import "TCBuddiesController.h"
#import "TCLogsManager.h"
#import "TCDragImageView.h"
#import "TCKeyedText.h"

#import "TCBuddy.h"
#import "TCImage.h"



/*
** Globals
*/
#pragma mark - Globals

static NSMutableArray *_windows = nil;



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
** TCBuddyInfoController - Private
*/
#pragma mark - TCBuddyInfoController - Private

@interface TCBuddyInfoController () <TCLogsObserver>
{
	NSMutableArray			*_logs;
	
	NSMutableDictionary		*_infos;
}

+ (TCBuddyInfoController *)buildController;

- (void)setInfo:(NSString *)indo withKey:(NSString *)key;
- (void)updateInfoView;

- (void)updateStatus:(tcbuddy_status)status;

@property (strong, nonatomic) TCBuddy	*buddy;
@property (strong, nonatomic) NSString	*address;

@end



/*
** TCBuddyInfoController
*/
#pragma mark - TCBuddyInfoController

@implementation TCBuddyInfoController


/*
** TCBuddyInfoController - Properties
*/
#pragma mark - TCBuddyInfoController - Properties


/*
** TCBuddyInfoController - Instance
*/
#pragma mark - TCBuddyInfoController - Instance

- (id)initWithWindow:(NSWindow *)window
{
	self = [super initWithWindow:window];
	
    if (self)
	{
		_logs = [[NSMutableArray alloc] init];
		_infos = [[NSMutableDictionary alloc] init];
		
		[window center];
		
		[self windowDidResize:nil];
    }
    
    return self;
}

- (void)dealloc
{
	TCDebugLog("(%p) TCBuddyInfoController dealloc", self);
	
	[self.window setDelegate:nil];
	[_logTable setDelegate:nil];
	[_logTable setDataSource:nil];
	[_views setDelegate:nil];
	
	[_addressField setDelegate:nil];
	[_aliasField setDelegate:nil];
	[_notesField setDelegate:nil];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	[self.window center];
	[self setWindowFrameAutosaveName:@"InfoWindow"];
	[self windowDidResize:nil];
}

- (void)awakeFromNib
{
	[_avatarView setFilename:_address];
}



/*
** TCBuddyInfoController - IBAction
*/
#pragma mark - TCBuddyInfoController - IBAction

- (IBAction)doToolBar:(id)sender
{
	NSInteger index = [_toolBar selectedSegment];
			
	[_views selectTabViewItemAtIndex:index];
}



/*
** TCBuddyInfoController - Private Tools
*/
#pragma mark - TCBuddyInfoController - Private Tools

+ (TCBuddyInfoController *)buildController
{
	static dispatch_once_t		pred;
	
	// Alloc global controller array
	dispatch_once(&pred, ^{
		_windows = [[NSMutableArray alloc] init];
	});
	
	// Alloc the controller
	TCBuddyInfoController *result = [[TCBuddyInfoController alloc] initWithWindowNibName:@"BuddyInfoWindow"];

	// Configure controller
	[result.window setDelegate:result];

	// Add the controller to the global array
	[_windows addObject:result];
	
	return result;
}



/*
** TCBuddyInfoController - Tools
*/
#pragma mark - TCBuddyInfoController - Tools

+ (void)showInfo
{
	[self showInfoOnBuddy:[[TCBuddiesController sharedController] selectedBuddy]];
}

+ (void)showInfoOnBuddy:(TCBuddy *)buddy
{
	NSUInteger	i, cnt = [_windows count];
	NSString	*address = [buddy address];
	
	// Check that we don't have a controller already running for this buddy
	for (i = 0; i < cnt; i++)
	{
		TCBuddyInfoController *ctrl = [_windows objectAtIndex:i];
		
		if ([ctrl.address isEqualToString:address])
		{
			[ctrl.window makeKeyAndOrderFront:nil];
			return;
		}
	}
	
	// Create new controller
	TCBuddyInfoController *ctrl = [self buildController];
	
	// Retain buddy
	ctrl.buddy = buddy;
	
	// Hold address
	ctrl.address = address;
	
	// Set direct info
	NSString *name = [buddy profileName];
	
	if ([name length] == 0)
		name = [buddy lastProfileName];
	
	[ctrl->_avatarView setImage:[buddy profileAvatar]];
	[ctrl->_addressField setStringValue:ctrl.address];
	[ctrl->_aliasField setStringValue:[buddy alias]];
	[[ctrl->_aliasField cell] setPlaceholderString:name];
	[[[ctrl->_notesField textStorage] mutableString] setString:[buddy notes]];
	
	[ctrl updateStatus:[buddy status]];
	
	// Set info
	[ctrl setInfo:[buddy profileName] withKey:BICInfoProfileName];
	[ctrl setInfo:[buddy profileText] withKey:BICInfoProfileText];
	
	[ctrl setInfo:[buddy peerClient] withKey:BICInfoPeerClient];
	[ctrl setInfo:[buddy peerVersion] withKey:BICInfoPeerVersion];
	
	if ([buddy blocked])
		[ctrl setInfo:NSLocalizedString(@"bdi_yes", @"") withKey:BICInfoIsBlocked];
	else
		[ctrl setInfo:NSLocalizedString(@"bdi_no", @"") withKey:BICInfoIsBlocked];
	
	[ctrl updateInfoView];
	
	// Register for logs
	[[TCLogsManager sharedManager] addObserver:ctrl forKey:ctrl.address];
	
	// Register for buddy changes
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyAvatarChanged:) name:TCCocoaBuddyChangedAvatarNotification object:buddy];
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyNameChanged:) name:TCCocoaBuddyChangedNameNotification object:buddy];
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyTextChanged:) name:TCCocoaBuddyChangedTextNotification object:buddy];
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyStatusChanged:) name:TCCocoaBuddyChangedStatusNotification object:buddy];
	
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyClientChanged:) name:TCCocoaBuddyChangedPeerClientNotification object:buddy];
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyVersionChanged:) name:TCCocoaBuddyChangedPeerVersionNotification object:buddy];

	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyBlockedChanged:) name:TCCocoaBuddyChangedBlockedNotification object:buddy];

	// Show the window
	[ctrl showWindow:nil];
	
	// Set the avatar drag name
	[ctrl->_avatarView setFilename:address];
}

+ (void)removingBuddy:(TCBuddy *)buddy
{
	NSUInteger i, cnt = [_windows count];
	
	for (i = 0; i < cnt; i++)
	{
		TCBuddyInfoController *ctrl = [_windows objectAtIndex:i];
		
		if (ctrl.buddy == buddy)
		{			
			[[TCLogsManager sharedManager] removeObserverForKey:ctrl.address];
			
			[[NSNotificationCenter defaultCenter] removeObserver:ctrl];
			
			[ctrl.window orderOut:nil];
			[_windows removeObjectAtIndex:i];
			
			return;
		}
	}
}



/*
** TCBuddyInfoController - Window Delegate
*/
#pragma mark - TCBuddyInfoController - Window Delegate

- (void)windowWillClose:(NSNotification *)notification
{	
	[[TCLogsManager sharedManager] removeObserverForKey:self.address];
	
	[_windows removeObject:self];
}

- (void)windowDidResize:(NSNotification *)notification
{
	NSSize		sz = self.window.frame.size;
	NSInteger	i, count = [_toolBar segmentCount];
	CGFloat		swidth = sz.width / count;
	
	for (i = 0; i < count; i++)
		[_toolBar setWidth:swidth forSegment:i];
}



/*
** TCBuddyInfoController - NSTableView
*/
#pragma mark - TCBuddyInfoController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{	
	return (NSInteger)[_logs count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{	
	if (rowIndex < 0 || rowIndex >= [_logs count])
		return nil;
	
	return [_logs objectAtIndex:(NSUInteger)rowIndex];
}



/*
** TCBuddyInfoController - NSTextView/Field
*/
#pragma mark - TCBuddyInfoController - NSTextView/Field

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
	 
- (void)updateStatus:(tcbuddy_status)status
{
	switch (status)
	{
		case tcbuddy_status_available:
			[_statusView setImage:[NSImage imageNamed:@"stat_online"]];
			break;
			
		case tcbuddy_status_away:
			[_statusView setImage:[NSImage imageNamed:@"stat_away"]];
			break;
			
		case tcbuddy_status_offline:
			[_statusView setImage:[NSImage imageNamed:@"stat_offline"]];
			break;
			
		case tcbuddy_status_xa:
			[_statusView setImage:[NSImage imageNamed:@"stat_xa"]];
			break;
	}
}


/*
** CBuddyInfoController - TCLogsObserver
*/
#pragma mark - CBuddyInfoController - TCLogsObserver

- (void)logManager:(TCLogsManager *)manager updateForKey:(NSString *)key withContent:(id)content
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if ([content isKindOfClass:[NSString class]])
		{
			if ([_logs count] > 500)
				[_logs removeObjectAtIndex:0];
			
			[_logs addObject:content];
		}
		else if ([content isKindOfClass:[NSArray class]])
		{
			[_logs addObjectsFromArray:content];
		}
		
		[_logTable reloadData];
	});
}



/*
** TCBuddyInfoController - Notifications
*/
#pragma mark - TCBuddyInfoController - Notifications

- (void)buddyAvatarChanged:(NSNotification *)notice
{
	NSImage *avatar = [[notice userInfo] objectForKey:@"avatar"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[_avatarView setImage:avatar];
	});
}

- (void)buddyNameChanged:(NSNotification *)notice
{
	NSString *name = [[notice userInfo] objectForKey:@"name"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self setInfo:name withKey:BICInfoProfileName];
		[self updateInfoView];
		
		[[_aliasField cell] setPlaceholderString:name];
	});
}

- (void)buddyTextChanged:(NSNotification *)notice
{
	NSString *text = [[notice userInfo] objectForKey:@"text"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self setInfo:text withKey:BICInfoProfileText];
		[self updateInfoView];
	});
}

- (void)buddyStatusChanged:(NSNotification *)notice
{
	NSNumber		*status = [[notice userInfo] objectForKey:@"status"];
	tcbuddy_status	istatus = (tcbuddy_status)[status intValue];
	
	// Build notification info
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self updateStatus:istatus];
	});
}

- (void)buddyClientChanged:(NSNotification *)notice
{
	NSString *client = [[notice userInfo] objectForKey:@"client"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self setInfo:client withKey:BICInfoPeerClient];
		[self updateInfoView];
	});
}

- (void)buddyVersionChanged:(NSNotification *)notice
{
	NSString *version = [[notice userInfo] objectForKey:@"version"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self setInfo:version withKey:BICInfoPeerVersion];
		[self updateInfoView];
	});
}

- (void)buddyBlockedChanged:(NSNotification *)notice
{
	NSNumber *blocked = [[notice userInfo] objectForKey:@"blocked"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if ([blocked boolValue])
			[self setInfo:NSLocalizedString(@"bdi_yes", @"") withKey:BICInfoIsBlocked];
		else
			[self setInfo:NSLocalizedString(@"bdi_no", @"") withKey:BICInfoIsBlocked];
		
		[self updateInfoView];
	});
}

@end
