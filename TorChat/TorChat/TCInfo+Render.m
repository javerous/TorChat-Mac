<<<<<<< HEAD
//
//  TCInfo+Render.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 08/08/2014.
//  Copyright (c) 2014 SourceMac. All rights reserved.
//
=======
/*
 *  TCInfo+Render.m
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
>>>>>>> javerous/master

#import "TCInfo+Render.h"

#import "TCBuddy.h"
#import "TCSocket.h"
#import "TCConnection.h"
#import "TCCoreManager.h"
#import "TCTorManager.h"

<<<<<<< HEAD
#import "TCTextConstants.h"

=======
>>>>>>> javerous/master

/*
** Defines
*/
#pragma mark - Defines

<<<<<<< HEAD
#define TCInfoNameKey		@"name"
#define TCInfoTextKey		@"text"
#define TCInfoDynTextKey	@"dyn_text"

=======
#define TCInfoNameKey			@"name"
#define TCInfoTextKey			@"text"
#define TCInfoDynTextKey		@"dyn_text"
#define TCInfoLocalizableKey	@"localizable"
>>>>>>> javerous/master



/*
** TCInfoRender
*/
#pragma mark - TCInfoRender

@implementation TCInfo (TCInfoRender)

<<<<<<< HEAD

- (NSString *)render
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Add the log time.
	[result appendString:[self.date description]];
	
=======
- (NSString *)renderComplete
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
>>>>>>> javerous/master
	// Get info.
	NSDictionary *infos = [[self class] renderInfo][self.domain][@(self.kind)][@(self.code)];
	
	if (!infos)
	{
<<<<<<< HEAD
		[result appendFormat:@" - Unknow"];
=======
		[result appendFormat:@"Unknow (domain='%@'; kind=%d; code=%d", self.domain, self.kind, self.code];
>>>>>>> javerous/master
		
		return result;
	}
	
	// Add the error name.
<<<<<<< HEAD
	[result appendFormat:@" - [%@]: ", infos[TCInfoNameKey]];
	
	// Add the info string
	NSString *text = infos[TCInfoTextKey];
	
	if (!text)
	{
		NSString * (^dyn)(TCInfo *) =  infos[TCInfoDynTextKey];
		
		if (dyn)
			text = dyn(self);
	}
	
	if (text)
		[result appendString:NSLocalizedString(text, @"")];
=======
	[result appendFormat:@"[%@] ", infos[TCInfoNameKey]];
	
	// Add the message string
	NSString *msg = [self renderMessage];
	
	if (msg)
		[result appendString:msg];
>>>>>>> javerous/master
	
	// Ad the sub-info
	if (self.subInfo)
	{
		[result appendString:@" "];
		[result appendString:[self.subInfo _render]];
	}
	
	return result;
}

- (NSString *)_render
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Get info.
	NSDictionary *infos = [[self class] renderInfo][self.domain][@(self.kind)][@(self.code)];
	
	if (!infos)
	{
		[result appendFormat:@"{Unknow}"];
		
		return result;
	}
	
	// Add the errcode and the info
	[result appendFormat:@"{%@ - ", infos[TCInfoNameKey]];
	
<<<<<<< HEAD
	// Add the info string
	NSString *text = infos[TCInfoTextKey];
	
	if (!text)
	{
		NSString * (^dyn)(TCInfo *) =  infos[TCInfoDynTextKey];
		
		if (dyn)
			text = dyn(self);
	}
	
	if (text)
		[result appendString:NSLocalizedString(text, @"")];
=======
	// Add the message string
	NSString *msg = [self renderMessage];

	if (msg)
		[result appendString:msg];
>>>>>>> javerous/master
	
	// Add the other sub-info
	if (self.subInfo)
	{
		[result appendString:@" "];
		[result appendString:[self.subInfo _render]];
	}
	
	[result appendString:@"}"];
	
	return result;
}

