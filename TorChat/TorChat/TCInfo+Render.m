//
//  TCInfo+Render.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 08/08/2014.
//  Copyright (c) 2016 SourceMac. All rights reserved.
//

#import "TCInfo+Render.h"

#import "TCBuddy.h"
#import "TCSocket.h"
#import "TCConnection.h"
#import "TCCoreManager.h"
#import "TCTorManager.h"

#import "TCTextConstants.h"


/*
** Defines
*/
#pragma mark - Defines

#define TCInfoNameKey		@"name"
#define TCInfoTextKey		@"text"
#define TCInfoDynTextKey	@"dyn_text"




/*
** TCInfoRender
*/
#pragma mark - TCInfoRender

@implementation TCInfo (TCInfoRender)


- (NSString *)render
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Add the log time.
	[result appendString:[self.date description]];
	
	// Get info.
	NSDictionary *infos = [[self class] renderInfo][self.domain][@(self.kind)][@(self.code)];
	
	if (!infos)
	{
		[result appendFormat:@" - Unknow"];
		
		return result;
	}
	
	// Add the error name.
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
	
	// Add the other sub-info
	if (self.subInfo)
	{
		[result appendString:@" "];
		[result appendString:[self.subInfo _render]];
	}
	
	[result appendString:@"}"];
	
	return result;
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
									TCInfoTextKey : TCCoreBuddyNoteTorConnected,
								},
							
							@(TCBuddyEventConnectedBuddy) :
								@{
									TCInfoNameKey : @"TCBuddyEventConnectedBuddy",
									TCInfoTextKey : TCCoreBuddyNoteConnected,
								},
							
							@(TCBuddyEventDisconnected) :
								@{
									TCInfoNameKey : @"TCBuddyEventDisconnected",
									TCInfoTextKey : TCCoreBuddyNoteStopped,
								},
							
							@(TCBuddyEventIdentified) :
								@{
									TCInfoNameKey : @"TCBuddyEventIdentified",
									TCInfoTextKey : TCCoreBuddyNoteIdentified,
								},
							
							@(TCBuddyEventStatus) :
								@{
									TCInfoNameKey : @"TCBuddyEventStatus",
									TCInfoTextKey : TCCoreBuddyNoteStatusChanged,
								},
							
							@(TCBuddyEventMessage) :
								@{
									TCInfoNameKey : @"TCBuddyEventMessage",
									TCInfoTextKey : TCCoreBuddyNoteNewMessage,
								},
							
							@(TCBuddyEventAlias) :
								@{
									TCInfoNameKey : @"TCBuddyEventAlias",
									TCInfoTextKey : TCCoreBuddyNoteAliasChanged,
								},
							
							@(TCBuddyEventNotes) :
								@{
									TCInfoNameKey : @"TCBuddyEventNotes",
									TCInfoTextKey : TCCoreBuddyNoteNotesChanged,
								},
							
							@(TCBuddyEventVersion) :
								@{
									TCInfoNameKey : @"TCBuddyEventVersion",
									TCInfoTextKey : TCCoreBuddyNoteNewVersion,
								},
							
							@(TCBuddyEventClient) :
								@{
									TCInfoNameKey : @"TCBuddyEventClient",
									TCInfoTextKey : TCCoreBuddyNoteNewClient,
								},
							
							@(TCBuddyEventBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyEventBlocked",
									TCInfoTextKey : TCCoreBuddyNoteBlockedChanged,
								},
							
							@(TCBuddyEventFileSendStart) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendStart",
									TCInfoTextKey : TCCoreBuddyNoteFileSendStart,
								},
							
							@(TCBuddyEventFileSendRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendRunning",
									TCInfoTextKey : TCCoreBuddyNoteFileChunkSend,
								},
							
							@(TCBuddyEventFileSendFinish) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendFinish",
									TCInfoTextKey : TCCoreBuddyNoteFileSendFinish,
								},
							
							@(TCBuddyEventFileSendStopped) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileSendStopped",
									TCInfoTextKey : TCCoreBuddyNoteFileSendCanceled,
								},
							
							@(TCBuddyEventFileReceiveStart) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveStart",
									TCInfoTextKey : TCCoreBuddyNoteFileReceiveStart,
								},
							
							@(TCBuddyEventFileReceiveRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveRunning",
									TCInfoTextKey : TCCoreBuddyNoteFileChunkReceive,
								},
							
							@(TCBuddyEventFileReceiveRunning) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveRunning",
									TCInfoTextKey : TCCoreBuddyNoteFileChunkReceive,
								},
							
							@(TCBuddyEventFileReceiveFinish) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveFinish",
									TCInfoTextKey : TCCoreBuddyNoteFileReceiveFinish,
								},
							
							@(TCBuddyEventFileReceiveStopped) :
								@{
									TCInfoNameKey : @"TCBuddyEventFileReceiveStopped",
									TCInfoTextKey : TCCoreBuddyNoteFileReceiveStopped,
								},
							
							@(TCBuddyEventProfileText) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileText",
									TCInfoTextKey : TCCoreBuddyNoteNewProfileText,
								},
							
							@(TCBuddyEventProfileText) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileText",
									TCInfoTextKey : TCCoreBuddyNoteNewProfileText,
								},
							
							@(TCBuddyEventProfileName) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileName",
									TCInfoTextKey : TCCoreBuddyNoteNewProfileName,
								},
							
							@(TCBuddyEventProfileAvatar) :
								@{
									TCInfoNameKey : @"TCBuddyEventProfileAvatar",
									TCInfoTextKey : TCCoreBuddyNoteNewProfileAvatar,
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCBuddyErrorResolveTor) :
								@{
									TCInfoNameKey : @"TCBuddyErrorResolveTor",
									TCInfoTextKey : TCCoreBuddyErrorTorResolve,
								},
							
							@(TCBuddyErrorConnectTor) :
								@{
									TCInfoNameKey : @"TCBuddyErrorConnectTor",
									TCInfoTextKey : TCCoreBuddyErrorTorConnect,
								},
							
							@(TCBuddyErrorSocket) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSocket",
									TCInfoTextKey : TCCoreBuddyErrorSocket,
								},
							
							@(TCBuddyErrorSocks) :
								@{
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
								},
							
							@(TCBuddyErrorMessageOffline) :
								@{
									TCInfoNameKey : @"TCBuddyErrorMessageOffline",
									TCInfoTextKey : TCCoreBuddyErrorMessageOffline,
								},
							
							@(TCBuddyErrorMessageBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyErrorMessageBlocked",
									TCInfoTextKey : TCCoreBuddyErrorMessageBlocked,
								},
							
							@(TCBuddyErrorSendFile) :
								@{
									TCInfoNameKey : @"TCBuddyErrorSendFile",
									TCInfoTextKey : TCCoreBuddyErrorFileSend,
								},
							
							@(TCBuddyErrorReceiveFile) :
								@{
									TCInfoNameKey : @"TCBuddyErrorReceiveFile",
									TCInfoTextKey : TCCoreBuddyErrorFileReceive,
								},
							
							@(TCBuddyErrorFileOffline) :
								@{
									TCInfoNameKey : @"TCBuddyErrorFileOffline",
									TCInfoTextKey : TCCoreBuddyErrorFileOffline,
								},
							
							@(TCBuddyErrorFileBlocked) :
								@{
									TCInfoNameKey : @"TCBuddyErrorFileBlocked",
									TCInfoTextKey : TCCoreBuddyErrorFileBlocked,
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
								},
							
							@(TCSocketErrorReadClosed) :
								@{
									TCInfoNameKey : @"TCSocketErrorReadClosed",
									TCInfoTextKey : @"core_socket_read_closed",
								},
							
							@(TCSocketErrorReadFull) :
								@{
									TCInfoNameKey : @"TCSocketErrorReadFull",
									TCInfoTextKey : @"core_socker_read_full",
								},
							
							@(TCSocketErrorWrite) :
								@{
									TCInfoNameKey : @"TCSocketErrorWrite",
									TCInfoTextKey : @"core_socket_write_error",
								},
							
							@(TCSocketErrorWriteClosed) :
								@{
									TCInfoNameKey : @"TCSocketErrorWriteClosed",
									TCInfoTextKey : @"core_socket_write_closed",
								},
						}
				},
			
				// == TCConnectionInfoDomain ==
				TCConnectionInfoDomain: @{
					@(TCInfoError) :
						@{
							@(TCCoreErrorSocket) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocket",
									TCInfoTextKey : @"core_cnx_error_socket",
								},
							
							@(TCCoreErrorClientCmdPing) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdPing",
									TCInfoTextKey : @"core_cnx_error_fake_ping",
								},
							
							@(TCCoreEventClientStarted) :
								@{
									TCInfoNameKey : @"TCCoreEventClientStarted",
									TCInfoTextKey : @"core_cnx_event_started",
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
									TCInfoTextKey : @"core_mng_event_new_buddy",
								},
							
							@(TCCoreEventStarted) :
								@{
									TCInfoNameKey : @"TCCoreEventStarted",
									TCInfoTextKey : @"core_mng_event_started",
								},
							
							@(TCCoreEventStopped) :
								@{
									TCInfoNameKey : @"TCCoreEventStopped",
									TCInfoTextKey : @"core_mng_event_stopped",
								},
							
							@(TCCoreEventStatus) :
								@{
									TCInfoNameKey : @"TCCoreEventStatus",
									TCInfoTextKey : @"",
								},
							
							@(TCCoreEventProfileAvatar) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileAvatar",
									TCInfoTextKey : @"core_mng_event_profile_avatar",
								},
							
							@(TCCoreEventProfileName) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileName",
									TCInfoTextKey : @"core_mng_event_profile_name",
								},
							
							@(TCCoreEventProfileText) :
								@{
									TCInfoNameKey : @"TCCoreEventProfileText",
									TCInfoTextKey : @"core_mng_event_profile_name",
								},
							
							@(TCCoreEventBuddyNew) :
								@{
									TCInfoNameKey : @"TCCoreEventBuddyNew",
									TCInfoTextKey : @"core_mng_event_new_buddy",
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCCoreErrorSocketCreate) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketCreate",
									TCInfoTextKey : @"core_mng_error_socket",
								},
							
							@(TCCoreErrorSocketOption) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketOption",
									TCInfoTextKey : @"core_mng_error_setsockopt",
								},
							
							@(TCCoreErrorSocketBind) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketBind",
									TCInfoTextKey : @"core_mng_error_bind",
								},
							
							@(TCCoreErrorSocketListen) :
								@{
									TCInfoNameKey : @"TCCoreErrorSocketListen",
									TCInfoTextKey : @"core_mng_error_listen",
								},
							
							@(TCCoreErrorServAccept) :
								@{
									TCInfoNameKey : @"TCCoreErrorServAccept",
									TCInfoTextKey : @"core_mng_error_accept",
								},
							
							@(TCCoreErrorServAcceptAsync) :
								@{
									TCInfoNameKey : @"TCCoreErrorServAcceptAsync",
									TCInfoTextKey : @"core_mng_error_async",
								},
							
							@(TCCoreErrorClientAlreadyPinged) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientAlreadyPinged",
									TCInfoTextKey : @"core_cnx_error_already_pinged",
								},
							
							@(TCCoreErrorClientMasquerade) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientMasquerade",
									TCInfoTextKey : @"core_cnx_error_masquerade",
								},
							
							@(TCCoreErrorClientAddBuddy) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientAddBuddy",
									TCInfoTextKey : @"core_cnx_error_add_buddy",
								},
							
							@(TCCoreErrorClientCmdPong) :
								@{
									TCInfoNameKey : @"TCCoreErrorClientCmdPong",
									TCInfoTextKey : @"core_cnx_error_pong",
								},
						}
				},
			
				// == TCTorManagerInfoStartDomain ==
				TCTorManagerInfoStartDomain : @{
					@(TCInfoInfo) :
						@{
							@(TCTorManagerEventStartHostname) :
								@{
									TCInfoNameKey : @"TCTorManagerInfoStartHostname",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventStartDone) :
								@{
									TCInfoNameKey : @"TCTorManagerInfoStartDone",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
					},
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorStartAlreadyRunning) :
								@{
									TCInfoNameKey : @"TCTorManagerInfoStartHostname",
									TCInfoTextKey : @"<fixme>"
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorStartConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartConfiguration",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text

								},
							
							@(TCTorManagerErrorStartUnarchive) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartUnarchive",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorStartSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartSignature",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorStartLaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorStartLaunch",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
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
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
						},
					   
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorCheckUpdateNetworkRequest) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateNetworkRequest",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							   
							   
							@(TCTorManagerErrorCheckUpdateBadServerReply) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateBadServerReply",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							   
							@(TCTorManagerErrorCheckUpdateRemoteInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateRemoteInfo",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							   
							@(TCTorManagerErrorCheckUpdateLocalSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateLocalSignature",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							   
							@(TCTorManagerErrorCheckUpdateNothingNew) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorCheckUpdateNothingNew",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
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
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventUpdateArchiveSize) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveSize",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventUpdateArchiveDownloading) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveDownloading",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventUpdateArchiveStage) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateArchiveStage",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventUpdateSignatureCheck) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateSignatureCheck",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventUpdateRelaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateRelaunch",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventUpdateDone) :
								@{
									TCInfoNameKey : @"TCTorManagerEventUpdateDone",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorUpdateTorNotRunning) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateTorNotRunning",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorUpdateConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateConfiguration",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorUpdateInternal) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateInternal",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorUpdateArchiveInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveInfo",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorUpdateArchiveDownload) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveDownload",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorUpdateArchiveStage) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateArchiveStage",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorUpdateRelaunch) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorUpdateRelaunch",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
						}
				},
			
				// == TCTorManagerInfoOperationDomain ==
				TCTorManagerInfoOperationDomain : @{
					@(TCInfoInfo) :
						@{
							@(TCTorManagerEventInfo) :
								@{
									TCInfoNameKey : @"TCTorManagerEventInfo",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerEventDone) :
								@{
									TCInfoNameKey : @"TCTorManagerEventDone",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
						},
					
					@(TCInfoError) :
						@{
							@(TCTorManagerErrorConfiguration) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorConfiguration",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
					
							@(TCTorManagerErrorIO) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorIO",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
							
							@(TCTorManagerErrorNetwork) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorNetwork",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
					
							@(TCTorManagerErrorExtract) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorExtract",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
					
							@(TCTorManagerErrorSignature) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorSignature",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
					
							@(TCTorManagerErrorTor) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorTor",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
					
							@(TCTorManagerErrorInternal) :
								@{
									TCInfoNameKey : @"TCTorManagerErrorInternal",
									TCInfoTextKey : @"<fixme>",
#warning FIXME: add text
								},
						}
				},
			};
	});
	
	return renderInfo;
}

@end
