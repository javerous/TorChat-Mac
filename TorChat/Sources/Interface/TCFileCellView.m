/*
 *  TCFileCellView.m
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



#import "TCFileCellView.h"

#import "TCButton.h"
#import "TCFilesCommon.h"



/*
** Prototypes
*/
#pragma mark - Prototypes

static NSString *NSStringFromFileSize(uint64_t size);



/*
** TCFileCellView - Private
*/
#pragma mark - TCFileCellView - Private

@interface TCFileCellView ()

@property (retain, nonatomic) IBOutlet NSButton		*iconButton;
@property (retain, nonatomic) IBOutlet NSTextField	*fileNameField;
@property (retain, nonatomic) IBOutlet NSTextField	*transferStatusField;
@property (retain, nonatomic) IBOutlet NSTextField	*transferDirectionField;
@property (retain, nonatomic) IBOutlet NSProgressIndicator	*transferIndicator;
@property (retain, nonatomic) IBOutlet TCButton		*showButton;
@property (retain, nonatomic) IBOutlet TCButton		*cancelButton;

@end



/*
** TCFileCellView
*/
#pragma mark - TCFileCellView

@implementation TCFileCellView


/*
** TCFileCellView - Instance
*/
#pragma mark - TCFileCellView - Instance

- (void)awakeFromNib
{
	[_showButton setImage:[NSImage imageNamed:@"file_reveal"]];
	[_showButton setRollOverImage:[NSImage imageNamed:@"file_reveal_rollover"]];
	[_showButton setPushImage:[NSImage imageNamed:@"file_reveal_pushed"]];

	[_cancelButton setImage:[NSImage imageNamed:@"file_stop"]];
	[_cancelButton setRollOverImage:[NSImage imageNamed:@"file_stop_rollover"]];
	[_cancelButton setPushImage:[NSImage imageNamed:@"file_stop_pushed"]];
}



/*
** TCFileCellView - Content
*/
#pragma mark - TCFileCellView - Content

- (void)setContent:(NSDictionary *)content
{
	if (!content)
		return;
	
	NSImage		*icon = [content objectForKey:TCFileIconKey];
	NSString	*path = [content objectForKey:TCFileFilePathKey];
	NSString	*buddyName = [content objectForKey:TCFileBuddyNameKey];
	NSString	*buddyAddress = [content objectForKey:TCFileBuddyAddressKey];
	NSString	*txtStatus = [content objectForKey:TCFileStatusTextKey];
	tcfile_way	way = (tcfile_way)[[content objectForKey:TCFileWayKey] intValue];
	uint64_t	fileSize = [[content objectForKey:TCFileSizeKey] unsignedLongLongValue];
	uint64_t	fileCompletedSize = [[content objectForKey:TCFileCompletedKey] unsignedLongLongValue];
	double		fileDone = (double)fileCompletedSize / (double)fileSize;
	NSColor		*txtColor = nil;
	
	// Icon.
	[_iconButton setImage:icon];
	
	// Name.
	NSString *name = [path lastPathComponent];
	
	[_fileNameField setStringValue:name];
	
	// Indicator.
	[_transferIndicator setDoubleValue:fileDone];
	
	// Status.
	NSString *directionText = nil;
	NSString *statusText;
	
	if (way == tcfile_upload)
		directionText = NSLocalizedString(@"file_progress_to", @"");
	else if (way == tcfile_download)
		directionText = NSLocalizedString(@"file_progress_from", @"");
	
	statusText = [NSString stringWithFormat:@"%@ %@ (%@) - %@ %@ %@", directionText, buddyName, buddyAddress, NSStringFromFileSize(fileCompletedSize), NSLocalizedString(@"file_progress_of", @""), NSStringFromFileSize(fileSize)];

	[_transferStatusField setTextColor:txtColor];
	[_transferStatusField setStringValue:statusText];
	
	// Status.
	[_transferDirectionField setTextColor:[NSColor grayColor]];
	[_transferDirectionField setStringValue:txtStatus];
}



/*
** TCFileCellView - NSTableCellView
*/
#pragma mark - TCFileCellView - NSTableCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    [super setBackgroundStyle:style];
	
    switch (style)
	{
        case NSBackgroundStyleLight:
			[_transferDirectionField setTextColor:[NSColor grayColor]];
            break;
			
        case NSBackgroundStyleDark:
        default:
			[_transferDirectionField setTextColor:[NSColor whiteColor]];
            break;
    }
}

@end



/*
** C Functions
*/
#pragma mark - C Functions

// == Render bytes ==
static NSString *NSStringFromFileSize(uint64_t size)
{
	uint64_t	gb = 0;
	float		fgb;
	uint64_t	mb = 0;
	float		fmb;
	uint64_t	kb = 0;
	float		fkb;
	uint64_t	b = 0;
	
	
	// Compute GB
	gb = size / (1024 * 1024 * 1024);
	fgb = (float)size / (float)(1024 * 1024 * 1024);
	size = size % (1024 * 1024 * 1024);
	
	// Compute MB
	mb = size / (1024 * 1024);
	fmb = (float)size / (float)(1024 * 1024);
	size = size % (1024 * 1024);
	
	// Compute KB
	kb = size / (1024);
	fkb = (float)size / (float)(1024);
	size = size % (1024);
	
	// Compute B
	b = size;
	
	
	if (gb)
	{
		if (mb)
			return [NSString stringWithFormat:@"%.02f %@", fgb, NSLocalizedString(@"file_gb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", gb, NSLocalizedString(@"file_gb", @"")];
	}
	else if (mb)
	{
		if (kb)
			return [NSString stringWithFormat:@"%.02f %@", fmb, NSLocalizedString(@"file_mb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", mb, NSLocalizedString(@"file_mb", @"")];
	}
	else if (kb)
	{
		if (b)
			return [NSString stringWithFormat:@"%.02f %@", fkb, NSLocalizedString(@"file_kb", @"")];
		else
			return [NSString stringWithFormat:@"%llu %@", kb, NSLocalizedString(@"file_kb", @"")];
	}
	else if (b)
		return [NSString stringWithFormat:@"%llu %@", b, NSLocalizedString(@"file_b", @"")];
	
	return [NSString stringWithFormat:@"0 %@", NSLocalizedString(@"file_b", @"")];
}

