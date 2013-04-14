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



#import "TCCocoaBuddy.h"

#import "TCFilesController.h"
#import "TCLogsController.h"
#import "TCBuddiesController.h"

#import "TCImageExtension.h"

#include "TCBuddy.h"
#include "TCInfo.h"
#include "TCString.h"
#include "TCImage.h"
#include "TCNumber.h"



/*
** TCCocoaBuddy
*/
#pragma mark - TCCocoaBuddy

@interface TCCocoaBuddy ()
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

- (void)initDelegate;

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

		// Retain the TCBuddy object handled by this object
		buddy = _buddy;
		buddy->retain();
		
		status = tcbuddy_status_offline;
		
		// Init the buddy delegate
		[self initDelegate];
		
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
	buddy->setDelegate(0, NULL);
	buddy->release();
	
	// Release queue
	dispatch_release(mainQueue);
	dispatch_release(noticeQueue);
	
	// Release cache
	[profileAvatar release];
	[profileName release];
	[profileText release];
	
	[localAvatar release];
	
	// Remove notification
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
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
	
	TCString	&address = buddy->address();
	NSString	*result = [NSString stringWithUTF8String:address.content().c_str()];
	
	return result;
}

- (NSString *)alias
{
	if (!buddy)
		return @"";
	
	TCString	*alias = buddy->alias();
	NSString	*result = [NSString stringWithUTF8String:alias->content().c_str()];
	
	alias->release();
	
	return result;
}

- (BOOL)blocked
{
	if (!buddy)
		return NO;
	
	return buddy->blocked();
}

- (void)setAlias:(NSString *)alias
{
	if (!buddy)
		return;
	
	const char	*calias = [alias UTF8String];
	TCString	*talias;
	
	if (!calias)
		return;
	
	talias = new TCString(calias);
	
	buddy->setAlias(talias);
	
	talias->release();
}

- (NSString *)notes
{
	if (!buddy)
		return @"";
	
	TCString	*notes = buddy->notes();
	NSString	*result = [NSString stringWithUTF8String:notes->content().c_str()];
	
	notes->release();
	
	return result;
}

- (void)setNotes:(NSString *)notes
{
	if (!buddy)
		return;
	
	const char	*cnotes = [notes UTF8String];
	TCString	*tnotes;
	
	if (!cnotes)
		return;
	
	tnotes = new TCString(cnotes);
	
	buddy->setNotes(tnotes);
	
	tnotes->release();
}

- (NSImage *)localAvatar
{
	if (dispatch_get_current_queue() == mainQueue)
		return localAvatar;
	else
	{
		__block NSImage *result = nil;
		
		dispatch_sync(mainQueue, ^{
			
			result = [localAvatar retain];
		});
		
		return [result autorelease];
	}
}

- (void)setLocalAvatar:(NSImage *)avatar
{
	// Hold avatar
	dispatch_async(mainQueue, ^{
		
		[avatar retain];
		[localAvatar release];
		
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
	if (dispatch_get_current_queue() == mainQueue)
		return [self _profileAvatar];
	else
	{
		__block NSImage *result = nil;

		dispatch_sync(mainQueue, ^{

			result = [[self _profileAvatar] retain];
		});
		
		return [result autorelease];
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
	
		result = [profileName retain];
	});
	
	if (result)
		return [result autorelease];
	else
		return @"";
}

- (NSString *)lastProfileName
{
	TCString	*str = buddy->getLastProfileName();
	NSString	*result = [NSString stringWithUTF8String:str->content().c_str()];
	
	str->release();
	
	return result;
}

- (NSString *)profileText
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = [profileText retain];
	});
	
	if (result)
		return [result autorelease];
	else
		return @"";
}

- (NSString *)finalName
{
	TCString	*str = buddy->getFinalName();
	NSString	*result = [NSString stringWithUTF8String:str->content().c_str()];
	
	str->release();
	
	return result;
}



/*
** TCCocoaBuddy - Peer
*/
#pragma mark - TCCocoaBuddy - Peer

- (NSString *)peerVersion
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = [peerVersion retain];
	});
	
	if (result)
		return [result autorelease];
	else
		return @"";
}

- (NSString *)peerClient
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = [peerClient retain];
	});
	
	if (result)
		return [result autorelease];
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
	// -> Delegate are retained / released (no weak)
	// -> We remove the delegate when we don't wan't anymore an object (release, remove, etc)
	
	if (!buddy)
		return;
	
	buddy->setDelegate(0, NULL);
}



/*
** TCCocoaBuddy - File
*/
#pragma mark - TCCocoaBuddy - File

- (void)cancelFileUpload:(NSString *)uuid
{
	if (!buddy)
		return;
	
	buddy->fileCancel([uuid UTF8String], tcbuddy_file_send);
}

- (void)cancelFileDownload:(NSString *)uuid
{
	if (!buddy)
		return;
	
	buddy->fileCancel([uuid UTF8String], tcbuddy_file_receive);
}

- (void)sendFile:(NSString *)fileName
{
	if (!buddy)
		return;
	
	const char *fname = [fileName UTF8String];
	
	if (fname)
	{
		TCString *tname = new TCString(fname);
		
		buddy->sendFile(tname);
		
		tname->release();
	}
}



/*
** TCCocoaBuddy - Chat Delegate
*/
#pragma mark - TCCocoaBuddy - Chat Delegate

