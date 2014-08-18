//
//  TCInfo+Render.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 08/08/2014.
//  Copyright (c) 2014 SourceMac. All rights reserved.
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
	NSDictionary *infos = [[self class] renderInfo][self.domain][@(self.code)];
	
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
	NSDictionary *infos = [[self class] renderInfo][self.domain][@(self.code)];
	
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
					// -- Event --
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
					
					// -- Error --
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
				},
			
				// == TCSocketInfoDomain ==
				TCSocketInfoDomain: @{
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
				},
			
				// == TCConnectionInfoDomain ==
				TCConnectionInfoDomain: @{
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
				},
			
				// == TCCoreManagerInfoDomain ==
				TCCoreManagerInfoDomain: @{
					@(TCCoreEventBuddyNew) :
						@{
							TCInfoNameKey : @"TCCoreEventBuddyNew",
							TCInfoTextKey : @"core_mng_event_new_buddy",
						},
					
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
				},
			
				// == TCTorManagerInfoStartDomain ==
				TCTorManagerInfoStartDomain : @{
					// -- Event --
					@(TCTorManagerEventStartHostname) :
						@{
							TCInfoNameKey : @"TCTorManagerInfoStartHostname",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					@(TCTorManagerEventStartDone) :
						@{
							TCInfoNameKey : @"TCTorManagerInfoStartDone",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					// -- Error --
					@(TCTorManagerErrorStartAlreadyRunning) :
						@{
							TCInfoNameKey : @"TCTorManagerInfoStartHostname",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					@(TCTorManagerErrorStartConfiguration) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorStartConfiguration",
							TCInfoTextKey : @"<fixme>", // FIXME
							},
					
					@(TCTorManagerErrorStartUnarchive) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorStartUnarchive",
							TCInfoTextKey : @"<fixme>", // FIXME
							},
					
					@(TCTorManagerErrorStartSignature) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorStartSignature",
							TCInfoTextKey : @"<fixme>", // FIXME
							},
					
					@(TCTorManagerErrorStartLaunch) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorStartLaunch",
							TCInfoTextKey : @"<fixme>", // FIXME
							},
				},
			
				// == TCTorManagerInfoUpdateDomain ==
				TCTorManagerInfoUpdateDomain : @{
					// -- Event --
					@(TCTorManagerEventUpdateAvailable) :
						@{
							TCInfoNameKey : @"TCTorManagerEventUpdateAvailable",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					// -- Error --
					@(TCTorManagerErrorUpdateNetworkRequest) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorUpdateNetworkRequest",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					
					@(TCTorManagerErrorUpdateBadServerReply) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorUpdateBadServerReply",
							TCInfoTextKey : @"<fixme>", // FIXME
						},

					@(TCTorManagerErrorUpdateRemoteInfo) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorUpdateRemoteInfo",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					@(TCTorManagerErrorUpdateLocalSignature) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorUpdateLocalSignature",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
					
					@(TCTorManagerErrorUpdateNothingNew) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorUpdateNothingNew",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
				},
			
				// == TCTorManagerInfoOperationDomain ==
				TCTorManagerInfoOperationDomain : @{
					// -- Error --
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
						},
					
					@(TCTorManagerErrorInternal) :
						@{
							TCInfoNameKey : @"TCTorManagerErrorInternal",
							TCInfoTextKey : @"<fixme>", // FIXME
						},
				},
			};
	});
	
	return renderInfo;
}

@end