<<<<<<< HEAD
=======
- (NSString *)renderMessage
{
	NSDictionary	*infos = [[self class] renderInfo][self.domain][@(self.kind)][@(self.code)];
	NSString		*msg = infos[TCInfoTextKey];
	
	if (!msg)
	{
		NSString * (^dyn)(TCInfo *) =  infos[TCInfoDynTextKey];
		
		if (dyn)
			msg = dyn(self);
	}
	
	if (msg)
	{
		if ([infos[TCInfoLocalizableKey] boolValue])
			return NSLocalizedString(msg, @"");
		else
			return msg;
	}
	
	return nil;
}

>>>>>>> javerous/master


/*
** TCInfoRender - Info
*/
#pragma mark - TCInfoRender - Info

+ (NSDictionary *)renderInfo
{
	static NSDictionary		*renderInfo = nil;
	static dispatch_once_t	onceToken;
	
	dispatch_once(&onceToken, ^{
		
		renderInfo = @{
			
			// == TCBuddyInfoDomain ==
			TCBuddyInfoDomain : @{
					@(TCInfoInfo) :
						@{
							@(TCBuddyEventConnectedTor) :
								@{
									TCInfoNameKey : @"TCBuddyEventConnectedTor",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteTorConnected,
=======
									TCInfoTextKey : @"core_bd_event_tor_connected",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventConnectedBuddy) :
								@{
									TCInfoNameKey : @"TCBuddyEventConnectedBuddy",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteConnected,
=======
									TCInfoTextKey : @"core_bd_event_connected",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventDisconnected) :
								@{
									TCInfoNameKey : @"TCBuddyEventDisconnected",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteStopped,
=======
									TCInfoTextKey : @"core_bd_event_stopped",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventIdentified) :
								@{
									TCInfoNameKey : @"TCBuddyEventIdentified",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteIdentified,
=======
									TCInfoTextKey : @"core_bd_event_identified",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventStatus) :
								@{
									TCInfoNameKey : @"TCBuddyEventStatus",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteStatusChanged,
=======
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										
										NSString *status = @"-";
										
										switch ([info.context intValue])
										{
											case TCStatusOffline:	status = NSLocalizedString(@"bd_status_offline", @""); break;
											case TCStatusAvailable: status = NSLocalizedString(@"bd_status_available", @""); break;
											case TCStatusAway:		status = NSLocalizedString(@"bd_status_away", @""); break;
											case TCStatusXA:		status = NSLocalizedString(@"bd_status_xa", @""); break;
										}
										
										return [NSString stringWithFormat:NSLocalizedString(@"core_bd_event_status_changed", @""), status];
									},
									TCInfoLocalizableKey : @NO,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventMessage) :
								@{
									TCInfoNameKey : @"TCBuddyEventMessage",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNewMessage,
=======
									TCInfoTextKey : @"core_bd_event_new_message",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventAlias) :
								@{
									TCInfoNameKey : @"TCBuddyEventAlias",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteAliasChanged,
=======
									TCInfoTextKey : @"core_bd_event_alias_changed",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventNotes) :
								@{
									TCInfoNameKey : @"TCBuddyEventNotes",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNotesChanged,
=======
									TCInfoTextKey : @"core_bd_event_notes_changed",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventVersion) :
								@{
									TCInfoNameKey : @"TCBuddyEventVersion",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNewVersion,
=======
									TCInfoTextKey : @"core_bd_event_new_version",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventClient) :
								@{
									TCInfoNameKey : @"TCBuddyEventClient",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNewClient,
								},
							
							@(TCBuddyEventBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyEventBlocked",
									TCInfoTextKey : TCCoreBuddyNoteBlockedChanged,
=======
									TCInfoTextKey : @"core_bd_event_new_client",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileSendStart) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendStart",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileSendStart,
=======
									TCInfoTextKey : @"core_bd_event_file_send_start",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileSendRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendRunning",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileChunkSend,
=======
									TCInfoTextKey : @"core_bd_event_file_chunk_send",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileSendFinish) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendFinish",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileSendFinish,
=======
									TCInfoTextKey : @"core_bd_event_file_send_finish",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileSendStopped) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendStopped",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileSendCanceled,
=======
									TCInfoTextKey : @"core_bd_event_file_send_canceled",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileReceiveStart) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveStart",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileReceiveStart,
								},
							
							@(TCBuddyEventFileReceiveRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveRunning",
									TCInfoTextKey : TCCoreBuddyNoteFileChunkReceive,
=======
									TCInfoTextKey : @"core_bd_event_file_receive_start",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileReceiveRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveRunning",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileChunkReceive,
=======
									TCInfoTextKey : @"core_bd_event_file_chunk_receive",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileReceiveFinish) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveFinish",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileReceiveFinish,
=======
									TCInfoTextKey : @"core_bd_event_file_receive_finish",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventFileReceiveStopped) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveStopped",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteFileReceiveStopped,
