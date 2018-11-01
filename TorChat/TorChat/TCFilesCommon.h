/*
 *  TCFilesCommon.h
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import <Cocoa/Cocoa.h>


/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, TCFileTransferDirection) {
	TCFileTransferDirectionUpload,
	TCFileTransferDirectionDownload
};

typedef NS_ENUM(unsigned int, TCFileTransferStatus) {
	TCFileTransferStatusRunning,
	TCFileTransferStatusFinish,
	TCFileTransferStatusCancel,
	TCFileTransferStatusStopped,
	TCFileTransferStatusError,
};



/*
** File Dictionary Keys
*/
#pragma mark - File Dictionary Keys

#define TCFileFilePathKey			@"filepath"
#define TCFileFileNameKey			@"filename"
#define TCFileBuddyIdentifierKey	@"buddy_identifier"
#define TCFileBuddyNameKey			@"buddy_name"
#define TCFileIconKey				@"icon"
#define TCFileSizeKey				@"size"

#define TCFileTransferDirectionKey		@"xdirection"
#define TCFileTransferStatusTextKey		@"xstatus_txt"
#define TCFileTransferCompletedKey		@"xcompleted"
#define TCFileTransferRemainingTimeKey	@"xremaining_time"
