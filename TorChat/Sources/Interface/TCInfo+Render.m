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
			
			TCBuddyInfoDomain : @{
					// -- Notify --
					@(TCBuddyNotifyConnectedTor) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyConnectedTor",
							TCInfoTextKey : TCCoreBuddyNoteTorConnected,
						},
					
					@(TCBuddyNotifyConnectedBuddy) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyConnectedBuddy",
							TCInfoTextKey : TCCoreBuddyNoteConnected,
						},
					
					@(TCBuddyNotifyDisconnected) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyDisconnected",
							TCInfoTextKey : TCCoreBuddyNoteStopped,
						},
					
					@(TCBuddyNotifyIdentified) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyIdentified",
							TCInfoTextKey : TCCoreBuddyNoteIdentified,
						},
					
					@(TCBuddyNotifyStatus) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyStatus",
							TCInfoTextKey : TCCoreBuddyNoteStatusChanged,
						},
					
					@(TCBuddyNotifyMessage) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyMessage",
							TCInfoTextKey : TCCoreBuddyNoteNewMessage,
						},
					
					@(TCBuddyNotifyAlias) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyAlias",
							TCInfoTextKey : TCCoreBuddyNoteAliasChanged,
						},
					
					@(TCBuddyNotifyNotes) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyNotes",
							TCInfoTextKey : TCCoreBuddyNoteNotesChanged,
						},
					
					@(TCBuddyNotifyVersion) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyVersion",
							TCInfoTextKey : TCCoreBuddyNoteNewVersion,
						},
					
					@(TCBuddyNotifyClient) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyClient",
							TCInfoTextKey : TCCoreBuddyNoteNewClient,
						},
					
					@(TCBuddyNotifyBlocked) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyBlocked",
							TCInfoTextKey : TCCoreBuddyNoteBlockedChanged,
						},
					
					@(TCBuddyNotifyFileSendStart) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileSendStart",
							TCInfoTextKey : TCCoreBuddyNoteFileSendStart,
						},
					
					@(TCBuddyNotifyFileSendRunning) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileSendRunning",
							TCInfoTextKey : TCCoreBuddyNoteFileChunkSend,
						},
					
					@(TCBuddyNotifyFileSendFinish) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileSendFinish",
							TCInfoTextKey : TCCoreBuddyNoteFileSendFinish,
						},
					
					@(TCBuddyNotifyFileSendStopped) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileSendStopped",
							TCInfoTextKey : TCCoreBuddyNoteFileSendCanceled,
						},
					
					@(TCBuddyNotifyFileReceiveStart) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileReceiveStart",
							TCInfoTextKey : TCCoreBuddyNoteFileReceiveStart,
						},
					
					@(TCBuddyNotifyFileReceiveRunning) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileReceiveRunning",
							TCInfoTextKey : TCCoreBuddyNoteFileChunkReceive,
						},
					
					@(TCBuddyNotifyFileReceiveRunning) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileReceiveRunning",
							TCInfoTextKey : TCCoreBuddyNoteFileChunkReceive,
						},
					
					@(TCBuddyNotifyFileReceiveFinish) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileReceiveFinish",
							TCInfoTextKey : TCCoreBuddyNoteFileReceiveFinish,
						},
					
					@(TCBuddyNotifyFileReceiveStopped) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyFileReceiveStopped",
							TCInfoTextKey : TCCoreBuddyNoteFileReceiveStopped,
						},
					
					@(TCBuddyNotifyProfileText) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyProfileText",
							TCInfoTextKey : TCCoreBuddyNoteNewProfileText,
						},
					
					@(TCBuddyNotifyProfileText) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyProfileText",
							TCInfoTextKey : TCCoreBuddyNoteNewProfileText,
						},
					
					@(TCBuddyNotifyProfileName) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyProfileName",
							TCInfoTextKey : TCCoreBuddyNoteNewProfileName,
						},
					
					@(TCBuddyNotifyProfileAvatar) :
						@{
							TCInfoNameKey : @"TCBuddyNotifyProfileAvatar",
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
			
				TCConnectionInfoDomain: @{
					@(TCCoreErrorSocket) :
						@{
							TCInfoNameKey : @"TCCoreErrorSocket",
							TCInfoTextKey : @"core_cnx_err_socket",
						},
					
					@(TCCoreErrorClientCmdPing) :
						@{
							TCInfoNameKey : @"TCCoreErrorClientCmdPing",
							TCInfoTextKey : @"core_cnx_err_fake_ping",
						},
					
					@(TCCoreNotifyClientStarted) :
						@{
							TCInfoNameKey : @"TCCoreNotifyClientStarted",
							TCInfoTextKey : @"core_cnx_note_started",
						},
				},
			
				TCCoreManagerInfoDomain: @{
					@(TCCoreNotifyBuddyNew) :
						@{
							TCInfoNameKey : @"TCCoreNotifyBuddyNew",
							TCInfoTextKey : @"core_mng_note_new_buddy",
						},
					
					@(TCCoreErrorSocketCreate) :
						@{
							TCInfoNameKey : @"TCCoreErrorSocketCreate",
							TCInfoTextKey : @"core_mng_err_socket",
						},
					
					@(TCCoreErrorSocketOption) :
						@{
							TCInfoNameKey : @"TCCoreErrorSocketOption",
							TCInfoTextKey : @"core_mng_err_setsockopt",
						},
					
					@(TCCoreErrorSocketBind) :
						@{
							TCInfoNameKey : @"TCCoreErrorSocketBind",
							TCInfoTextKey : @"core_mng_err_bind",
						},
					
					@(TCCoreErrorSocketListen) :
						@{
							TCInfoNameKey : @"TCCoreErrorSocketListen",
							TCInfoTextKey : @"core_mng_err_listen",
						},
					
					@(TCCoreErrorServAccept) :
						@{
							TCInfoNameKey : @"TCCoreErrorServAccept",
							TCInfoTextKey : @"core_mng_err_accept",
						},
					
					@(TCCoreErrorServAcceptAsync) :
						@{
							TCInfoNameKey : @"TCCoreErrorServAcceptAsync",
							TCInfoTextKey : @"core_mng_err_async",
						},
					
					@(TCCoreNotifyStarted) :
						@{
							TCInfoNameKey : @"TCCoreNotifyStarted",
							TCInfoTextKey : @"core_mng_note_started",
						},
					
					@(TCCoreNotifyStopped) :
						@{
							TCInfoNameKey : @"TCCoreNotifyStopped",
							TCInfoTextKey : @"core_mng_note_stopped",
						},
					
					@(TCCoreNotifyStatus) :
						@{
							TCInfoNameKey : @"TCCoreNotifyStatus",
							TCInfoTextKey : @"",
						},
					
					@(TCCoreNotifyProfileAvatar) :
						@{
							TCInfoNameKey : @"TCCoreNotifyProfileAvatar",
							TCInfoTextKey : @"core_mng_note_profile_avatar",
						},
					
					@(TCCoreNotifyProfileName) :
						@{
							TCInfoNameKey : @"TCCoreNotifyProfileName",
							TCInfoTextKey : @"core_mng_note_profile_name",
						},
					
					@(TCCoreNotifyProfileText) :
						@{
							TCInfoNameKey : @"TCCoreNotifyProfileText",
							TCInfoTextKey : @"core_mng_note_profile_name",
						},
					
					@(TCCoreNotifyBuddyNew) :
						@{
							TCInfoNameKey : @"TCCoreNotifyBuddyNew",
							TCInfoTextKey : @"core_mng_note_new_buddy",
						},
					
					@(TCCoreErrorClientAlreadyPinged) :
						@{
							TCInfoNameKey : @"TCCoreErrorClientAlreadyPinged",
							TCInfoTextKey : @"core_cnx_err_already_pinged",
						},
					
					@(TCCoreErrorClientMasquerade) :
						@{
							TCInfoNameKey : @"TCCoreErrorClientMasquerade",
							TCInfoTextKey : @"core_cnx_err_masquerade",
						},
					
					@(TCCoreErrorClientAddBuddy) :
						@{
							TCInfoNameKey : @"TCCoreErrorClientAddBuddy",
							TCInfoTextKey : @"core_cnx_err_add_buddy",
						},
					
					@(TCCoreErrorClientCmdPong) :
						@{
							TCInfoNameKey : @"TCCoreErrorClientCmdPong",
							TCInfoTextKey : @"core_cnx_err_pong",
						},
				},
			};
	});
	
	return renderInfo;
}

@end
