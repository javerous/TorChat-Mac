/*
 *  TCFilesController.h
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



#import <Cocoa/Cocoa.h>

#import "TCFilesCommon.h"



/*
** TCFilesController
*/
#pragma mark -
#pragma mark TCFilesController

// == Class ==
@interface TCFilesController : NSObject
{
@public
	IBOutlet NSWindow		*mainWindow;
	IBOutlet NSTextField	*countField;
	IBOutlet NSButton		*clearButton;
	IBOutlet NSTableView	*filesView;

@private
    NSMutableArray *files;
	
}

// -- Constructor --
+ (TCFilesController *)sharedController;

// -- Interface --
- (IBAction)doClear:(id)sender;
- (IBAction)showWindow:(id)sender;

// -- Actions --
- (void)startFileTransfert:(NSString *)uuid withFilePath:(NSString *)filePath buddyAddress:(NSString *)address buddyName:(NSString *)name transfertWay:(tcfile_way)way fileSize:(uint64_t)size;
- (void)setStatus:(tcfile_status)status andTextStatus:(NSString *)txtStatus forFileTransfert:(NSString *)uuid withWay:(tcfile_way)way;
- (void)setCompleted:(uint64_t)size forFileTransfert:(NSString *)uuid withWay:(tcfile_way)way;

@end
