/*
 *  TCCocoaBuddy.mm
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


#warning XXX this class still have a reason to exist with the siwtching of the core in Cocoa. Not sure (delegation can perhaps be moved on a manager of something).


#import "TCCocoaBuddy.h"

#import "TCFilesController.h"
#import "TCLogsController.h"
#import "TCBuddiesController.h"

#import "TCBuddy.h"
#import "TCInfo.h"
#import "TCImage.h"


/*
** Global
*/
#pragma mark - Global

static char gQueueIdentityKey;
static char gLocalQueueContext;



/*
** TCCocoaBuddy
*/
#pragma mark - TCCocoaBuddy

@interface TCCocoaBuddy () <TCBuddyDelegate>
{
	TCBuddy						*_buddy;
	
	dispatch_queue_t			_localQueue;
	dispatch_queue_t			_noticeQueue;
	
	tcbuddy_status				_status;
	NSImage						*_profileAvatar;
	NSString					*_profileName;
	NSString					*_profileText;
	
	NSString					*_peerVersion;
	NSString					*_peerClient;
	
	NSImage						*_localAvatar;
}

- (NSImage *)_profileAvatar;

@end



/*
** TCCocoaBuddy
*/
#pragma mark - TCCocoaBuddy

@implementation TCCocoaBuddy


/*
** TCCocoaBuddy - Instance
*/
#pragma mark - TCCocoaBuddy - Instance

- (id)initWithBuddy:(TCBuddy *)buddy
{
	self = [super init];
	
    if (self)
	{
		// Build a queue
		_localQueue = dispatch_queue_create("com.torchat.cocoa.buddy.local", DISPATCH_QUEUE_SERIAL);
		_noticeQueue = dispatch_queue_create("com.torchat.cocoa.buddy.notice", DISPATCH_QUEUE_SERIAL);

		dispatch_queue_set_specific(_localQueue, &gQueueIdentityKey, &gLocalQueueContext, NULL);

		// Handle the buddy
		_buddy = buddy;
		
		_status = tcbuddy_status_offline;
		
		// Init the buddy delegate
		buddy.delegate = self;
		
		// Observe notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(localAvatarChanged:) name:TCBuddiesControllerAvatarChanged object:nil];
    }
    
    return self;
}

- (void)dealloc
{
	TCDebugLog("Cocoa buddy release");
	
	// Stop UI chat
	[[TCChatController sharedController] stopChatWithIdentifier:[self address]];
	
	// Clean delegate
	_buddy.delegate = nil;
	
	// Remove notification
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



/*
** TCCocoaBuddy - Status
*/
#pragma mark - TCCocoaBuddy - Status

- (tcbuddy_status)status
{
	__block tcbuddy_status result;
	
	dispatch_sync(_localQueue, ^{
		result = _status;
	});
	
	return result;
}

- (NSString *)address
{
	if (!_buddy)
		return @"";
	
	return [_buddy address];
}

- (NSString *)alias
{
	if (!_buddy)
		return @"";
	
	return [_buddy alias];
}

- (BOOL)blocked
{
	if (!_buddy)
		return NO;
	
	return [_buddy blocked];
}

- (void)setAlias:(NSString *)alias
{
	if (!_buddy || !alias)
		return;
	
	[_buddy setAlias:alias];
}

- (NSString *)notes
{
	if (!_buddy)
		return @"";
	
	return [_buddy notes];
}

- (void)setNotes:(NSString *)notes
{
	if (!_buddy || !notes)
		return;
	
	[_buddy setNotes:notes];
}

- (NSImage *)localAvatar
{
	if (dispatch_get_specific(&gQueueIdentityKey) == &gLocalQueueContext)
		return _localAvatar;
	else
	{
		__block NSImage *result = nil;
		
		dispatch_sync(_localQueue, ^{
			result = _localAvatar;
		});
		
		return result;
	}
}

- (void)setLocalAvatar:(NSImage *)avatar
{
	// Hold avatar
	dispatch_async(_localQueue, ^{
		_localAvatar = avatar;
	});
	
	// Refresh chat avatar
	[[TCChatController sharedController] setLocalAvatar:avatar forIdentifier:[self address]];
}



/*
** TCCocoaBuddy - Profile
*/
#pragma mark - TCCocoaBuddy - Profile

- (NSImage *)profileAvatar
{
	if (dispatch_get_specific(&gQueueIdentityKey) == &gLocalQueueContext)
		return [self _profileAvatar];
	else
	{
		__block NSImage *result = nil;

		dispatch_sync(_localQueue, ^{
			result = [self _profileAvatar];
		});
		
		return result;
	}
}

- (NSImage *)_profileAvatar
{
	// > localQueue <
	
	if (_profileAvatar)
		return _profileAvatar;
	else
	{
		NSImage *img = [NSImage imageNamed:NSImageNameUser];
		
		[img setSize:NSMakeSize(64, 64)];
		
		return img;
	}
}

- (NSString *)profileName
{
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _profileName;
	});
	
	if (result)
		return result;
	else
		return @"";
}