=======
									TCInfoTextKey : @"core_bd_event_file_receive_stopped",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventProfileText) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileText",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNewProfileText,
								},
							
							@(TCBuddyEventProfileText) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileText",
									TCInfoTextKey : TCCoreBuddyNoteNewProfileText,
=======
									TCInfoTextKey : @"core_bd_event_new_profile_text",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventProfileName) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileName",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNewProfileName,
=======
									TCInfoTextKey : @"core_bd_event_new_profile_name",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyEventProfileAvatar) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileAvatar",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyNoteNewProfileAvatar,
=======
									TCInfoTextKey : @"core_bd_event_new_profile_avatar",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCBuddyErrorResolveTor) :
								@{
									TCInfoNameKey : @"TCBuddyErrorResolveTor",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorTorResolve,
=======
									TCInfoTextKey : @"core_bd_error_tor_resolve",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorConnectTor) :
								@{
									TCInfoNameKey : @"TCBuddyErrorConnectTor",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorTorConnect,
=======
									TCInfoTextKey : @"core_bd_error_tor_connect",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorSocket) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSocket",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorSocket,
=======
									TCInfoTextKey : @"core_bd_error_socket",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorSocks) :
								@{
<<<<<<< HEAD
									TCInfoNameKey : @"TCBuddyErrorSocket",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										
										if ([info.context intValue] == 91)
											return TCCoreBuddyErrorSocks91;
										else if ([info.context intValue] == 92)
											return TCCoreBuddyErrorSocks92;
										else if ([info.context intValue] == 93)
											return TCCoreBuddyErrorSocks93;
										else
											return TCCoreBuddyErrorSocksUnknown;
									},
=======
									TCInfoNameKey : @"TCBuddyErrorSocks",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										
										if ([info.context intValue] == 91)
											return @"core_bd_error_socks_91";
										else if ([info.context intValue] == 92)
											return @"core_bd_error_socks_92";
										else if ([info.context intValue] == 93)
											return @"core_bd_error_socks_93";
										else
											return @"core_bd_error_socks_unknown";
									},
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorSocksRequest) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSocksRequest",
									TCInfoTextKey : @"core_bd_error_socks_request",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorMessageOffline) :
								@{
									TCInfoNameKey : @"TCBuddyErrorMessageOffline",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorMessageOffline,
=======
									TCInfoTextKey : @"core_bd_error_message_offline",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorMessageBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyErrorMessageBlocked",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorMessageBlocked,
=======
									TCInfoTextKey : @"core_bd_error_message_blocked",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorSendFile) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSendFile",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorFileSend,
