/*
 *  TCFilesWindowController.m
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

#import <SMFoundation/SMFoundation.h>

#import "TCFilesWindowController.h"

#import "TCFileCellView.h"
#import "TCButton.h"

#import "TCCoreManager.h"
#import "TCBuddy.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

// Private file keys
#define TCFileUUIDKey			@"uuid"
#define TCFileStatusKey			@"status"
#define TCFilePercentKey		@"percent"
#define TCFileSpeedHelperKey	@"speed_helper"

#define TCFileIconContextKey	@"icon_ctx"
#define TCFileCancelContextKey	@"cancel_ctx"
#define TCFileShowContextKey	@"show_ctx"



/*
** TCFilesWindowController - Private
*/
#pragma mark - TCFilesWindowController - Private

@interface TCFilesWindowController () <TCCoreManagerObserver, TCBuddyObserver>
{
	TCCoreManager	*_core;

	NSMutableArray	*_files;
	NSMutableSet	*_buddies;
}

@property (strong, nonatomic) IBOutlet NSTextField	*countField;
@property (strong, nonatomic) IBOutlet NSButton		*clearButton;
@property (strong, nonatomic) IBOutlet NSTableView	*filesView;

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

- (instancetype)init
{
	self = [super initWithWindowNibName:@"FilesWindow"];
	
    if (self)
	{
		// Alloc containers.
		_files =  [[NSMutableArray alloc] init];
		_buddies = [[NSMutableSet alloc] init];
    }
    
    return self;
}



/*
** TCFilesWindowController - Life
*/
#pragma mark - TCFilesWindowController - Life

- (void)startWithCoreManager:(TCCoreManager *)coreMananager completionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	if (!handler)
		handler = ^{ };
	
	dispatch_group_async(group, dispatch_get_main_queue(), ^{
		
		// Hold parameters.
		_core = coreMananager;
		
		// Observe.
		[_core addObserver:self];
		
		// Handle current buddies.
		NSArray *buddies = [_core buddies];
		
		for (TCBuddy *buddy in buddies)
		{
			[buddy addObserver:self];
			[_buddies addObject:buddy];
		};
	});
	
	// Wait end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	if (!handler)
		handler = ^{ };
	
	dispatch_group_async(group, dispatch_get_main_queue(), ^{
		
		// Unmonitor buddies.
		for (TCBuddy *buddy in _buddies)
			[buddy removeObserver:self];
		
		[_buddies removeAllObjects];
		
		// Unmonitor core.
		[_core removeObserver:self];
		_core = nil;
	});
	
	// Wait end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
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
** TCFilesWindowController - TCCoreManagerObserver
*/
#pragma mark - TCFilesWindowController - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(SMInfo *)info
{
	// Handle buddy life.
	if (info.kind == SMInfoInfo)
	{
		if (info.code == TCCoreEventBuddyNew)
		{
			TCBuddy *buddy = (TCBuddy *)info.context;
			
			[buddy addObserver:self];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[_buddies addObject:buddy];
			});
		}
		else if (info.code == TCCoreEventBuddyRemove)
		{
			TCBuddy *buddy = (TCBuddy *)info.context;
			
			[buddy removeObserver:self];
			
			dispatch_async(dispatch_get_main_queue(), ^{
				[_buddies removeObject:buddy];
			});
		}
	}
}



/*
** TCFilesWindowController - TCBuddyObserver
*/
#pragma mark - TCFilesWindowController - TCBuddyObserver

- (void)buddy:(TCBuddy *)buddy information:(SMInfo *)info
{
	if (info.kind == SMInfoInfo)
	{
		switch (info.code)
		{
			case TCBuddyEventFileSendStart:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[self startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyIdentifier:[buddy identifier] buddyName:[buddy finalName] transfertWay:tcfile_upload fileSize:[finfo fileSizeTotal]];
				
				break;
			}
				
			case TCBuddyEventFileSendRunning:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[self setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case TCBuddyEventFileSendFinish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_upload_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case TCBuddyEventFileSendStopped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self setStatus:tcfile_status_stopped andTextStatus:NSLocalizedString(@"file_upload_stopped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_upload];
				
				break;
			}
				
			case TCBuddyEventFileReceiveStart:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[self startFileTransfert:[finfo uuid] withFilePath:[finfo filePath] buddyIdentifier:[buddy identifier] buddyName:[buddy finalName] transfertWay:tcfile_download fileSize:[finfo fileSizeTotal]];
				
				break;
			}
				
			case TCBuddyEventFileReceiveRunning:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[self setCompleted:[finfo fileSizeCompleted] forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case TCBuddyEventFileReceiveFinish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self setStatus:tcfile_status_finish andTextStatus:NSLocalizedString(@"file_download_done", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
				
			case TCBuddyEventFileReceiveStopped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self setStatus:tcfile_status_stopped andTextStatus:NSLocalizedString(@"file_download_stopped", @"") forFileTransfert:[finfo uuid] withWay:tcfile_download];
				
				break;
			}
		}
	}
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
		
	[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
}

