/*
 *  TCCocoaBuddy.mm
 *
 *  Copyright 2010 Avérous Julien-Pierre
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

#include "TCBuddy.h"
#include "TCInfo.h"



/*
** TCCocoaBuddy
*/
#pragma mark -
#pragma mark TCCocoaBuddy

@implementation TCCocoaBuddy


/*
** TCCocoaBuddy - Property
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Property

@synthesize delegate;



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

		// Retain the TCBuddy object handled by this object
		buddy = _buddy;
		buddy->retain();
		
		_status = tcbuddy_status_offline;
		
		// Set the delegate to ourself
		buddy->setDelegate(mainQueue, ^(TCBuddy *aBuddy, const TCInfo *info) {
			
			 // Add the error in the error manager
			 [[TCLogsController sharedController] addBuddyLogEntryFromAddress:[self address] name:[self name] andText:[NSString stringWithUTF8String:info->render().c_str()]];

			// Actions
			switch (info->infoCode())
			{
				case tcbuddy_notify_connected_tor:
					break;
					
				case tcbuddy_notify_connected_buddy:
					break;
					
				case tcbuddy_notify_disconnected:
					_status = tcbuddy_status_offline;
					
					[delegate buddyHasChanged:self];
					
					break;
					
				case tcbuddy_notify_identified:
					break;
					
				case tcbuddy_notify_status:
				{
					_status = buddy->status();
										
					[delegate buddyHasChanged:self];
					
					dispatch_async(dispatch_get_main_queue(), ^{
						
						NSString *ostatus = @"";

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
						
						if (chat)
							[chat receiveStatus:ostatus];
					});
					
					break;
				}
					
				case tcbuddy_notify_message:
				{
					NSMutableArray				*omessages = [[NSMutableArray alloc] init];
					std::vector<std::string *>	messages = buddy->getMessages();
					size_t						i, cnt = messages.size();
										
					// Convert the messages in Objective-C
					for (i = 0; i < cnt; i++)
					{
						std::string *msg = messages[i];
						NSString	*omsg = [[NSString alloc] initWithUTF8String:msg->c_str()];
						
						[omessages addObject:omsg];
						
						[omsg release];
						delete msg;
					}
					
					// Show the messages in main-thread (graphical operation)
					dispatch_async(dispatch_get_main_queue(), ^{
						
						// Check that we have a chat window
						if (!chat)
						{
							NSString *title = [NSString stringWithFormat:@"%@ (%@)", [self address], [self name]];
							
							chat = [[TCChatController chatWithName:title onDelegate:self] retain];
						}
						
						// Get the message from the buddy
						for (NSString *msg in omessages)
						{
							[chat receiveMessage:msg];
						}
						
						[omessages release];
					});
					
					break;
				}
					
				case tcbuddy_notify_info:
				{
					[delegate buddyHasChanged:self];
					
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
					NSString	*obaddres = [[NSString alloc] initWithUTF8String:aBuddy->address().c_str()];
					NSString	*obname = [[NSString alloc] initWithUTF8String:aBuddy->name().c_str()];
					
					// Add the file transfert to the controller
					[[TCFilesController sharedController] startFileTransfert:ouuid withFilePath:opath buddyAddress:obaddres buddyName:obname transfertWay:tcfile_upload fileSize:finfo->fileSizeTotal()];
					
					// Release
					[ouuid release];
					[opath release];
					[obaddres release];
					[obname release];
					
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
					NSString	*obaddres = [[NSString alloc] initWithUTF8String:aBuddy->address().c_str()];
					NSString	*obname = [[NSString alloc] initWithUTF8String:aBuddy->name().c_str()];

					
					// Add the file transfert to the controller
					[[TCFilesController sharedController] startFileTransfert:ouuid withFilePath:opath buddyAddress:obaddres buddyName:obname transfertWay:tcfile_download fileSize:finfo->fileSizeTotal()];
					
					// Release
					[ouuid release];
					[opath release];
					[obaddres release];
					[obname release];
					
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
	
	[chat setDelegate:nil];
	[chat release];
    
    [super dealloc];
}



/*
** TCCocoaBuddy - Status
*/
#pragma mark -
#pragma mark TCCocoaBuddy - Status

- (tcbuddy_status)status
{
	return _status;
}

- (NSString *)name
{
	if (!buddy)
		return @"";
	
	return [NSString stringWithUTF8String:buddy->name().c_str()];
}

- (NSString *)address
{
	if (!buddy)
		return @"";
	
	return [NSString stringWithUTF8String:buddy->address().c_str()];
}

- (NSString *)comment
{
	if (!buddy)
		return @"";
	
	return [NSString stringWithUTF8String:buddy->comment().c_str()];
}

- (void)setName:(NSString *)name
{
	if (!buddy)
		return;
	
	const char *cname = [name UTF8String];
	
	if (!cname)
		return;
	
	buddy->setName(cname);
}

- (void)setComment:(NSString *)comment
{
	if (!buddy)
		return;
	
	const char *ccomment = [comment UTF8String];
	
	if (!ccomment)
		return;
	
	buddy->setComment(ccomment);
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
		buddy->sendFile(fname);
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
	std::string	ccmessage(cmessage);
	
	if (cmessage)
		buddy->sendMessage(ccmessage);
}

- (void)openChatWindow
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Check that we have a chat window
		if (!chat)
		{
			NSString *title = [NSString stringWithFormat:@"%@ (%@)", [self name], [self address]];
			
			chat = [[TCChatController chatWithName:title onDelegate:self] retain];
		}
		
		[chat openWindow];
	});
}

@end