=======
									TCInfoTextKey : @"core_bd_error_filesend",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorReceiveFile) :
								@{
									TCInfoNameKey : @"TCBuddyErrorReceiveFile",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorFileReceive,
=======
									TCInfoTextKey : @"core_bd_error_filereceive",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorFileOffline) :
								@{
									TCInfoNameKey : @"TCBuddyErrorFileOffline",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorFileOffline,
=======
									TCInfoTextKey : @"core_bd_error_file_offline",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorFileBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyErrorFileBlocked",
<<<<<<< HEAD
									TCInfoTextKey : TCCoreBuddyErrorFileBlocked,
=======
									TCInfoTextKey : @"core_bd_error_file_blocked",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCBuddyErrorParse) :
								@{
									TCInfoNameKey : @"TCBuddyErrorParse",
								},
						}
				},
			
				// == TCSocketInfoDomain ==
				TCSocketInfoDomain: @{
					@(TCInfoError) :
						@{
							@(TCSocketErrorRead) :
								@{
									TCInfoNameKey : @"TCSocketErrorRead",
									TCInfoTextKey : @"core_socket_read_error",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCSocketErrorReadClosed) :
								@{
									TCInfoNameKey : @"TCSocketErrorReadClosed",
									TCInfoTextKey : @"core_socket_read_closed",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCSocketErrorReadFull) :
								@{
									TCInfoNameKey : @"TCSocketErrorReadFull",
									TCInfoTextKey : @"core_socker_read_full",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCSocketErrorWrite) :
								@{
									TCInfoNameKey : @"TCSocketErrorWrite",
									TCInfoTextKey : @"core_socket_write_error",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCSocketErrorWriteClosed) :
								@{
									TCInfoNameKey : @"TCSocketErrorWriteClosed",
									TCInfoTextKey : @"core_socket_write_closed",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						}
				},
			
				// == TCConnectionInfoDomain ==
				TCConnectionInfoDomain: @{
<<<<<<< HEAD
=======
					@(TCInfoInfo) :
						@{
							@(TCCoreEventClientStarted) :
								@{
									TCInfoNameKey : @"TCCoreEventClientStarted",
									TCInfoTextKey : @"core_cnx_event_started",
									TCInfoLocalizableKey : @YES,
							},
							
							@(TCCoreEventClientStopped) :
								@{
									TCInfoNameKey : @"TCCoreEventClientStopped",
									TCInfoTextKey : @"core_cnx_event_stopped",
									TCInfoLocalizableKey : @YES,
							},
						},
					
>>>>>>> javerous/master
					@(TCInfoError) :
						@{
							@(TCCoreErrorSocket) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocket",
									TCInfoTextKey : @"core_cnx_error_socket",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorClientCmdPing) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdPing",
									TCInfoTextKey : @"core_cnx_error_fake_ping",
<<<<<<< HEAD
								},
							
							@(TCCoreEventClientStarted) :
								@{
									TCInfoNameKey : @"TCCoreEventClientStarted",
									TCInfoTextKey : @"core_cnx_event_started",
								},
						}
				},
=======
									TCInfoLocalizableKey : @YES,
								},
						}
					},
>>>>>>> javerous/master
			
				// == TCCoreManagerInfoDomain ==
				TCCoreManagerInfoDomain: @{
					@(TCInfoInfo) :
						@{
							@(TCCoreEventBuddyNew) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyNew",
<<<<<<< HEAD
									TCInfoTextKey : @"core_mng_event_new_buddy",
=======
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										TCBuddy *buddy = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_new_buddy", @""), buddy.address];
									},
									TCInfoLocalizableKey : @NO,
								},
							
							@(TCCoreEventBuddyRemove) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyRemove",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										TCBuddy *buddy = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_remove_buddy", @""), buddy.address];
									},
									TCInfoLocalizableKey : @NO,
								},
							
							@(TCCoreEventBuddyBlocked) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyBlocked",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										TCBuddy *buddy = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_blocked_buddy", @""), buddy.address];
									},
									TCInfoLocalizableKey : @NO,
								},
							
							@(TCCoreEventBuddyUnblocked) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyUnblocked",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										TCBuddy *buddy = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_unblock_buddy", @""), buddy.address];
									},
									TCInfoLocalizableKey : @NO,
>>>>>>> javerous/master
								},
							
							@(TCCoreEventStarted) :
								@{
									TCInfoNameKey : @"TCCoreEventStarted",
									TCInfoTextKey : @"core_mng_event_started",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreEventStopped) :
								@{
									TCInfoNameKey : @"TCCoreEventStopped",
									TCInfoTextKey : @"core_mng_event_stopped",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreEventStatus) :
								@{
									TCInfoNameKey : @"TCCoreEventStatus",
<<<<<<< HEAD
									TCInfoTextKey : @"",
=======
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										
										NSString *status = @"-";
										
										switch ([info.context intValue])
										{
											case TCStatusOffline:	status = NSLocalizedString(@"bd_status_offline", @""); break;
											case TCStatusAvailable: status = NSLocalizedString(@"bd_status_available", @""); break;
											case TCStatusAway:		status = NSLocalizedString(@"bd_status_away", @""); break;
											case TCStatusXA:		status = NSLocalizedString(@"bd_status_xa", @""); break;
										}
										
										return [NSString stringWithFormat:NSLocalizedString(@"core_mng_event_status", @""), status];
									},
									TCInfoLocalizableKey : @NO,