- (IBAction)doCancelTransfer:(id)sender
{
	// Get transfert info.
	NSInteger row = [_filesView rowForView:sender];
	
	if (row < 0 || row >= [_files count])
		return;
	
	NSDictionary *file = _files[(NSUInteger)row];

	// Search the buddy associated with this transfert.
	NSString	*uuid = file[TCFileUUIDKey];
	NSString	*identifier = file[TCFileBuddyIdentifierKey];
	tcfile_way	way = (tcfile_way)[file[TCFileWayKey] intValue];
	
	for (TCBuddy *buddy in _buddies)
	{
		if ([[buddy identifier] isEqualToString:identifier])
		{
			// > Change the file status.
			[self setStatus:tcfile_status_cancel andTextStatus:NSLocalizedString(@"file_canceling", @"") forFileTransfert:uuid withWay:way];
			
			// > Cancel the transfert.
			if (way == tcfile_upload)
				[buddy fileCancelOfUUID:uuid way:TCBuddyFileSend];
			else if (way == tcfile_download)
				[buddy fileCancelOfUUID:uuid way:TCBuddyFileReceive];
			
			return;
		}
	}
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
		tcfile_status	status = (tcfile_status)[file[TCFileStatusKey] intValue];

		if (status != tcfile_status_running)
			[indSet addIndex:i];
	}
	
	[_files removeObjectsAtIndexes:indSet];
	
	[_filesView reloadData];
	[self _updateCount];
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
	// Get cell.
	TCFileCellView	*cellView = nil;
	NSDictionary	*file = [_files objectAtIndex:(NSUInteger)rowIndex];
	tcfile_status	status = (tcfile_status)[file[TCFileStatusKey] intValue];

	if (status == tcfile_status_running)
		cellView = [tableView makeViewWithIdentifier:@"transfers_progress" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"transfers_end" owner:self];

	// Set content.
	[cellView setContent:file];
	
	// Set actions.
	__weak TCFilesWindowController *weakSelf = self;
	
	if (cellView.showButton.actionHandler == nil)
	{
		cellView.showButton.actionHandler = ^(TCButton *button) {
			[weakSelf doShowTransfer:button];
		};
	}
	
	if (cellView.cancelButton && cellView.cancelButton.actionHandler == nil)
	{
		cellView.cancelButton.actionHandler = ^(TCButton *button) {
			[weakSelf doCancelTransfer:button];
		};
	}
	
	if (cellView.iconButton.actionHandler == nil)
	{
		cellView.iconButton.actionHandler = ^(TCButton *button) {
			[weakSelf doOpenTransfer:button];
		};
	}
	
	// Set button context.
	cellView.iconButton.context = (TCButtonContext *)file[TCFileIconContextKey];
	cellView.cancelButton.context = (TCButtonContext *)file[TCFileCancelContextKey];
	cellView.showButton.context = (TCButtonContext *)file[TCFileShowContextKey];

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
		tcfile_status	status = (tcfile_status)[file[TCFileStatusKey] intValue];

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
** TCFilesWindowController - Helpers
*/
#pragma mark - TCFilesWindowController - Helpers

