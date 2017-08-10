/*
 *  TCFilesWindowController.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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
#define TCFileTransferUUIDKey			@"xuuid"
#define TCFileTransferSpeedHelperKey	@"xspeed_helper"
#define TCFileTransferStatusKey			@"xstatus"

#define TCFileIconContextKey	@"icon_ctx"
#define TCFileCancelContextKey	@"cancel_ctx"
#define TCFileShowContextKey	@"show_ctx"



/*
** TCFilesWindowController - Private
*/
#pragma mark - TCFilesWindowController - Private

@interface TCFilesWindowController () <TCCoreManagerObserver, TCBuddyObserver>
{
	id <TCConfigApp> _configuration;
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

- (instancetype)initWithConfiguration:(id <TCConfigApp>)configuration coreManager:(TCCoreManager *)coreMananager
{
	self = [super initWithWindow:nil];
	
    if (self)
	{
		// Hold parameters.
		_configuration = configuration;
		_core = coreMananager;
		
		// Alloc containers.
		_files =  [[NSMutableArray alloc] init];
		_buddies = [[NSMutableSet alloc] init];
		
		// Observe.
		[_core addObserver:self];
		
		// Handle current buddies.
		NSArray *buddies = _core.buddies;
		
		for (TCBuddy *buddy in buddies)
		{
			[buddy addObserver:self];
			[_buddies addObject:buddy];
		};
    }
    
    return self;
}



/*
** TCFilesWindowController - NSWindowController + NSWindowDelegate
*/
#pragma mark - TCFilesWindowController - NSWindowController + NSWindowDelegate

- (nullable NSString *)windowNibName
{
	return @"FilesWindow";
}

- (id)owner
{
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	// Place window.
	NSString *windowFrame = [_configuration generalSettingValueForKey:@"window-frame-files"];
	
	if (windowFrame)
		[self.window setFrameFromString:windowFrame];
	else
		[self.window center];
	
	// Update count.
	[self _updateCount];
}



/*
** TCFilesWindowController - Synchronize
*/
#pragma mark - TCFilesWindowController - Synchronize

- (void)synchronizeWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if (self.windowLoaded)
			[_configuration setGeneralSettingValue:self.window.stringWithSavedFrame forKey:@"window-frame-files"];

		handler();
	});
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
				[self startFileTransferUUID:finfo.uuid filePath:finfo.filePath fileName:finfo.fileName buddyIdentifier:buddy.identifier buddyName:buddy.finalName transferDirection:TCFileTransferDirectionUpload fileSize:finfo.fileSizeTotal];
				
				break;
			}
				
			case TCBuddyEventFileSendRunning:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[self updateFileTransferUUID:finfo.uuid transferDirection:TCFileTransferDirectionUpload completedSize:finfo.fileSizeCompleted];
				
				break;
			}
				
			case TCBuddyEventFileSendFinish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self updateFileTransferUUID:finfo.uuid transferDirection:TCFileTransferDirectionUpload transferStatus:TCFileTransferStatusFinish transferTextStatus:NSLocalizedString(@"file_upload_done", @"")];
				
				break;
			}
				
			case TCBuddyEventFileSendStopped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self updateFileTransferUUID:finfo.uuid transferDirection:TCFileTransferDirectionUpload transferStatus:TCFileTransferStatusStopped transferTextStatus:NSLocalizedString(@"file_upload_stopped", @"")];
				
				break;
			}
				
			case TCBuddyEventFileReceiveStart:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Add the file transfert to the controller
				[self startFileTransferUUID:finfo.uuid filePath:finfo.filePath fileName:finfo.fileName buddyIdentifier:buddy.identifier buddyName:buddy.finalName transferDirection:TCFileTransferDirectionDownload fileSize:finfo.fileSizeTotal];
				
				break;
			}
				
			case TCBuddyEventFileReceiveRunning:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update bytes received
				[self updateFileTransferUUID:finfo.uuid transferDirection:TCFileTransferDirectionDownload completedSize:finfo.fileSizeCompleted];

				break;
			}
				
			case TCBuddyEventFileReceiveFinish:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self updateFileTransferUUID:finfo.uuid transferDirection:TCFileTransferDirectionDownload transferStatus:TCFileTransferStatusFinish transferTextStatus:NSLocalizedString(@"file_download_done", @"")];

				break;
			}
				
			case TCBuddyEventFileReceiveStopped:
			{
				TCFileInfo *finfo = (TCFileInfo *)info.context;
				
				if (!finfo)
					return;
				
				// Update status
				[self updateFileTransferUUID:finfo.uuid transferDirection:TCFileTransferDirectionDownload transferStatus:TCFileTransferStatusStopped transferTextStatus:NSLocalizedString(@"file_download_stopped", @"")];

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
	
	if (row < 0 || row >= _files.count)
		return;
	
	NSDictionary	*file = _files[(NSUInteger)row];
	NSString		*path = file[TCFileFilePathKey];
	
	if (path)
		[[NSWorkspace sharedWorkspace] selectFile:path inFileViewerRootedAtPath:@""];
}