>>>>>>> javerous/master
								},
							
							@(TCCoreEventProfileAvatar) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileAvatar",
									TCInfoTextKey : @"core_mng_event_profile_avatar",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreEventProfileName) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileName",
									TCInfoTextKey : @"core_mng_event_profile_name",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreEventProfileText) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileText",
<<<<<<< HEAD
									TCInfoTextKey : @"core_mng_event_profile_name",
								},
							
							@(TCCoreEventBuddyNew) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyNew",
									TCInfoTextKey : @"core_mng_event_new_buddy",
=======
									TCInfoTextKey : @"core_mng_event_profile_text",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCCoreErrorSocketCreate) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketCreate",
									TCInfoTextKey : @"core_mng_error_socket",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorSocketOption) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketOption",
									TCInfoTextKey : @"core_mng_error_setsockopt",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorSocketBind) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketBind",
									TCInfoTextKey : @"core_mng_error_bind",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorSocketListen) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketListen",
									TCInfoTextKey : @"core_mng_error_listen",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorServAccept) :
								@{
									TCInfoNameKey : @"TCCoreErrorServAccept",
									TCInfoTextKey : @"core_mng_error_accept",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorServAcceptAsync) :
								@{
									TCInfoNameKey : @"TCCoreErrorServAcceptAsync",
									TCInfoTextKey : @"core_mng_error_async",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorClientAlreadyPinged) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientAlreadyPinged",
									TCInfoTextKey : @"core_cnx_error_already_pinged",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorClientMasquerade) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientMasquerade",
									TCInfoTextKey : @"core_cnx_error_masquerade",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorClientAddBuddy) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientAddBuddy",
									TCInfoTextKey : @"core_cnx_error_add_buddy",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientCmdUnknownCommand):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdUnknownCommand",
>>>>>>> javerous/master
								},
							
							@(TCCoreErrorClientCmdPong) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdPong",
									TCInfoTextKey : @"core_cnx_error_pong",
<<<<<<< HEAD
=======
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientCmdStatus):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdStatus",
								},
							
							@(TCCoreErrorClientCmdVersion):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdVersion",
								},
							
							@(TCCoreErrorClientCmdClient):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdClient",
								},
							
							@(TCCoreErrorClientCmdProfileText):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdProfileText",
								},
							
							@(TCCoreErrorClientCmdProfileName):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdProfileName",
								},
							
							@(TCCoreErrorClientCmdProfileAvatar):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdProfileAvatar",
								},
							
							@(TCCoreErrorClientCmdProfileAvatarAlpha):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdProfileAvatarAlpha",
								},
							
							@(TCCoreErrorClientCmdMessage):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdMessage",
								},
							
							@(TCCoreErrorClientCmdAddMe):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdAddMe",
								},
							
							@(TCCoreErrorClientCmdRemoveMe):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdRemoveMe",
								},
							
							@(TCCoreErrorClientCmdFileName):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdFileName",
								},
							
							@(TCCoreErrorClientCmdFileData):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdFileData",
								},
							
							@(TCCoreErrorClientCmdFileDataOk):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdFileDataOk",
								},
							
							@(TCCoreErrorClientCmdFileDataError):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdFileDataError",
								},
							
							@(TCCoreErrorClientCmdFileStopSending):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdFileStopSending",
								},
							
							@(TCCoreErrorClientCmdFileStopReceiving):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdFileStopReceiving",