- (void)chatSendMessage:(NSString *)message forIdentifier:(NSString *)identifier
{
	if (!buddy)
		return;
	
	const char	*cmessage = [message UTF8String];
	
	if (cmessage)
	{
		TCString *tmessage = new TCString(cmessage);

		buddy->sendMessage(tmessage);
		
		tmessage->release();
	}
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
** TCCocoaBuddy - Private
*/
#pragma mark - TCCocoaBuddy - Private

- (void)initDelegate
{
	// Set the delegate to ourself
	buddy->setDelegate(mainQueue, ^(TCBuddy *aBuddy, const TCInfo *info) {
		
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
				TCImage			*img = dynamic_cast<TCImage *>(info->context());
				NSImage			*avatar = [[NSImage alloc] initWithTCImage:img];
				NSDictionary	*uinfo;
				
				// If no avatar, use standard user
				if ([[avatar representations] count] == 0)
				{
					[avatar release];
					
					avatar = [[NSImage imageNamed:NSImageNameUser] retain];
					
					[avatar setSize:NSMakeSize(64, 64)];
				}
				
				// Build notification info
				uinfo = [NSDictionary dictionaryWithObject:avatar forKey:@"avatar"];
				
				// Hold avatar
				[profileAvatar release];
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

				[profileText release];
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

				[profileName release];
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
				
				// Clean
				[omessage release];
				
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

				[peerVersion release];
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

				[peerClient release];
				peerClient = oclient;
				
				dispatch_async(noticeQueue, ^{
					
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedPeerClientNotification object:self userInfo:uinfo];					
				});
				
				break;
			}
			
			case tcbuddy_notify_file_send_start:
			{
				TCFileInfo *finfo = dynamic_cast<TCFileInfo *>(info->context());
				
				if (!finfo)
					return;
				
				// Get & convert arguments					
				NSString	*ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				NSString	*opath = [[NSString alloc] initWithUTF8String:finfo->filePath().c_str()];
				NSString	*obaddres = [[NSString alloc] initWithUTF8String:aBuddy->address().content().c_str()];
				TCString	*bname = aBuddy->getFinalName();
				NSString	*obname = [[NSString alloc] initWithUTF8String:bname->content().c_str()];
				
				// Add the file transfert to the controller
				[[TCFilesController sharedController] startFileTransfert:ouuid withFilePath:opath buddyAddress:obaddres buddyName:obname transfertWay:tcfile_upload fileSize:finfo->fileSizeTotal()];
				
				// Release
				[ouuid release];
				[opath release];
				[obaddres release];
				[obname release];
				
				bname->release();
				
				break;
			}
			
			case tcbuddy_notify_file_send_running:
			{
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				NSString	*ouuid;
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				
				// Update bytes received
				[[TCFilesController sharedController] setCompleted:finfo->fileSizeCompleted() forFileTransfert:ouuid withWay:tcfile_upload];
				
				// Release
				[ouuid release];
				
				break;
			}
			
			case tcbuddy_notify_file_send_finish:
			{
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				NSString	*ouuid;
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				
				// Update status					
				[[TCFilesController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_upload_done", @"") forFileTransfert:ouuid withWay:tcfile_upload];
				
				// Release
				[ouuid release];
				break;
			}
			
			case tcbuddy_notify_file_send_stoped:
			{
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				NSString	*ouuid;
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				
				// Update status
				[[TCFilesController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_upload_stoped", @"") forFileTransfert:ouuid withWay:tcfile_upload];
				
				// Release
				[ouuid release];
				break;
			}
			
			case tcbuddy_notify_file_receive_start:
			{
				TCFileInfo *finfo = dynamic_cast<TCFileInfo *>(info->context());
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				NSString	*ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				NSString	*opath = [[NSString alloc] initWithUTF8String:finfo->filePath().c_str()];
				NSString	*obaddres = [[NSString alloc] initWithUTF8String:aBuddy->address().content().c_str()];
				TCString	*bname = aBuddy->getFinalName();
				NSString	*obname = [[NSString alloc] initWithUTF8String:bname->content().c_str()];

				// Add the file transfert to the controller
				[[TCFilesController sharedController] startFileTransfert:ouuid withFilePath:opath buddyAddress:obaddres buddyName:obname transfertWay:tcfile_download fileSize:finfo->fileSizeTotal()];
				
				// Release
				[ouuid release];
				[opath release];
				[obaddres release];
				[obname release];
				
				bname->release();
				
				break;
			}
			
			case tcbuddy_notify_file_receive_running:
			{
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				NSString	*ouuid;
				
				if (!finfo)
					return;
				
				ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				
				// Update bytes received
				[[TCFilesController sharedController] setCompleted:finfo->fileSizeCompleted() forFileTransfert:ouuid withWay:tcfile_download];
				
				// Release
				[ouuid release];
				
				break;
			}
			
			case tcbuddy_notify_file_receive_finish:
			{
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				NSString	*ouuid;
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				
				// Update status					
				[[TCFilesController sharedController] setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_download_done", @"") forFileTransfert:ouuid withWay:tcfile_download];
				
				// Release
				[ouuid release];
				break;
			}
			
			case tcbuddy_notify_file_receive_stoped:
			{
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				NSString	*ouuid;
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				
				// Update status
				[[TCFilesController sharedController] setStatus:tcfile_status_stoped andTextStatus:NSLocalizedString(@"file_download_stoped", @"") forFileTransfert:ouuid withWay:tcfile_download];
				
				// Release
				[ouuid release];
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
				
				// Clean
				[full release];
				
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
				
				// Clean
				[full release];
				
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