- (NSString *)lastProfileName
{
	return [_buddy lastProfileName];
}

- (NSString *)profileText
{
	NSString *text = [_buddy profileText];
	
	if (!text)
		return @"";
	
	return text;
}

- (NSString *)finalName
{
	return [_buddy finalName];
}



/*
** TCCocoaBuddy - Peer
*/
#pragma mark - TCCocoaBuddy - Peer

- (NSString *)peerVersion
{
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _peerVersion;
	});
	
	if (result)
		return result;
	else
		return @"";
}

- (NSString *)peerClient
{
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _peerClient;
	});
	
	if (result)
		return result;
	else
		return @"";
}



/*
** TCCocoaBuddy - Actions
*/
#pragma mark - TCCocoaBuddy - Actions

- (void)startChatAndSelect:(BOOL)select
{
	TCChatController	*chat;
	NSString			*identifier;
	
	chat = [TCChatController sharedController];
	identifier = [self address];
	
	// Start chat
	[chat startChatWithIdentifier:identifier name:[self finalName] localAvatar:[self localAvatar] remoteAvatar:[self profileAvatar] delegate:self];
	
	// Select it
	if (select)
		[chat selectChatWithIdentifier:identifier];
}



/*
** TCCocoaBuddy - Handling
*/
#pragma mark - TCCocoaBuddy - Handling

- (void)yieldCore
{
	// Manage cycling reference in a dispatch environment:
	// -> Delegate are retained / released (no weak) XXX It's not true anymore. Fix the things to match this fact.
	// -> We remove the delegate when we don't wan't anymore an object (release, remove, etc)
	
	if (!_buddy)
		return;
	
	_buddy.delegate = nil;
}



/*
** TCCocoaBuddy - File
*/
#pragma mark - TCCocoaBuddy - File

- (void)cancelFileUpload:(NSString *)uuid
{
	if (!_buddy || !uuid)
		return;
	
	[_buddy fileCancelOfUUID:uuid way:tcbuddy_file_send];
}

- (void)cancelFileDownload:(NSString *)uuid
{
	if (!_buddy || !uuid)
		return;
	
	[_buddy fileCancelOfUUID:uuid way:tcbuddy_file_receive];
}

- (void)sendFile:(NSString *)fileName
{
	if (!_buddy || !fileName)
		return;
	
	[_buddy sendFile:fileName];
}



/*
** TCCocoaBuddy - Chat Delegate
*/
#pragma mark - TCCocoaBuddy - Chat Delegate

- (void)chatSendMessage:(NSString *)message forIdentifier:(NSString *)identifier
{
	if (!_buddy || !message)
		return;
	
	[_buddy sendMessage:message];
}



/*
** TCCocoaBuddy - Notifications
*/
#pragma mark - TCCocoaBuddy - Notifications

- (void)localAvatarChanged:(NSNotification *)notice
{
	NSImage *image = [[notice userInfo] objectForKey:@"avatar"];
	
	[self setLocalAvatar:image];
}



/*
** TCCocoaBuddy - TCBuddyDelegate
*/
#pragma mark - TCCocoaBuddy - TCBuddyDelegate

