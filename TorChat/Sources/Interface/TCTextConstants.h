/*
 *  TCTextConstants.h
 *
 *  Copyright 2014 Avérous Julien-Pierre
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



#ifndef TCTEXTCONSTANTS_H_
# define TCTEXTCONSTANTS_H_

// -- Buddy --
// Errors.
#define TCCoreBuddyErrorTorResolve			@"core_bd_err_tor_resolve"
#define TCCoreBuddyErrorTorConnect			@"core_bd_err_tor_connect"

#define TCCoreBuddyErrorMessageOffline		@"core_bd_err_message_offline"
#define TCCoreBuddyErrorMessageBlocked		@"core_bd_err_message_blocked"

#define TCCoreBuddyErrorFileSend			@"core_bd_err_filesend"
#define TCCoreBuddyErrorFileBlocked			@"core_bd_err_file_blocked"
#define TCCoreBuddyErrorFileOffline			@"core_bd_err_file_offline"

#define TCCoreBuddyErrorFileReceive			@"core_bd_err_filereceive"

#define TCCoreBuddyErrorSocksRequest		@"core_bd_err_socks_request"
#define TCCoreBuddyErrorSocks91				@"core_bd_err_socks_91"
#define TCCoreBuddyErrorSocks92				@"core_bd_err_socks_92"
#define TCCoreBuddyErrorSocks93				@"core_bd_err_socks_93"
#define TCCoreBuddyErrorSocksUnknown		@"core_bd_err_socks_unknown"

#define TCCoreBuddyErrorSocket				@"core_bd_err_socket"

#define TCCoreBuddyErrorParse				@"core_bd_err_parse"

// Notes.
#define TCCoreBuddyNoteTorConnected			@"core_bd_note_tor_connected"
#define TCCoreBuddyNoteStopped				@"core_bd_note_stopped"

#define TCCoreBuddyNoteStatusChanged		@"core_bd_note_status_changed"
#define TCCoreBuddyNoteAliasChanged			@"core_bd_note_alias_changed"
#define TCCoreBuddyNoteNotesChanged			@"core_bd_note_notes_changed"
#define TCCoreBuddyNoteBlockedChanged		@"core_bd_note_blocked_changed"

#define TCCoreBuddyNoteFileSendCanceled		@"core_bd_note_file_send_canceled"
#define TCCoreBuddyNoteFileReceiveCanceled	@"core_bd_note_file_receive_canceled"

#define TCCoreBuddyNoteFileSendStart		@"core_bd_note_file_send_start"
#define TCCoreBuddyNoteFileChunkSend		@"core_bd_note_file_chunk_send"
#define TCCoreBuddyNoteFileSendFinish		@"core_bd_note_file_send_finish"
#define TCCoreBuddyNoteFileSendStopped		@"core_bd_note_file_send_stopped"

#define TCCoreBuddyNoteFileReceiveStart		@"core_bd_note_file_receive_start"
#define TCCoreBuddyNoteFileChunkReceive		@"core_bd_note_file_chunk_receive"
#define TCCoreBuddyNoteFileReceiveFinish	@"core_bd_note_file_receive_finish"
#define TCCoreBuddyNoteFileReceiveStopped	@"core_bd_note_file_receive_stopped"


#define TCCoreBuddyNoteIdentified			@"core_bd_note_identified"

#define TCCoreBuddyNoteConnected			@"core_bd_note_connected"

#define TCCoreBuddyNoteNewMessage			@"core_bd_note_new_message"
#define TCCoreBuddyNoteNewVersion			@"core_bd_note_new_version"
#define TCCoreBuddyNoteNewClient			@"core_bd_note_new_client"
#define TCCoreBuddyNoteNewProfileText		@"core_bd_note_new_profile_text"
#define TCCoreBuddyNoteNewProfileName		@"core_bd_note_new_profile_name"
#define TCCoreBuddyNoteNewProfileAvatar		@"core_bd_note_new_profile_avatar"

#endif /* !TCERRORCONSTANTS_H_ */