>>>>>>> javerous/master
								},
						}
				},
			
				// == TCTorManagerInfoStartDomain ==
				TCTorManagerInfoStartDomain : @{
					@(TCInfoInfo) :
						@{
<<<<<<< HEAD
							@(TCTorManagerEventStartHostname) :
								@{
									TCInfoNameKey : @"TCTorManagerInfoStartHostname",
									TCInfoTextKey : @"<fixme>", // FIXME
=======
							@(TCTorManagerEventStartBootstrapping) :
								@{
									TCInfoNameKey : @"TCTorManagerEventStartBootstrapping",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										NSDictionary	*context = info.context;
										NSNumber		*progress = context[@"progress"];
										NSString		*summary = context[@"summary"];
										
										return [NSString stringWithFormat:NSLocalizedString(@"tor_start_info_bootstrap", @""), [progress unsignedIntegerValue], summary];
									},
									TCInfoLocalizableKey : @NO,
								},
							
							
							@(TCTorManagerEventStartHostname) :
								@{
									TCInfoNameKey : @"TCTorManagerEventStartHostname",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										return [NSString stringWithFormat:NSLocalizedString(@"tor_start_info_hostname", @""), info.context];
									},
									TCInfoLocalizableKey : @NO,
								},
							
							@(TCTorManagerEventStartURLSession) :
								@{
									TCInfoNameKey : @"TCTorManagerEventStartURLSession",
									TCInfoTextKey : @"tor_start_info_url_session",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventStartDone) :
								@{
<<<<<<< HEAD
									TCInfoNameKey : @"TCTorManagerInfoStartDone",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
					},
=======
									TCInfoNameKey : @"TCTorManagerEventStartDone",
									TCInfoTextKey : @"tor_start_info_done",
									TCInfoLocalizableKey : @YES,
								},
						},
					
					@(TCInfoWarning) :
						@{
							@(TCTorManagerWarningStartCanceled) :
								@{
									TCInfoNameKey : @"TCTorManagerWarningStartCanceled",
									TCInfoTextKey : @"tor_start_warning_canceled",
									TCInfoLocalizableKey : @YES,
								},
						},
>>>>>>> javerous/master
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorStartAlreadyRunning) :
								@{
<<<<<<< HEAD
									TCInfoNameKey : @"TCTorManagerInfoStartHostname",
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoNameKey : @"TCTorManagerErrorStartAlreadyRunning",
									TCInfoTextKey : @"tor_start_err_already_running",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorStartConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartConfiguration",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_start_err_configuration",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorStartUnarchive) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartUnarchive",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_start_err_unarchive",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorStartSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartSignature",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_start_err_signature",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorStartLaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartLaunch",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_start_err_launch",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartControlConnect) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartControlConnect",
									TCInfoTextKey : @"tor_start_err_control_connect",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartControlAuthenticate) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartControlAuthenticate",
									TCInfoTextKey : @"tor_start_err_control_authenticate",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartControlMonitor) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartControlMonitor",
									TCInfoTextKey : @"tor_start_err_control_monitor",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						}
				},
			
				// == TCTorManagerInfoCheckUpdateDomain ==
				TCTorManagerInfoCheckUpdateDomain : @{
					@(TCInfoInfo) :
						@{
							@(TCTorManagerEventCheckUpdateAvailable) :
								@{
									TCInfoNameKey : @"TCTorManagerEventCheckUpdateAvailable",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										NSDictionary *context = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"tor_checkupdate_info_version_available", @""), context[@"new_version"]];
									},
									TCInfoLocalizableKey : @NO,