- (void)buddy:(TCBuddy *)aBuddy event:(const TCInfo *)info
{
	// Add the error in the error manager
	[[TCLogsController sharedController] addBuddyLogEntryFromAddress:[self address] alias:[self alias] andText:[info render]];
	
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
				NSDictionary *uinfo;
				
				_status = tcbuddy_status_offline;
				
				// Build notification info
				uinfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_status] forKey:@"status"];
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_identified:
				break;
				
			case tcbuddy_notify_status:
			{
				NSNumber		*statusValue = (NSNumber *)info.context;
				NSDictionary	*uinfo;
				NSString		*ostatus = @"";
				
				// Update status
				_status = (tcbuddy_status)[statusValue intValue];
				
				// Build notification info
				uinfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_status] forKey:@"status"];
				
				// Send notification
				dispatch_async(_noticeQueue, ^{
					
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:self userInfo:uinfo];
				});
				
				// Send status to chat window
				switch (_status)
				{
					case tcbuddy_status_offline:
						ostatus = NSLocalizedString(@"bd_status_offline", @"");
						break;
						
					case tcbuddy_status_available:
						ostatus = NSLocalizedString(@"bd_status_available", @"");
						break;
						
					case tcbuddy_status_away:
						ostatus = NSLocalizedString(@"bd_status_away", @"");
						
						break;
						
					case tcbuddy_status_xa:
						ostatus = NSLocalizedString(@"bd_status_xa", @"");
						break;
				}
				
				[[TCChatController sharedController] receiveStatus:ostatus forIdentifier:[self address]];
				
				break;
			}
				
			case tcbuddy_notify_profile_avatar:
			{
				NSImage			*avatar = [(TCImage *)info.context imageRepresentation];
				NSDictionary	*uinfo;
				
				// If no avatar, use standard user
				if ([[avatar representations] count] == 0)
				{
					avatar = [NSImage imageNamed:NSImageNameUser];
					
					[avatar setSize:NSMakeSize(64, 64)];
				}
				
				// Build notification info
				uinfo = [NSDictionary dictionaryWithObject:avatar forKey:@"avatar"];
				
				// Hold avatar
				_profileAvatar = avatar;
				
				// Notify of the new avatar
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedAvatarNotification object:self userInfo:uinfo];
				});
				
				// Set the new avatar to the chat window
				[[TCChatController sharedController] setRemoteAvatar:_profileAvatar forIdentifier:[self address]];
				
				break;
			}
				
			case tcbuddy_notify_profile_text:
			{
				NSString		*text = info.context;
				NSDictionary	*uinfo = [NSDictionary dictionaryWithObject:text forKey:@"text"];
				
				_profileText = text;
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedTextNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_profile_name:
			{
				NSString		*name = info.context;
				NSDictionary	*uinfo = [NSDictionary dictionaryWithObject:name forKey:@"name"];
				
				_profileName = name;
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedNameNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_message:
			{
				// Start a chat UI
				[self startChatAndSelect:NO];
				
				// Add the message (on main queue, else the chat can be not started)
				[[TCChatController sharedController] receiveMessage:info.context forIdentifier:[self address]];
				
				break;
			}
				
			case tcbuddy_notify_alias:
			{
				NSString        *alias =info.context;
				NSDictionary    *uinfo = [NSDictionary dictionaryWithObject:alias forKey:@"alias"];
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedAliasNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_notes:
			{
				// TCString *notes = dynamic_cast<TCString *>(info->context());
				
				break;
			}
				
			case tcbuddy_notify_blocked:
			{
				NSNumber		*blocked = info.context;
				NSDictionary	*uinfo = [NSDictionary dictionaryWithObject:blocked forKey:@"blocked"];
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedBlockedNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_version:
			{
				NSString        *version = info.context;
				NSDictionary    *uinfo = [NSDictionary dictionaryWithObject:version forKey:@"version"];
				
				_peerVersion = version;
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerVersionNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_client:
			{
				NSString        *client = info.context;
				NSDictionary    *uinfo = [NSDictionary dictionaryWithObject:client forKey:@"client"];
				
				_peerClient = client;
				
				dispatch_async(_noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerClientNotification object:self userInfo:uinfo];
				});
				
				break;
			}
				
			case tcbuddy_notify_file_send_start:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[[TCFilesController sharedController] startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyAddress:[aBuddy address] buddyName:[aBuddy finalName] transfertWay:tcfile_upload fileSize:[finfo fileSizeTotal]];
				
				break;
			}
				
			case tcbuddy_notify_file_send_running:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[[TCFilesController sharedController] setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case tcbuddy_notify_file_send_finish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_upload_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case tcbuddy_notify_file_send_stoped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_upload_stoped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_start:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[[TCFilesController sharedController] startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyAddress:[aBuddy address] buddyName:[aBuddy finalName] transfertWay:tcfile_download fileSize:[finfo fileSizeTotal]];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_running:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[[TCFilesController sharedController] setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_finish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_download_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case tcbuddy_notify_file_receive_stoped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[[TCFilesController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_download_stoped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
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
				NSString	*message = info.context;
				NSString	*full;
				
				if (message)
					full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_offline", ""), message];
				else
					full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_offline", ""), @"-"];
				
				// Add the error
				[[TCChatController sharedController] receiveError:full forIdentifier:[self address]];
				
				break;
			}
				
			case tcbuddy_error_message_blocked:
			{
				NSString	*message = (NSString *)info.context;
				NSString	*full;
				
				if (message)
					full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_blocked", ""), message];
				else
					full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_blocked", ""), @"-"];
				
				// Add the error
				[[TCChatController sharedController] receiveError:full forIdentifier:[self address]];
				
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

@end
