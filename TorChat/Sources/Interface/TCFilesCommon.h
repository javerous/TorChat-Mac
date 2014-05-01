/*
 *  TCFilesCommon.h
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



#import <Cocoa/Cocoa.h>



/*
** Types
*/
#pragma mark - Types

// == File transfert way ==
typedef enum
{
	tcfile_upload,
	tcfile_download
} tcfile_way;

// == File transfert status ==
typedef enum
{
	tcfile_status_running,
	tcfile_status_finish,
	tcfile_status_cancel,
	tcfile_status_stoped,
	tcfile_status_error,
} tcfile_status;



/*
** File Dictionary Keys
*/
#pragma mark - File Dictionary Keys

#define TCFileUUIDKey			@"uuid"
#define TCFileFilePathKey		@"filepath"
#define TCFileBuddyAddressKey	@"buddy_address"
#define TCFileBuddyNameKey		@"buddy_name"
#define TCFileWayKey			@"way"
#define TCFileStatusKey			@"status"
#define TCFileStatusTextKey		@"status_txt"
#define TCFilePercentKey		@"percent"
#define TCFileIconKey			@"icon"
#define TCFileSizeKey			@"size"
#define TCFileCompletedKey		@"completed"



/*
** File Notify
*/
#pragma mark - File Dictionary Keys

#define TCFileCancelNotification	@"TCFileCancelNotification"