- (IBAction)doCancelTransfer:(id)sender
{
	// Get transfert info.
	NSInteger row = [_filesView rowForView:sender];
	
	if (row < 0 || row >= _files.count)
		return;
	
	NSDictionary *file = _files[(NSUInteger)row];

	// Search the buddy associated with this transfert.
	NSString	*identifier = file[TCFileBuddyIdentifierKey];
	NSString	*transferUUID = file[TCFileTransferUUIDKey];
	TCFileTransferDirection transferDirection = (TCFileTransferDirection)[file[TCFileTransferDirectionKey] intValue];
	
	
	for (TCBuddy *buddy in _buddies)
	{
		if ([buddy.identifier isEqualToString:identifier])
		{
			// > Change the file status.
			[self updateFileTransferUUID:transferUUID transferDirection:transferDirection transferStatus:TCFileTransferStatusCancel transferTextStatus:NSLocalizedString(@"file_canceling", @"")];
			
			// > Cancel the transfert.
			if (transferDirection == TCFileTransferDirectionUpload)
				[buddy cancelTransferForTransferUUID:transferUUID transferDirection:TCBuddyFileTransferDirectionSend];
			else if (transferDirection == TCFileTransferDirectionDownload)
				[buddy cancelTransferForTransferUUID:transferUUID transferDirection:TCBuddyFileTransferDirectionReceive];
			
			return;
		}
	}
}

- (IBAction)doOpenTransfer:(id)sender
{
	NSInteger row = [_filesView rowForView:sender];
	
	if (row < 0 || row >= _files.count)
		return;
	
	NSDictionary	*file = _files[(NSUInteger)row];
	NSString		*path = file[TCFileFilePathKey];
	
	if (path)
		[[NSWorkspace sharedWorkspace] openFile:path];
}