- (void)startFileTransfert:(NSString *)uuid withFilePath:(NSString *)filePath buddyIdentifier:(NSString *)identifier buddyName:(NSString *)name transfertWay:(tcfile_way)way fileSize:(uint64_t)size
{
	NSAssert(uuid, @"uuid is nil");
	NSAssert(filePath, @"filePath is nil");
	NSAssert(name, @"name is nil");
	NSAssert(identifier, @"identifier is nil");
	
	// Build file description
	NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
	
	// > Set icon.
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType:[filePath pathExtension]];
	
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
	
	item[TCFileIconKey] = icon;
	
	// > Set speed helper.
	SMSpeedHelper *speedHelper = [[SMSpeedHelper alloc] initWithCompleteAmount:size];

	speedHelper.updateHandler = ^(NSTimeInterval remainingTime) {
		dispatch_async(dispatch_get_main_queue(), ^{
			
			NSUInteger			idx = NSNotFound;
			NSMutableDictionary *file = [self _fileForUUID:uuid way:way index:&idx];
			
			if (!file)
				return;
			
			file[TCFileRemainingTimeKey] = @(remainingTime);
			[_filesView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:idx] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		});
	};
	
	item[TCFileSpeedHelperKey] = speedHelper;
	
	// > Set button context.
	item[TCFileIconContextKey] = [TCButton createEmptyContext];
	item[TCFileCancelContextKey] = [TCButton createEmptyContext];
	item[TCFileShowContextKey] = [TCButton createEmptyContext];
	
	// > Set general stuff.
	item[TCFileUUIDKey] = uuid;
	item[TCFileFilePathKey] = filePath;
	item[TCFileBuddyIdentifierKey] = identifier;
	item[TCFileBuddyNameKey] = name;
	item[TCFileWayKey] = @(way);
	item[TCFileStatusKey] = @(tcfile_status_running);
	item[TCFilePercentKey] = @0.0;
	item[TCFileSizeKey] = @(size);
	item[TCFileCompletedKey] = @0;
	item[TCFileSpeedHelperKey] = speedHelper;
	
	if (way == tcfile_upload)
		item[TCFileStatusTextKey] = NSLocalizedString(@"file_uploading", @"");
	else if (way == tcfile_download)
		item[TCFileStatusTextKey] = NSLocalizedString(@"file_downloading", @"");
	
	// Update things.
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Add the file.
		[_files addObject:item];
		
		// Reload UID.
		[_filesView reloadData];
		[self _updateCount];
		
		// Show the window.
		[self showWindow:nil];
	});
}

- (void)setStatus:(tcfile_status)status andTextStatus:(NSString *)txtStatus forFileTransfert:(NSString *)uuid withWay:(tcfile_way)way
{
	NSAssert(txtStatus, @"txtStatus is nil");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Search file.
		NSUInteger			idx = NSNotFound;
		NSMutableDictionary	*file = [self _fileForUUID:uuid way:way index:&idx];
		
		if (!file)
			return;
		
		// Update status.
		file[TCFileStatusKey] = @(status);
		file[TCFileStatusTextKey] = txtStatus;

		// Remove speed updater.
		if (status != tcfile_status_running)
		{			
			SMSpeedHelper *speedHelper = file[TCFileSpeedHelperKey];
			
			speedHelper.updateHandler = nil;
			
			[file removeObjectForKey:TCFileSpeedHelperKey];
			[file removeObjectForKey:TCFileRemainingTimeKey];
		}
		
		// Reload table.
		[_filesView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:idx] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		[self _updateCount];
	});
}

- (void)setCompleted:(uint64_t)size forFileTransfert:(NSString *)uuid withWay:(tcfile_way)way
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Search file.
		NSUInteger			idx = NSNotFound;
		NSMutableDictionary *file = [self _fileForUUID:uuid way:way index:&idx];
		
		if (!file)
			return;
		
		// Update completed.
		file[TCFileCompletedKey] = @(size);
		
		// Update speed helper.
		SMSpeedHelper *speedHelper = file[TCFileSpeedHelperKey];
		
		if (speedHelper)
			[speedHelper setCurrentAmount:size];
		
		// Reload UI.
		[_filesView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:idx] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		[self _updateCount];
	});
}

- (void)_updateCount
{
	// > main queue <
	
	unsigned count_up = 0;
	unsigned count_down = 0;
	unsigned count_run = 0;
	unsigned count_unrun = 0;
	
	for (NSDictionary *file in _files)
	{
		tcfile_status	status = (tcfile_status)[file[TCFileStatusKey] intValue];
		tcfile_way		way = (tcfile_way)[file[TCFileWayKey] intValue];
		
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
		txt_up = NSLocalizedString(@"file_one_upload", @"");
	
	// Build down string
	NSString *txt_down = nil;
	
	key = NSLocalizedString(@"file_downloads", @"");

	if (count_down > 1)
		txt_down = [NSString stringWithFormat:key, count_up];
	else if (count_down > 0)
		txt_down = NSLocalizedString(@"file_one_download", @"");

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

- (NSMutableDictionary *)_fileForUUID:(NSString *)uuid way:(tcfile_way)way index:(NSUInteger *)index
{
	// > main queue <
	
	__block NSMutableDictionary *result = nil;
	
	[_files enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull file, NSUInteger idx, BOOL * _Nonnull stop) {
		
		NSString	*auuid = file[TCFileUUIDKey];
		tcfile_way	away = (tcfile_way)[file[TCFileWayKey] intValue];
		
		if (away != way || [auuid isEqualToString:uuid] == NO)
			return;
		
		result = file;
		
		if (index)
			*index = idx;
		
		*stop = YES;
	}];

	return result;
}

@end


NS_ASSUME_NONNULL_END

