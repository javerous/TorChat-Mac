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

#import "TCInfo+Render.h"

#import "TCBuddy.h"
#import "TCSocket.h"
#import "TCConnection.h"
#import "TCCoreManager.h"
#import "TCTorManager.h"


/*
** Defines
*/
#pragma mark - Defines

#define TCInfoNameKey			@"name"
#define TCInfoTextKey			@"text"
#define TCInfoDynTextKey		@"dyn_text"
#define TCInfoLocalizableKey	@"localizable"



/*
** TCInfoRender
*/
#pragma mark - TCInfoRender

@implementation TCInfo (TCInfoRender)

- (NSString *)renderComplete
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Get info.
	NSDictionary *infos = [[self class] renderInfo][self.domain][@(self.kind)][@(self.code)];
	
	if (!infos)
	{
		[result appendFormat:@"Unknow (domain='%@'; kind=%d; code=%d", self.domain, self.kind, self.code];
		
		return result;
	}
	
	// Add the error name.
	[result appendFormat:@"[%@] ", infos[TCInfoNameKey]];
	
	// Add the message string
	NSString *msg = [self renderMessage];
	
	if (msg)
		[result appendString:msg];
	
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
	
	// Add the message string
	NSString *msg = [self renderMessage];

	if (msg)
		[result appendString:msg];
	
	// Add the other sub-info
	if (self.subInfo)
	{
		[result appendString:@" "];
		[result appendString:[self.subInfo _render]];
	}
	
	[result appendString:@"}"];
	
	return result;
}

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
									TCInfoTextKey : @"core_bd_event_tor_connected",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventConnectedBuddy) :
								@{
									TCInfoNameKey : @"TCBuddyEventConnectedBuddy",
									TCInfoTextKey : @"core_bd_event_connected",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventDisconnected) :
								@{
									TCInfoNameKey : @"TCBuddyEventDisconnected",
									TCInfoTextKey : @"core_bd_event_stopped",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventIdentified) :
								@{
									TCInfoNameKey : @"TCBuddyEventIdentified",
									TCInfoTextKey : @"core_bd_event_identified",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventStatus) :
								@{
									TCInfoNameKey : @"TCBuddyEventStatus",
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
								},
							
							@(TCBuddyEventMessage) :
								@{
									TCInfoNameKey : @"TCBuddyEventMessage",
									TCInfoTextKey : @"core_bd_event_new_message",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventAlias) :
								@{
									TCInfoNameKey : @"TCBuddyEventAlias",
									TCInfoTextKey : @"core_bd_event_alias_changed",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventNotes) :
								@{
									TCInfoNameKey : @"TCBuddyEventNotes",
									TCInfoTextKey : @"core_bd_event_notes_changed",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventVersion) :
								@{
									TCInfoNameKey : @"TCBuddyEventVersion",
									TCInfoTextKey : @"core_bd_event_new_version",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventClient) :
								@{
									TCInfoNameKey : @"TCBuddyEventClient",
									TCInfoTextKey : @"core_bd_event_new_client",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileSendStart) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendStart",
									TCInfoTextKey : @"core_bd_event_file_send_start",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileSendRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendRunning",
									TCInfoTextKey : @"core_bd_event_file_chunk_send",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileSendFinish) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendFinish",
									TCInfoTextKey : @"core_bd_event_file_send_finish",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileSendStopped) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendStopped",
									TCInfoTextKey : @"core_bd_event_file_send_canceled",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileReceiveStart) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveStart",
									TCInfoTextKey : @"core_bd_event_file_receive_start",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileReceiveRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveRunning",
									TCInfoTextKey : @"core_bd_event_file_chunk_receive",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileReceiveFinish) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveFinish",
									TCInfoTextKey : @"core_bd_event_file_receive_finish",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventFileReceiveStopped) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveStopped",
									TCInfoTextKey : @"core_bd_event_file_receive_stopped",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventProfileText) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileText",
									TCInfoTextKey : @"core_bd_event_new_profile_text",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventProfileName) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileName",
									TCInfoTextKey : @"core_bd_event_new_profile_name",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyEventProfileAvatar) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileAvatar",
									TCInfoTextKey : @"core_bd_event_new_profile_avatar",
									TCInfoLocalizableKey : @YES,
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCBuddyErrorResolveTor) :
								@{
									TCInfoNameKey : @"TCBuddyErrorResolveTor",
									TCInfoTextKey : @"core_bd_error_tor_resolve",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorConnectTor) :
								@{
									TCInfoNameKey : @"TCBuddyErrorConnectTor",
									TCInfoTextKey : @"core_bd_error_tor_connect",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorSocket) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSocket",
									TCInfoTextKey : @"core_bd_error_socket",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorSocks) :
								@{
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
								},
							
							@(TCBuddyErrorMessageOffline) :
								@{
									TCInfoNameKey : @"TCBuddyErrorMessageOffline",
									TCInfoTextKey : @"core_bd_error_message_offline",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorMessageBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyErrorMessageBlocked",
									TCInfoTextKey : @"core_bd_error_message_blocked",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorSendFile) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSendFile",
									TCInfoTextKey : @"core_bd_error_filesend",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorReceiveFile) :
								@{
									TCInfoNameKey : @"TCBuddyErrorReceiveFile",
									TCInfoTextKey : @"core_bd_error_filereceive",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorFileOffline) :
								@{
									TCInfoNameKey : @"TCBuddyErrorFileOffline",
									TCInfoTextKey : @"core_bd_error_file_offline",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCBuddyErrorFileBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyErrorFileBlocked",
									TCInfoTextKey : @"core_bd_error_file_blocked",
									TCInfoLocalizableKey : @YES,
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
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCSocketErrorReadClosed) :
								@{
									TCInfoNameKey : @"TCSocketErrorReadClosed",
									TCInfoTextKey : @"core_socket_read_closed",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCSocketErrorReadFull) :
								@{
									TCInfoNameKey : @"TCSocketErrorReadFull",
									TCInfoTextKey : @"core_socker_read_full",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCSocketErrorWrite) :
								@{
									TCInfoNameKey : @"TCSocketErrorWrite",
									TCInfoTextKey : @"core_socket_write_error",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCSocketErrorWriteClosed) :
								@{
									TCInfoNameKey : @"TCSocketErrorWriteClosed",
									TCInfoTextKey : @"core_socket_write_closed",
									TCInfoLocalizableKey : @YES,
								},
						}
				},
			
				// == TCConnectionInfoDomain ==
				TCConnectionInfoDomain: @{
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
					
					@(TCInfoError) :
						@{
							@(TCCoreErrorSocket) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocket",
									TCInfoTextKey : @"core_cnx_error_socket",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientCmdPing) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdPing",
									TCInfoTextKey : @"core_cnx_error_fake_ping",
									TCInfoLocalizableKey : @YES,
								},
						}
					},
			
				// == TCCoreManagerInfoDomain ==
				TCCoreManagerInfoDomain: @{
					@(TCInfoInfo) :
						@{
							@(TCCoreEventBuddyNew) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyNew",
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
								},
							
							@(TCCoreEventStarted) :
								@{
									TCInfoNameKey : @"TCCoreEventStarted",
									TCInfoTextKey : @"core_mng_event_started",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreEventStopped) :
								@{
									TCInfoNameKey : @"TCCoreEventStopped",
									TCInfoTextKey : @"core_mng_event_stopped",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreEventStatus) :
								@{
									TCInfoNameKey : @"TCCoreEventStatus",
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
								},
							
							@(TCCoreEventProfileAvatar) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileAvatar",
									TCInfoTextKey : @"core_mng_event_profile_avatar",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreEventProfileName) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileName",
									TCInfoTextKey : @"core_mng_event_profile_name",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreEventProfileText) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileText",
									TCInfoTextKey : @"core_mng_event_profile_text",
									TCInfoLocalizableKey : @YES,
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCCoreErrorSocketCreate) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketCreate",
									TCInfoTextKey : @"core_mng_error_socket",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorSocketOption) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketOption",
									TCInfoTextKey : @"core_mng_error_setsockopt",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorSocketBind) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketBind",
									TCInfoTextKey : @"core_mng_error_bind",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorSocketListen) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketListen",
									TCInfoTextKey : @"core_mng_error_listen",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorServAccept) :
								@{
									TCInfoNameKey : @"TCCoreErrorServAccept",
									TCInfoTextKey : @"core_mng_error_accept",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorServAcceptAsync) :
								@{
									TCInfoNameKey : @"TCCoreErrorServAcceptAsync",
									TCInfoTextKey : @"core_mng_error_async",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientAlreadyPinged) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientAlreadyPinged",
									TCInfoTextKey : @"core_cnx_error_already_pinged",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientMasquerade) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientMasquerade",
									TCInfoTextKey : @"core_cnx_error_masquerade",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientAddBuddy) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientAddBuddy",
									TCInfoTextKey : @"core_cnx_error_add_buddy",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCCoreErrorClientCmdUnknownCommand):
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdUnknownCommand",
								},
							
							@(TCCoreErrorClientCmdPong) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdPong",
									TCInfoTextKey : @"core_cnx_error_pong",
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
								},
						}
				},
			
				// == TCTorManagerInfoStartDomain ==
				TCTorManagerInfoStartDomain : @{
					@(TCInfoInfo) :
						@{
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
								},
							
							@(TCTorManagerEventStartDone) :
								@{
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
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorStartAlreadyRunning) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartAlreadyRunning",
									TCInfoTextKey : @"tor_start_err_already_running",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartConfiguration",
									TCInfoTextKey : @"tor_start_err_configuration",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartUnarchive) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartUnarchive",
									TCInfoTextKey : @"tor_start_err_unarchive",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartSignature",
									TCInfoTextKey : @"tor_start_err_signature",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorStartLaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartLaunch",
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
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										NSDictionary *context = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"tor_checkupdate_info_version_available", @""), context[@"new_version"]];
									},
									TCInfoLocalizableKey : @NO,
								},
						},
					   
					@(TCInfoError) :
						@{
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
								},
							   
							@(TCTorManagerErrorCheckUpdateLocalSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateLocalSignature",
									TCInfoTextKey : @"tor_checkupdate_error_validate_local_signature",
									TCInfoLocalizableKey : @YES,
								},
							   
							@(TCTorManagerErrorCheckUpdateNothingNew) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateNothingNew",
									TCInfoTextKey : @"tor_checkupdate_error_nothing_new",
									TCInfoLocalizableKey : @YES,
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
									TCInfoTextKey : @"tor_update_info_retrieve_info",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerEventUpdateArchiveSize) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveSize",
									TCInfoDynTextKey : ^ NSString *(TCInfo *info) {
										NSNumber *context = info.context;
										return [NSString stringWithFormat:NSLocalizedString(@"tor_update_info_archive_size", @""), [context unsignedLongLongValue]];
									},
									TCInfoLocalizableKey : @NO,
								},
							
							@(TCTorManagerEventUpdateArchiveDownloading) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveDownloading",
									TCInfoTextKey : @"tor_update_info_downloading",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerEventUpdateArchiveStage) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveStage",
									TCInfoTextKey : @"tor_update_info_stage",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerEventUpdateSignatureCheck) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateSignatureCheck",
									TCInfoTextKey : @"tor_update_info_signature_check",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerEventUpdateRelaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateRelaunch",
									TCInfoTextKey : @"tor_update_info_relaunch",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerEventUpdateDone) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateDone",
									TCInfoTextKey : @"tor_update_info_done",
									TCInfoLocalizableKey : @YES,
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorUpdateTorNotRunning) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateTorNotRunning",
									TCInfoTextKey : @"tor_update_err_not_running",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorUpdateConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateConfiguration",
									TCInfoTextKey : @"tor_update_err_configuration",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorUpdateInternal) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateInternal",
									TCInfoTextKey : @"tor_update_err_internal",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorUpdateArchiveInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveInfo",
									TCInfoTextKey : @"tor_update_err_archive_info",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorUpdateArchiveDownload) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveDownload",
									TCInfoTextKey : @"tor_update_err_archive_download",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorUpdateArchiveStage) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveStage",
									TCInfoTextKey : @"tor_update_err_archive_stage",
									TCInfoLocalizableKey : @YES,
								},
							
							@(TCTorManagerErrorUpdateRelaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateRelaunch",
									TCInfoTextKey : @"tor_update_err_relaunch",
									TCInfoLocalizableKey : @YES,
								},
						}
				},
			
				// == TCTorManagerInfoOperationDomain ==
				TCTorManagerInfoOperationDomain : @{
					@(TCInfoInfo) :
						@{
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
								},
						},
					
					@(TCInfoError) :
						@{
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
								},
					
							@(TCTorManagerErrorInternal) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorInternal",
									TCInfoTextKey : @"tor_operation_err_internal",
									TCInfoLocalizableKey : @YES,
								},
						}
				},
			};
	});
	
	return renderInfo;
}

@end
