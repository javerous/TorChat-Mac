/*
 *  TCFilesController.m
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import "TCFilesController.h"

#import "TCFileCellView.h"



/*
** TCFilesController - Private
*/
#pragma mark - TCFilesController - Private

@interface TCFilesController ()
{
	NSMutableArray *_files;
}

// -- IBAction --
- (IBAction)doShowTransfer:(id)sender;
- (IBAction)doCancelTransfer:(id)sender;
- (IBAction)doOpenTransfer:(id)sender;

- (IBAction)doClear:(id)sender;


// -- Helpers --
- (void)_updateCount;

@end



/*
** TCFilesController
*/
#pragma mark - TCFilesController

@implementation TCFilesController


/*
** TCFilesController - Instance
*/
#pragma mark - TCFilesController - Instance

+ (TCFilesController *)sharedController
{
	static dispatch_once_t		onceToken;
	static TCFilesController	*shr;
	
	dispatch_once(&onceToken, ^{
		shr = [[TCFilesController alloc] init];
	});

	return shr;
}

- (id)init
{
	self = [super init];
	
    if (self)
	{
		// Alloc files array.
		_files =  [[NSMutableArray alloc] init];
		
		// Load the nib.
		[[NSBundle mainBundle] loadNibNamed:@"FilesWindow" owner:self topLevelObjects:nil];
		
		// Update window.
		[_mainWindow center];
		[_mainWindow setFrameAutosaveName:@"FilesWindow"];
		
		[self _updateCount];
    }
    
    return self;
}



/*
** TCFilesController - IBAction
*/
#pragma mark - TCFilesController - IBAction

- (IBAction)doShowTransfer:(id)sender
{
	NSInteger row = [_filesView rowForView:sender];
	
	if (row < 0 || row >= [_files count])
		return;
	
	NSDictionary	*file = _files[(NSUInteger)row];
	NSString		*path = file[TCFileFilePathKey];
		
	[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:nil];
}

- (IBAction)doCancelTransfer:(id)sender
{
	NSInteger row = [_filesView rowForView:sender];
	
	if (row < 0 || row >= [_files count])
		return;
	
	NSDictionary *file = _files[(NSUInteger)row];
	NSDictionary *dict = @{ @"uuid" : file[TCFileUUIDKey], @"address" : file[TCFileBuddyAddressKey], @"way" : file[TCFileWayKey] };
	
	[[NSNotificationCenter defaultCenter] postNotificationName:TCFileCancelNotification object:nil userInfo:dict];
}

- (IBAction)doOpenTransfer:(id)sender
{
	NSInteger row = [_filesView rowForView:sender];
	
	if (row < 0 || row >= [_files count])
		return;
	
	NSDictionary	*file = _files[(NSUInteger)row];
	NSString		*path = file[TCFileFilePathKey];
			
	[[NSWorkspace sharedWorkspace] openFile:path];
}

- (IBAction)doClear:(id)sender
{
	NSMutableIndexSet	*indSet = [NSMutableIndexSet indexSet];
	NSUInteger			i, cnt = [_files count];
	
	for (i = 0; i < cnt; i++)
	{
		NSDictionary	*file = [_files objectAtIndex:i];
		tcfile_status	status = (tcfile_status)[[file objectForKey:TCFileStatusKey] intValue];

		if (status != tcfile_status_running)
			[indSet addIndex:i];
	}
	
	[_files removeObjectsAtIndexes:indSet];
	
	[_filesView reloadData];
	
	[self _updateCount];
}

- (IBAction)showWindow:(id)sender
{
	[_mainWindow makeKeyAndOrderFront:sender];
}



/*
** TCFilesController - Actions
*/
#pragma mark - TCFilesController - Action

- (void)startFileTransfert:(NSString *)uuid withFilePath:(NSString *)filePath buddyAddress:(NSString *)address buddyName:(NSString *)name transfertWay:(tcfile_way)way fileSize:(uint64_t)size
{
	if (!uuid || !filePath || !name || !address)
		return;
	
	// Build file description
	NSMutableDictionary *item = [[NSMutableDictionary alloc] initWithCapacity:7];
	NSImage				*icon = [[NSWorkspace sharedWorkspace] iconForFileType:[filePath pathExtension]];
	
	[icon setSize:NSMakeSize(50, 50)];
	[icon lockFocus];
	{
		NSImage *badge = nil;
		
		if (way == tcfile_upload)
			badge = [NSImage imageNamed:@"file_up"];
		else if (way == tcfile_download)
			badge = [NSImage imageNamed:@"file_down"];
		
		if (badge)
			[badge drawAtPoint:NSMakePoint(50 - 16, 0) fromRect:NSMakeRect(0, 0, 16, 16) operation:NSCompositeSourceOver fraction:1.0];
	}
	[icon unlockFocus];
	
	[item setObject:uuid forKey:TCFileUUIDKey];
	[item setObject:filePath forKey:TCFileFilePathKey];
	[item setObject:address forKey:TCFileBuddyAddressKey];
	[item setObject:name forKey:TCFileBuddyNameKey];
	[item setObject:[NSNumber numberWithInt:way] forKey:TCFileWayKey];
	[item setObject:[NSNumber numberWithInt:tcfile_status_running] forKey:TCFileStatusKey];
	[item setObject:[NSNumber numberWithFloat:0.0] forKey:TCFilePercentKey];
	[item setObject:icon forKey:TCFileIconKey];
	[item setObject:[NSNumber numberWithUnsignedLongLong:size] forKey:TCFileSizeKey];
	[item setObject:[NSNumber numberWithUnsignedLongLong:0] forKey:TCFileCompletedKey];
	
	if (way == tcfile_upload)
		[item setObject:NSLocalizedString(@"file_uploading", @"") forKey:TCFileStatusTextKey];
	else if (way == tcfile_download)
		[item setObject:NSLocalizedString(@"file_downloading", @"") forKey:TCFileStatusTextKey];
	
	// Make internal & interface changes in main thread
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Add the file
		[_files addObject:item];
				
		// Reload the view
		[_filesView reloadData];
		
		// Reaload count
		[self _updateCount];
		
		// Show the window
		[_mainWindow makeKeyAndOrderFront:self];
	});
}