>>>>>>> javerous/master
								},
						},
					   
					@(TCInfoError) :
						@{
<<<<<<< HEAD
							@(TCTorManagerErrorCheckUpdateNetworkRequest) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateNetworkRequest",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
							   
							   
							@(TCTorManagerErrorCheckUpdateBadServerReply) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateBadServerReply",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
							   
							@(TCTorManagerErrorCheckUpdateRemoteInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateRemoteInfo",
									TCInfoTextKey : @"<fixme>", // FIXME
=======
							@(TCTorManagerErrorCheckUpdateTorNotRunning) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateTorNotRunning",
									TCInfoTextKey : @"tor_checkupdate_error_not_running",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorRetrieveRemoteInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorRetrieveRemoteInfo",
									TCInfoTextKey : @"tor_checkupdate_error_check_remote_info",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							   
							@(TCTorManagerErrorCheckUpdateLocalSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateLocalSignature",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_checkupdate_error_validate_local_signature",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							   
							@(TCTorManagerErrorCheckUpdateNothingNew) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateNothingNew",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_checkupdate_error_nothing_new",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						}
				},
			
				// == TCTorManagerInfoUpdateDomain ==
				TCTorManagerInfoUpdateDomain : @{
					@(TCInfoInfo) :
						@{
							@(TCTorManagerEventUpdateArchiveInfoRetrieving) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveInfoRetrieving",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_info_retrieve_info",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventUpdateArchiveSize) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveSize",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										NSNumber *context = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"tor_update_info_archive_size", @""), [context unsignedLongLongValue]];
									},
									TCInfoLocalizableKey : @NO,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventUpdateArchiveDownloading) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveDownloading",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_info_downloading",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventUpdateArchiveStage) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveStage",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_info_stage",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventUpdateSignatureCheck) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateSignatureCheck",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_info_signature_check",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventUpdateRelaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateRelaunch",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_info_relaunch",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerEventUpdateDone) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateDone",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_info_done",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorUpdateTorNotRunning) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateTorNotRunning",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_not_running",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorUpdateConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateConfiguration",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_configuration",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorUpdateInternal) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateInternal",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_internal",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorUpdateArchiveInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveInfo",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_archive_info",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorUpdateArchiveDownload) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveDownload",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_archive_download",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorUpdateArchiveStage) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveStage",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_archive_stage",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
							
							@(TCTorManagerErrorUpdateRelaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateRelaunch",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_update_err_relaunch",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						}
				},
			
				// == TCTorManagerInfoOperationDomain ==
				TCTorManagerInfoOperationDomain : @{
					@(TCInfoInfo) :
						@{
<<<<<<< HEAD
							@(TCTorManagerEventInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerEventInfo",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
							
							@(TCTorManagerEventDone) :
								@{
									TCInfoNameKey : @"TCTorManagerEventDone",
									TCInfoTextKey : @"<fixme>", // FIXME
=======
							@(TCTorManagerEventOperationInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerEventOperationInfo",
									TCInfoTextKey : @"tor_operation_info_info",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerEventOperationDone) :
								@{
									TCInfoNameKey : @"TCTorManagerEventOperationDone",
									TCInfoTextKey : @"tor_operation_info_done",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						},
					
					@(TCInfoError) :
						@{
<<<<<<< HEAD
							@(TCTorManagerErrorConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorConfiguration",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
					
							@(TCTorManagerErrorIO) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorIO",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
							
							@(TCTorManagerErrorNetwork) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorNetwork",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
					
							@(TCTorManagerErrorExtract) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorExtract",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
					
							@(TCTorManagerErrorSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorSignature",
									TCInfoTextKey : @"<fixme>", // FIXME
								},
					
							@(TCTorManagerErrorTor) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorTor",
									TCInfoTextKey : @"<fixme>", // FIXME
=======
							@(TCTorManagerErrorOperationConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorOperationConfiguration",
									TCInfoTextKey : @"tor_operation_err_configuration",
									TCInfoLocalizableKey : @YES,
								},
					
							@(TCTorManagerErrorOperationIO) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorOperationIO",
									TCInfoTextKey : @"tor_operation_err_io",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorOperationNetwork) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorOperationNetwork",
									TCInfoTextKey : @"tor_operation_err_network",
									TCInfoLocalizableKey : @YES,
								},
					
							@(TCTorManagerErrorOperationExtract) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorOperationExtract",
									TCInfoTextKey : @"tor_operation_err_extract",
									TCInfoLocalizableKey : @YES,
								},
					
							@(TCTorManagerErrorOperationSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorOperationSignature",
									TCInfoTextKey : @"tor_operation_err_signature",
									TCInfoLocalizableKey : @YES,
								},
					
							@(TCTorManagerErrorOperationTor) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorTor",
									TCInfoTextKey : @"tor_operation_err_tor",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
					
							@(TCTorManagerErrorInternal) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorInternal",
<<<<<<< HEAD
									TCInfoTextKey : @"<fixme>", // FIXME
=======
									TCInfoTextKey : @"tor_operation_err_internal",
									TCInfoLocalizableKey : @YES,
>>>>>>> javerous/master
								},
						}
				},
			};
	});
	
	return renderInfo;
}

@end