- (IBAction)doClear:(id)sender
{
	NSMutableIndexSet	*indSet = [NSMutableIndexSet indexSet];
	NSUInteger			i, cnt = _files.count;
	
	for (i = 0; i < cnt; i++)
	{
		NSDictionary			*file = _files[i];
		TCFileTransferStatus	status = (TCFileTransferStatus)[file[TCFileTransferStatusKey] intValue];

		if (status != TCFileTransferStatusRunning)
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
	return (NSInteger)_files.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	// Get cell.
	TCFileCellView			*cellView = nil;
	NSDictionary			*file = _files[(NSUInteger)rowIndex];
	TCFileTransferStatus	status = (TCFileTransferStatus)[file[TCFileTransferStatusKey] intValue];

	if (status == TCFileTransferStatusRunning)
		cellView = [tableView makeViewWithIdentifier:@"transfers_progress" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"transfers_end" owner:self];

	// Set content.
	cellView.content = file;
	
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
	
	if (file[TCFileFilePathKey] == nil)
	{
		cellView.iconButton.actionHandler = nil;
	}
	else if (cellView.iconButton.actionHandler == nil)
	{
		cellView.iconButton.actionHandler = ^(TCButton *button) {
			[weakSelf doOpenTransfer:button];
		};
	}
	
	// Set button context.
	cellView.iconButton.context = (TCButtonContext *)file[TCFileIconContextKey];
	cellView.cancelButton.context = (TCButtonContext *)file[TCFileCancelContextKey];
	cellView.showButton.context = (TCButtonContext *)file[TCFileShowContextKey];
	
	// Set button visibility.
	cellView.showButton.hidden = (file[TCFileFilePathKey] == nil);

	return cellView;
}

- (BOOL)doDeleteKeyInTableView:(NSTableView *)aTableView
{
	NSIndexSet			*set = _filesView.selectedRowIndexes;
	NSMutableIndexSet	*final = [NSMutableIndexSet indexSet];
    NSUInteger			currentIndex = set.firstIndex;
	
    while (currentIndex != NSNotFound)
	{
		NSDictionary			*file = _files[currentIndex];
		TCFileTransferStatus	status = (TCFileTransferStatus)[file[TCFileTransferStatusKey] intValue];

		if (status != TCFileTransferStatusRunning)
			[final addIndex:currentIndex];

        currentIndex = [set indexGreaterThanIndex:currentIndex];
    }
	
	if (final.count == 0)
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

- (void)startFileTransferUUID:(NSString *)uuid filePath:(nullable NSString *)filePath fileName:(NSString *)fileName buddyIdentifier:(NSString *)identifier buddyName:(NSString *)name transferDirection:(TCFileTransferDirection)transferDirection fileSize:(uint64_t)size
{
	NSAssert(uuid, @"uuid is nil");
	NSAssert(filePath || transferDirection == TCFileTransferDirectionUpload, @"filePath is nil while file download");
	NSAssert(name, @"name is nil");
	NSAssert(identifier, @"identifier is nil");
	
	// Build file description
	NSMutableDictionary *item = [[NSMutableDictionary alloc] init];
	
	// > Set icon.
	NSImage *icon = [[NSWorkspace sharedWorkspace] iconForFileType:fileName.pathExtension];
	
	icon.size = NSMakeSize(50, 50);
	[icon lockFocus];
	{
		NSImage *badge = nil;
		
		if (transferDirection == TCFileTransferDirectionUpload)
			badge = [NSImage imageNamed:@"file_up"];
		else if (transferDirection == TCFileTransferDirectionDownload)
			badge = [NSImage imageNamed:@"file_down"];
		
		if (badge)
			[badge drawAtPoint:NSMakePoint(50 - 16, 0) fromRect:NSMakeRect(0, 0, 16, 16) operation:NSCompositeSourceOver fraction:1.0];
	}
	[icon unlockFocus];
	
	item[TCFileIconKey] = icon;
	
	// > Create speed helper.
	SMSpeedHelper *speedHelper = [[SMSpeedHelper alloc] initWithCompleteAmount:size];

	speedHelper.updateHandler = ^(NSTimeInterval remainingTime) {
		dispatch_async(dispatch_get_main_queue(), ^{
			
			NSUInteger			idx = NSNotFound;
			NSMutableDictionary *file = [self _fileInfoForTransferUUID:uuid transferDirection:transferDirection index:&idx];
			
			if (!file)
				return;
			
			file[TCFileTransferRemainingTimeKey] = @(remainingTime);
			[_filesView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:idx] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		});
	};
	
	// > Set button context.
	item[TCFileIconContextKey] = [TCButton createEmptyContext];
	item[TCFileCancelContextKey] = [TCButton createEmptyContext];
	item[TCFileShowContextKey] = [TCButton createEmptyContext];
	
	// > Set general info.
	item[TCFileTransferUUIDKey] = uuid;
	if (filePath)
		item[TCFileFilePathKey] = filePath;
	item[TCFileFileNameKey] = fileName;
	item[TCFileBuddyIdentifierKey] = identifier;
	item[TCFileBuddyNameKey] = name;
	item[TCFileSizeKey] = @(size);
	
	// > Set transfer info.
	item[TCFileTransferSpeedHelperKey] = speedHelper;
	item[TCFileTransferDirectionKey] = @(transferDirection);
	item[TCFileTransferStatusKey] = @(TCFileTransferStatusRunning);
	item[TCFileTransferCompletedKey] = @0;

	if (transferDirection == TCFileTransferDirectionUpload)
		item[TCFileTransferStatusTextKey] = NSLocalizedString(@"file_uploading", @"");
	else if (transferDirection == TCFileTransferDirectionDownload)
		item[TCFileTransferStatusTextKey] = NSLocalizedString(@"file_downloading", @"");
	
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

- (void)updateFileTransferUUID:(NSString *)uuid transferDirection:(TCFileTransferDirection)direction transferStatus:(TCFileTransferStatus)status transferTextStatus:(NSString *)textStatus
{
	NSAssert(textStatus, @"txtStatus is nil");
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Search file.
		NSUInteger			idx = NSNotFound;
		NSMutableDictionary	*file = [self _fileInfoForTransferUUID:uuid transferDirection:direction index:&idx];
		
		if (!file)
			return;
		
		// Update status.
		file[TCFileTransferStatusKey] = @(status);
		file[TCFileTransferStatusTextKey] = textStatus;

		// Remove speed updater.
		if (status != TCFileTransferStatusRunning)
		{
			SMSpeedHelper *speedHelper = file[TCFileTransferSpeedHelperKey];
			
			speedHelper.updateHandler = nil;
			
			[file removeObjectForKey:TCFileTransferSpeedHelperKey];
			[file removeObjectForKey:TCFileTransferRemainingTimeKey];
		}
		
		// Reload table.
		[_filesView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:idx] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		[self _updateCount];
	});
}

- (void)updateFileTransferUUID:(NSString *)uuid transferDirection:(TCFileTransferDirection)direction completedSize:(uint64_t)size
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Search file.
		NSUInteger			idx = NSNotFound;
		NSMutableDictionary *file = [self _fileInfoForTransferUUID:uuid transferDirection:direction index:&idx];
		
		if (!file)
			return;
		
		// Update completed.
		file[TCFileTransferCompletedKey] = @(size);
		
		// Update speed helper.
		SMSpeedHelper *speedHelper = file[TCFileTransferSpeedHelperKey];
		
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
	
	unsigned countUpload = 0;
	unsigned countDownload = 0;
	unsigned coutRunning = 0;
	unsigned countNotRunning = 0;
	
	for (NSDictionary *file in _files)
	{
		TCFileTransferStatus		transferStatus = (TCFileTransferStatus)[file[TCFileTransferStatusKey] intValue];
		TCFileTransferDirection		transferDirection = (TCFileTransferDirection)[file[TCFileTransferDirectionKey] intValue];
		
		if (transferStatus == TCFileTransferStatusRunning)
			coutRunning++;
		else
			countNotRunning++;
		
		if (transferDirection == TCFileTransferDirectionUpload)
			countUpload++;
		else if (transferDirection == TCFileTransferDirectionDownload)
			countDownload++;
	}
	
	// Activate items
	_clearButton.enabled = (countNotRunning > 0);
	_countField.hidden = (_files.count == 0);

	NSString *key;

	// Build up string
	NSString *textUpload = nil;
	
	key = NSLocalizedString(@"file_uploads", @"");
	
	if (countUpload > 1)
		textUpload = [NSString stringWithFormat:key, countUpload];
	else if (countUpload > 0)
		textUpload = NSLocalizedString(@"file_one_upload", @"");
	
	// Build down string
	NSString *textDownload = nil;
	
	key = NSLocalizedString(@"file_downloads", @"");

	if (countDownload > 1)
		textDownload = [NSString stringWithFormat:key, countDownload];
	else if (countDownload > 0)
		textDownload = NSLocalizedString(@"file_one_download", @"");

	// Show the final string
	if (textUpload && textDownload)
		_countField.stringValue = [NSString stringWithFormat:@"%@ — %@", textDownload, textUpload];
	else
	{
		if (textUpload)
			_countField.stringValue = textUpload;
		else if (textDownload)
			_countField.stringValue = textDownload;
	}
}

- (NSMutableDictionary *)_fileInfoForTransferUUID:(NSString *)uuid transferDirection:(TCFileTransferDirection)direction index:(NSUInteger *)index
{
	// > main queue <
	
	__block NSMutableDictionary *result = nil;
	
	[_files enumerateObjectsUsingBlock:^(NSMutableDictionary * _Nonnull file, NSUInteger idx, BOOL * _Nonnull stop) {
		
		NSString	*auuid = file[TCFileTransferUUIDKey];
		TCFileTransferDirection	adirection = (TCFileTransferDirection)[file[TCFileTransferDirectionKey] intValue];
		
		if (adirection != direction || [auuid isEqualToString:uuid] == NO)
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

