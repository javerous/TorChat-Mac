/*
 *  TCFilesWindowController.m
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



#import "TCFilesWindowController.h"

#import "TCFileCellView.h"



/*
** TCFilesWindowController - Private
*/
#pragma mark - TCFilesWindowController - Private

@interface TCFilesWindowController ()
{
	NSMutableArray *_files;
}

@property (strong, nonatomic) IBOutlet NSTextField	*countField;
@property (strong, nonatomic) IBOutlet NSButton		*clearButton;
@property (strong, nonatomic) IBOutlet NSTableView	*filesView;

// -- IBAction --
- (IBAction)doShowTransfer:(id)sender;
- (IBAction)doCancelTransfer:(id)sender;
- (IBAction)doOpenTransfer:(id)sender;

- (IBAction)doClear:(id)sender;


// -- Helpers --
- (void)_updateCount;

@end



/*
** TCFilesWindowController
*/
#pragma mark - TCFilesWindowController

@implementation TCFilesWindowController


/*
** TCFilesWindowController - Instance
*/
#pragma mark - TCFilesWindowController - Instance

+ (TCFilesWindowController *)sharedController
{
	static dispatch_once_t		onceToken;
	static TCFilesWindowController	*shr;
	
	dispatch_once(&onceToken, ^{
		shr = [[TCFilesWindowController alloc] init];
	});

	return shr;
}

- (id)init
{
	self = [super initWithWindowNibName:@"FilesWindow"];
	
    if (self)
	{
		// Alloc files array.
		_files =  [[NSMutableArray alloc] init];
    }
    
    return self;
}



/*
** TCFilesWindowController - NSWindowController
*/
#pragma mark - TCFilesWindowController - NSWindowController

- (void)windowDidLoad
{
	// Update window.
	[self.window center];
	[self.window setFrameAutosaveName:@"FilesWindow"];
	
	[self _updateCount];
}



/*
** TCFilesWindowController - IBAction
*/
#pragma mark - TCFilesWindowController - IBAction

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



/*
** TCFilesWindowController - Actions
*/
#pragma mark - TCFilesWindowController - Action

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
		[self showWindow:nil];
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
** TCFilesWindowController - Table View
*/
#pragma mark - TCFilesWindowController - Table View

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
** TCFilesWindowController - Private
*/
#pragma mark - TCFilesWindowController - Private

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

	NSString *key;

	// Build up string
	NSString *txt_up = nil;
	
	key = NSLocalizedString(@"file_uploads", @"");
	
	if (count_up > 1)
		txt_up = [NSString stringWithFormat:key, count_up];
	else if (count_up > 0)
		txt_up = NSLocalizedString(@"one_upload", @"");
	
	// Build down string
	NSString *txt_down = nil;
	
	key = NSLocalizedString(@"file_downloads", @"");

	if (count_down > 1)
		txt_down = [NSString stringWithFormat:key, count_up];
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
