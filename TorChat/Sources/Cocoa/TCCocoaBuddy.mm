/*
 *  TCCocoaBuddy.mm
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


#warning XXX this class still have a reason to exist with the siwtching of the core in Cocoa. Not sure (delegation can perhaps be moved on a manager of something).


#import "TCCocoaBuddy.h"

#import "TCFilesController.h"
#import "TCLogsController.h"
#import "TCBuddiesController.h"

#import "TCBuddy.h"
#include "TCInfo.h"
#include "TCString.h"
#include "TCImage.h"
#include "TCNumber.h"


/*
** Global
*/
#pragma mark - Global

static char gQueueIdentityKey;
static char gMainQueueContext;



/*
** TCCocoaBuddy
*/
#pragma mark - TCCocoaBuddy

@interface TCCocoaBuddy () <TCBuddyDelegate>
{
	TCBuddy						*buddy;
	
	dispatch_queue_t			mainQueue;
	dispatch_queue_t			noticeQueue;
	
	tcbuddy_status				status;
	NSImage						*profileAvatar;
	NSString					*profileName;
	NSString					*profileText;
	
	NSString					*peerVersion;
	NSString					*peerClient;
	
	NSImage						*localAvatar;
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

- (id)initWithBuddy:(TCBuddy *)_buddy
{
	self = [super init];
	
    if (self)
	{
		// Build a queue
		mainQueue = dispatch_queue_create("com.torchat.cocoa.buddy.main", DISPATCH_QUEUE_SERIAL);
		noticeQueue = dispatch_queue_create("com.torchat.cocoa.buddy.notice", DISPATCH_QUEUE_SERIAL);

		dispatch_queue_set_specific(mainQueue, &gQueueIdentityKey, &gMainQueueContext, NULL);

		// Handle the buddy
		buddy = _buddy;
		
		status = tcbuddy_status_offline;
		
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
	buddy.delegate = nil;
	
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
	
	dispatch_sync(mainQueue, ^{
		
		result = status;
	});
	
	return result;
}

- (NSString *)address
{
	if (!buddy)
		return @"";
	
	return [buddy address];
}

- (NSString *)alias
{
	if (!buddy)
		return @"";
	
	return [buddy alias];
}

- (BOOL)blocked
{
	if (!buddy)
		return NO;
	
	return [buddy blocked];
}

- (void)setAlias:(NSString *)alias
{
	if (!buddy || !alias)
		return;
	
	[buddy setAlias:alias];
}

- (NSString *)notes
{
	if (!buddy)
		return @"";
	
	return [buddy notes];
}

- (void)setNotes:(NSString *)notes
{
	if (!buddy || !notes)
		return;
	
	[buddy setNotes:notes];
}

- (NSImage *)localAvatar
{
	if (dispatch_get_specific(&gQueueIdentityKey) == &gMainQueueContext)
		return localAvatar;
	else
	{
		__block NSImage *result = nil;
		
		dispatch_sync(mainQueue, ^{
			result = localAvatar;
		});
		
		return result;
	}
}

- (void)setLocalAvatar:(NSImage *)avatar
{
	// Hold avatar
	dispatch_async(mainQueue, ^{
		localAvatar = avatar;
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
	if (dispatch_get_specific(&gQueueIdentityKey) == &gMainQueueContext)
		return [self _profileAvatar];
	else
	{
		__block NSImage *result = nil;

		dispatch_sync(mainQueue, ^{
			result = [self _profileAvatar];
		});
		
		return result;
	}
}

- (NSImage *)_profileAvatar
{
	// > mainQueue <
	
	if (profileAvatar)
		return profileAvatar;
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
	
	dispatch_sync(mainQueue, ^{
		result = profileName;
	});
	
	if (result)
		return result;
	else
		return @"";
}

- (NSString *)lastProfileName
{
	return [buddy lastProfileName];
}

- (NSString *)profileText
{
	NSString *text = [buddy profileText];
	
	if (!text)
		return @"";
	
	return text;
}

- (NSString *)finalName
{
	return [buddy finalName];
}



/*
** TCCocoaBuddy - Peer
*/
#pragma mark - TCCocoaBuddy - Peer

- (NSString *)peerVersion
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		result = peerVersion;
	});
	
	if (result)
		return result;
	else
		return @"";
}

- (NSString *)peerClient
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = peerClient;
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
	
