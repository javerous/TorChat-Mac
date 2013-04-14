/*
 *  TCCocoaBuddy.mm
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
#pragma mark -
#pragma mark TCCocoaBuddy

@interface TCCocoaBuddy ()

- (void)initDelegate;
- (void)_openChatWindow;

@end



/*
** TCCocoaBuddy
*/
#pragma mark -
#pragma mark TCCocoaBuddy

@implementation TCCocoaBuddy


/*
** TCCocoaBuddy - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Constructor & Destructor


- (id)initWithBuddy:(TCBuddy *)_buddy
{
    if ((self = [super init]))
	{
		// Build a queue
		mainQueue = dispatch_queue_create("com.torchat.cocoa.buddy.main", NULL);
		noticeQueue = dispatch_queue_create("com.torchat.cocoa.buddy.notice", NULL);

		// Retain the TCBuddy object handled by this object
		buddy = _buddy;
		buddy->retain();
		
		_status = tcbuddy_status_offline;
		
		// Init the buddy delegate
		[self initDelegate];
		
		// Observe notifications
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(controllerAvatarChanged:) name:TCBuddiesControllerAvatarChanged object:nil];
    }
    
    return self;
}

- (void)dealloc
{
	TCDebugLog("Cocoa buddy release");
	
	// Clean delegate
	buddy->setDelegate(0, NULL);
	buddy->release();
	
	// Release queue
	dispatch_release(mainQueue);
	dispatch_release(noticeQueue);
	
	// release chat window
	[chat setDelegate:nil];
	[chat release];
	
	// Release cache
	[_pavatar release];
	[_pname release];
	[_ptext release];
	
	[_cpavatar release];
	
	// Remove notification
	[[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [super dealloc];
}



/*
** TCCocoaBuddy - Status
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Status

- (tcbuddy_status)status
{
	__block tcbuddy_status result;
	
	dispatch_sync(mainQueue, ^{
		
		result = _status;
	});
	
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

- (NSString *)address
{
	if (!buddy)
		return @"";
	
	TCString	&address = buddy->address();
	NSString	*result = [NSString stringWithUTF8String:address.content().c_str()];
		
	return result;
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

- (void)setControllerAvatar:(NSImage *)avatar
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[avatar retain];
		[_cpavatar release];
		
		_cpavatar = avatar;
		
		if (chat)
			[chat setLocalAvatar:avatar];
	});
}



/*
** TCCocoaBuddy - Profile
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Profile

- (NSImage *)profileAvatar
{
	__block NSImage *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = [_pavatar retain];
	});
	
	if (result)
		return [result autorelease];
	else
		return [NSImage imageNamed:NSImageNameUser];
}

- (NSString *)profileName
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = [_pname retain];
	});
	
	if (result)
		return [result autorelease];
	else
		return @"";
}

- (NSString *)profileText
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		
		result = [_ptext retain];
	});
	
	if (result)
		return [result autorelease];
	else
		return @"";
}



/*
** TCCocoaBuddy - Actions
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Actions

- (void)openChatWindow
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[self _openChatWindow];
	});
}

- (void)_openChatWindow
{
	// > dipsatch main queue <
	
	// Check that we have a chat window
	if (!chat)
	{
		NSString *title = [NSString stringWithFormat:@"%@ (%@)", [self alias], [self address]];
		
		chat = [[TCChatController chatWithName:title onDelegate:self] retain];
		
		[chat setLocalAvatar:_cpavatar];
		[chat setRemoteAvatar:[self profileAvatar]];
	}
	
	[chat openWindow];
}



/*
** TCCocoaBuddy - Handling
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Handling

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
#pragma mark -
#pragma mark TCCocoaBuddy - File

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
#pragma mark -
#pragma mark TCCocoaBuddy - Chat Delegate

- (void)chat:(TCChatController *)aChat sendMessage:(NSString *)message
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
#pragma mark -
#pragma mark TCCocoaBuddy - Notifications

- (void)controllerAvatarChanged:(NSNotification *)notice
{
	NSImage *image = [[notice userInfo] objectForKey:@"avatar"];
	
	[self setControllerAvatar:image];
}



/*
** TCCocoaBuddy - Private
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Private

- (void)initDelegate
{
	// Set the delegate to ourself
	buddy->setDelegate(mainQueue, ^(TCBuddy *aBuddy, const TCInfo *info) {
		
		// Add the error in the error manager
		[[TCLogsController sharedController] addBuddyLogEntryFromAddress:[self address] alias:[self alias] andText:[NSString stringWithUTF8String:info->render().c_str()]];
		
		// Actions
		switch (info->infoCode())
		{
			case tcbuddy_notify_connected_tor:
				break;
				
			case tcbuddy_notify_connected_buddy:
				break;
				
			case tcbuddy_notify_disconnected:
			{
				NSDictionary *info;
				
				_status = tcbuddy_status_offline;
				
				// Build notification info
				info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_status] forKey:@"status"];
				
				dispatch_async(noticeQueue, ^{
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:self userInfo:info];					
				});
				
				break;
			}
				
			case tcbuddy_notify_identified:
				break;
				
			case tcbuddy_notify_status:
			{
				TCNumber		*status = dynamic_cast<TCNumber *>(info->context());
				NSDictionary	*info;

				// Update status
				_status = (tcbuddy_status)status->uint8Value();
				
				// Build notification info
				info = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:_status] forKey:@"status"];

				// Send notification
				dispatch_async(noticeQueue, ^{
					
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedStatusNotification object:self userInfo:info];					
				});
				
				// Send status to chat window
				dispatch_async(dispatch_get_main_queue(), ^{
					
					NSString *ostatus = @"";
					
					// Show status in chat
					if (chat)
					{
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
						
						[chat receiveStatus:ostatus];
					}
				});
				
				break;
			}
				
			case tcbuddy_notify_profile_avatar:
			{
				TCImage	*img = dynamic_cast<TCImage *>(info->context());
				NSImage *avatar = [[NSImage alloc] initWithTCImage:img];
				
				[_pavatar release];
				_pavatar = avatar;
				
				// Notify of the new avatar
				dispatch_async(noticeQueue, ^{
					
					NSDictionary *info = [NSDictionary dictionaryWithObject:avatar forKey:@"avatar"];

					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedAvatarNotification object:self userInfo:info];					
				});
				
				// Set the new avatar to the chat window
				dispatch_async(dispatch_get_main_queue(), ^{
					[chat setRemoteAvatar:_pavatar];
				});
										  
				break;
			}
				
			case tcbuddy_notify_profile_text:
			{
				TCString *text = dynamic_cast<TCString *>(info->context());
				
				[_ptext release];
				_ptext = [[NSString alloc] initWithUTF8String:text->content().c_str()];
				
				dispatch_async(noticeQueue, ^{
					
					NSDictionary *info = [NSDictionary dictionaryWithObject:_ptext forKey:@"text"];
					
					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedTextNotification object:self userInfo:info];					
				});
				
				break;
			}
				
			case tcbuddy_notify_profile_name:
			{
				TCString *name = dynamic_cast<TCString *>(info->context());

				[_pname release];
				_pname = [[NSString alloc] initWithUTF8String:name->content().c_str()];
				
				dispatch_async(noticeQueue, ^{
					
					NSDictionary *info = [NSDictionary dictionaryWithObject:_pname forKey:@"name"];

					[[NSNotificationCenter defaultCenter] postNotificationName:TCCocoaBuddyChangedNameNotification object:self userInfo:info];					
				});
				
				break;
			}	
				
			case tcbuddy_notify_message:
			{
				TCString	*message = dynamic_cast<TCString *>(info->context());
				NSString	*omessage = [[NSString alloc] initWithUTF8String:message->content().c_str()];
				
				
				// Show the messages in main-thread (graphical operation)
				dispatch_async(dispatch_get_main_queue(), ^{
					
					// Open chat window if needed
					[self _openChatWindow];
					
					// Get the message from the buddy
					[chat receiveMessage:omessage];
					
					// Release
					[omessage release];
				});
				
				break;
			}
				
			case tcbuddy_notify_alias:
			{
				TCString *alias = dynamic_cast<TCString *>(info->context());
				
				(void)alias;
				break;
			}
				
			case tcbuddy_notify_notes:
			{
				TCString *notes = dynamic_cast<TCString *>(info->context());

				(void)notes;
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
				NSString	*obalias = [[NSString alloc] initWithUTF8String:aBuddy->alias()->content().c_str()];
				
				// Add the file transfert to the controller
				[[TCFilesController sharedController] startFileTransfert:ouuid withFilePath:opath buddyAddress:obaddres buddyAlias:obalias transfertWay:tcfile_upload fileSize:finfo->fileSizeTotal()];
				
				// Release
				[ouuid release];
				[opath release];
				[obaddres release];
				[obalias release];
				
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
				TCFileInfo	*finfo = dynamic_cast<TCFileInfo *>(info->context());
				
				if (!finfo)
					return;
				
				// Get & convert arguments
				NSString	*ouuid = [[NSString alloc] initWithUTF8String:finfo->uuid().c_str()];
				NSString	*opath = [[NSString alloc] initWithUTF8String:finfo->filePath().c_str()];
				NSString	*obaddres = [[NSString alloc] initWithUTF8String:aBuddy->address().content().c_str()];
				NSString	*obalias = [[NSString alloc] initWithUTF8String:aBuddy->alias()->content().c_str()];
				
				
				// Add the file transfert to the controller
				[[TCFilesController sharedController] startFileTransfert:ouuid withFilePath:opath buddyAddress:obaddres buddyAlias:obalias transfertWay:tcfile_download fileSize:finfo->fileSizeTotal()];
				
				// Release
				[ouuid release];
				[opath release];
				[obaddres release];
				[obalias release];
				
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
				
			case tcbuddy_error_message_offline:
			{
				NSString	*message = [[NSString alloc] initWithUTF8String:info->info().c_str()];
				NSString	*full = [[NSString alloc] initWithFormat:NSLocalizedString(@"bd_error_offline", ""), message];
				
				dispatch_async(dispatch_get_main_queue(), ^{
					
					// Show the error in the window if active
					if (chat)
						[chat receiveError:full];
					
					// Clean
					[full release];
					[message release];
				});
				
				break;
			}
		}
	});
}


@end