- (void)setStatus:(tcfile_status)status andTextStatus:(NSString *)txtStatus forFileTransfert:(NSString *)uuid withWay:(tcfile_way)way
{
	if (!txtStatus)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		for (NSMutableDictionary *file in _files)
		{
			NSString	*auuid = [file objectForKey:TCFileUUIDKey];
			tcfile_way	away = (tcfile_way)[[file objectForKey:TCFileWayKey] intValue];
			
			if (away == way && [auuid isEqualToString:uuid])
			{
				[file setObject:[NSNumber numberWithInt:status] forKey:TCFileStatusKey];
				[file setObject:txtStatus forKey:TCFileStatusTextKey];
				
				[_filesView reloadData];
				[self _updateCount];
				break;
			}
		}
		
	});
}

- (void)setCompleted:(uint64_t)size forFileTransfert:(NSString *)uuid withWay:(tcfile_way)way
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		for (NSMutableDictionary *file in _files)
		{
			NSString	*auuid = [file objectForKey:TCFileUUIDKey];
			tcfile_way	away = (tcfile_way)[[file objectForKey:TCFileWayKey] intValue];
			
			if (away == way && [auuid isEqualToString:uuid])
			{
				[file setObject:@(size) forKey:TCFileCompletedKey];
				
				[_filesView reloadData];
				[self _updateCount];
				break;
			}
		}
	});
}



/*
** TCFilesController - Table View
*/
#pragma mark - TCFilesController - Table View

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{	
	return (NSInteger)[_files count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	TCFileCellView	*cellView = nil;
	NSDictionary	*file = [_files objectAtIndex:(NSUInteger)rowIndex];
	tcfile_status	status = (tcfile_status)[[file objectForKey:TCFileStatusKey] intValue];

	if (status == tcfile_status_finish || status == tcfile_status_cancel || status == tcfile_status_stoped || status == tcfile_status_error)
		cellView = [tableView makeViewWithIdentifier:@"transfers_end" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"transfers_progress" owner:self];

	[cellView setContent:file];
	
	return cellView;
}

- (BOOL)doDeleteKeyInTableView:(NSTableView *)aTableView
{
	NSIndexSet			*set = [_filesView selectedRowIndexes];
	NSMutableIndexSet	*final = [NSMutableIndexSet indexSet];
    NSUInteger			currentIndex = [set firstIndex];
	
    while (currentIndex != NSNotFound)
	{
		NSDictionary	*file = [_files objectAtIndex:currentIndex];
		tcfile_status	status = (tcfile_status)[[file objectForKey:TCFileStatusKey] intValue];

		if (status != tcfile_status_running)
			[final addIndex:currentIndex];

        currentIndex = [set indexGreaterThanIndex:currentIndex];
    }
	
	if ([final count] == 0)
		return NO;
	
	// Remove items from array
	[_files removeObjectsAtIndexes:final];
	
	// Reload
	[_filesView reloadData];
	[self _updateCount];
	
	return YES;
}



/*
** TCFilesController - Private
*/
#pragma mark - TCFilesController - Private

- (void)_updateCount
{
	// > in main queue <
	
	unsigned count_up = 0;
	unsigned count_down = 0;
	unsigned count_run = 0;
	unsigned count_unrun = 0;
	
	for (NSDictionary *file in _files)
	{
		tcfile_status	status = (tcfile_status)[[file objectForKey:TCFileStatusKey] intValue];
		tcfile_way		way = (tcfile_way)[[file objectForKey:TCFileWayKey] intValue];
		
		if (status == tcfile_status_running)
			count_run++;
		else
			count_unrun++;
		
		if (way == tcfile_upload)
			count_up++;
		else if (way == tcfile_download)
			count_down++;
	}
	
	// Activate items
	[_clearButton setEnabled:(count_unrun > 0)];
	[_countField setHidden:([_files count] == 0)];

	// Build up string
	NSString *txt_up = nil;
	if (count_up > 1)
		txt_up = [NSString stringWithFormat:NSLocalizedString(@"file_uploads", @""), count_up];
	else if (count_up > 0)
		txt_up = NSLocalizedString(@"one_upload", @"");
	
	// Build down string
	NSString *txt_down = nil;
	if (count_down > 1)
		txt_down = [NSString stringWithFormat:NSLocalizedString(@"file_downloads", @""), count_up];
	else if (count_down > 0)
		txt_down = NSLocalizedString(@"one_download", @"");

	// Show the final string
	if (txt_up && txt_down)
		[_countField setStringValue:[NSString stringWithFormat:@"%@ — %@", txt_down, txt_up]];
	else
	{
		if (txt_up)
			[_countField setStringValue:txt_up];
		else if (txt_down)
			[_countField setStringValue:txt_down];
	}
}

@end