	if (!buddy)
		return;
	
	buddy.delegate = nil;
}



/*
** TCCocoaBuddy - File
*/
#pragma mark - TCCocoaBuddy - File

- (void)cancelFileUpload:(NSString *)uuid
{
	if (!buddy || !uuid)
		return;
	
	[buddy fileCancelOfUUID:uuid way:tcbuddy_file_send];
}

- (void)cancelFileDownload:(NSString *)uuid
{
	if (!buddy || !uuid)
		return;
	
	[buddy fileCancelOfUUID:uuid way:tcbuddy_file_receive];
}

- (void)sendFile:(NSString *)fileName
{
	if (!buddy || !fileName)
		return;
	
	[buddy sendFile:fileName];
}



/*
** TCCocoaBuddy - Chat Delegate
*/
#pragma mark - TCCocoaBuddy - Chat Delegate

- (void)chatSendMessage:(NSString *)message forIdentifier:(NSString *)identifier
{
	if (!buddy || !message)
		return;
	
	[buddy sendMessage:message];
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
	[[TCLogsController sharedController] addBuddyLogEntryFromAddress:[self address] alias:[self alias] andText:[NSString stringWithUTF8String:info->render().c_str()]];
	
	// Actions
	switch ((tcbuddy_info)info->infoCode())
	{
		case tcbuddy_notify_connected_tor:
			break;
			
		case tcbuddy_notify_connected_buddy:
			break;
			
		case tcbuddy_notify_disconnected:
		{
			NSDictionary *uinfo;
			
			status = tcbuddy_status_offline;
			
			// Build notification info
			uinfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:status] forKey:@"status"];
			
			dispatch_async(noticeQueue, ^{
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcbuddy_notify_identified:
			break;
			
		case tcbuddy_notify_status:
		{
			TCNumber		*statusValue = dynamic_cast<TCNumber *>(info->context());
			NSDictionary	*uinfo;
			NSString		*ostatus = @"";
			
			// Update status
			status = (tcbuddy_status)statusValue->uint8Value();
			
			// Build notification info
			uinfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:status] forKey:@"status"];
			
			// Send notification
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:self userInfo:uinfo];
			});
			
			// Send status to chat window
			switch (status)
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
			TCImage			*img = (__bridge TCImage *)(info->context());
			NSImage			*avatar = [img imageRepresentation];
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
			profileAvatar = avatar;
			
			// Notify of the new avatar
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedAvatarNotification object:self userInfo:uinfo];
			});
			
			// Set the new avatar to the chat window
			[[TCChatController sharedController] setRemoteAvatar:profileAvatar forIdentifier:[self address]];
			
			break;
		}
			
		case tcbuddy_notify_profile_text:
		{
			TCString		*text = dynamic_cast<TCString *>(info->context());
			NSString		*otext = [[NSString alloc] initWithUTF8String:text->content().c_str()];
			NSDictionary	*uinfo = [NSDictionary dictionaryWithObject:otext forKey:@"text"];
			
			profileText = otext;
			
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedTextNotification object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcbuddy_notify_profile_name:
		{
			TCString		*name = dynamic_cast<TCString *>(info->context());
			NSString		*oname = [[NSString alloc] initWithUTF8String:name->content().c_str()];
			NSDictionary	*uinfo = [NSDictionary dictionaryWithObject:oname forKey:@"name"];
			
			profileName = oname;
			
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedNameNotification object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcbuddy_notify_message:
		{
			TCString	*message = dynamic_cast<TCString *>(info->context());
			NSString	*omessage = [[NSString alloc] initWithUTF8String:message->content().c_str()];
			
			// Start a chat UI
			[self startChatAndSelect:NO];
			
			// Add the message (on main queue, else the chat can be not started)
			[[TCChatController sharedController] receiveMessage:omessage forIdentifier:[self address]];
			
			break;
		}
			
		case tcbuddy_notify_alias:
		{
			TCString        *alias = dynamic_cast<TCString *>(info->context());
			NSString        *oalias = [NSString stringWithUTF8String:alias->content().c_str()];
			NSDictionary    *uinfo = [NSDictionary dictionaryWithObject:oalias forKey:@"alias"];
			
			dispatch_async(noticeQueue, ^{
				
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
			TCNumber		*blocked = dynamic_cast<TCNumber *>(info->context());
			NSNumber		*oblocked = [NSNumber numberWithBool:(BOOL)blocked->uint8Value()];
			NSDictionary	*uinfo = [NSDictionary dictionaryWithObject:oblocked forKey:@"blocked"];
			
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedBlockedNotification object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcbuddy_notify_version:
		{
			TCString        *version = dynamic_cast<TCString *>(info->context());
			NSString        *oversion = [[NSString alloc] initWithUTF8String:version->content().c_str()];
			NSDictionary    *uinfo = [NSDictionary dictionaryWithObject:oversion forKey:@"version"];
			
			peerVersion = oversion;
			
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerVersionNotification object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcbuddy_notify_client:
		{
			TCString        *client = dynamic_cast<TCString *>(info->context());
			NSString        *oclient = [[NSString alloc] initWithUTF8String:client->content().c_str()];
			NSDictionary    *uinfo = [NSDictionary dictionaryWithObject:oclient forKey:@"client"];
			
			peerClient = oclient;
			
			dispatch_async(noticeQueue, ^{
				
				[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerClientNotification object:self userInfo:uinfo];
			});
			
			break;
		}
			
		case tcbuddy_notify_file_send_start:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;
			
			// Add the file transfert to the controller
			[[TCFilesController sharedController] startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyAddress:[aBuddy address] buddyName:[aBuddy finalName] transfertWay:tcfile_upload fileSize:[finfo fileSizeTotal]];
			
			break;
		}
			
		case tcbuddy_notify_file_send_running:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;
			
			// Update bytes received
			[[TCFilesController sharedController] setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_upload];
			
			break;
		}
			
		case tcbuddy_notify_file_send_finish:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;
			
			// Update status
			[[TCFilesController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_upload_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
			
			break;
		}
			
		case tcbuddy_notify_file_send_stoped:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;

			// Update status
			[[TCFilesController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_upload_stoped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
			
			break;
		}
			
		case tcbuddy_notify_file_receive_start:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;

			// Add the file transfert to the controller
			[[TCFilesController sharedController] startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyAddress:[aBuddy address] buddyName:[aBuddy finalName] transfertWay:tcfile_download fileSize:[finfo fileSizeTotal]];
			
			break;
		}
			
		case tcbuddy_notify_file_receive_running:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;
						
			// Update bytes received
			[[TCFilesController sharedController] setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_download];
			
			break;
		}
			
		case tcbuddy_notify_file_receive_finish:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
			if (!finfo)
				return;
			
			// Update status
			[[TCFilesController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_download_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
			
			break;
		}
			
		case tcbuddy_notify_file_receive_stoped:
		{
			TCFileInfo *finfo = (__bridge TCFileInfo *)(info->context());
			
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
			TCString	*message = dynamic_cast<TCString *>(info->context());
			NSString	*full;
			
			if (message)
				full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_offline", ""), [NSString stringWithUTF8String:message->content().c_str()]];
			else
				full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_offline", ""), @"-"];
			
			// Add the error
			[[TCChatController sharedController] receiveError:full forIdentifier:[self address]];
			
			break;
		}
			
		case tcbuddy_error_message_blocked:
		{
			TCString	*message = dynamic_cast<TCString *>(info->context());
			NSString	*full;
			
			if (message)
				full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_blocked", ""), [NSString stringWithUTF8String:message->content().c_str()]];
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
}

@end
