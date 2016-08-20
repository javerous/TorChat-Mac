/*
 *  TCFileCellView.m
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

#import "TCFileCellView.h"

#import "TCButton.h"
#import "TCFilesCommon.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCFileCellView - Private
*/
#pragma mark - TCFileCellView - Private

@interface TCFileCellView ()

@property (strong, nonatomic) IBOutlet TCButton		*iconButton;
@property (retain, nonatomic) IBOutlet NSTextField	*fileNameField;
@property (retain, nonatomic) IBOutlet NSTextField	*transferStatusField;
@property (retain, nonatomic) IBOutlet NSTextField	*transferDirectionField;
@property (retain, nonatomic) IBOutlet NSProgressIndicator	*transferIndicator;
@property (strong, nonatomic) IBOutlet TCButton		*showButton;
@property (strong, nonatomic) IBOutlet TCButton		*cancelButton;

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
	_showButton.image = (NSImage *)[NSImage imageNamed:@"file_reveal"];
	_showButton.overImage = (NSImage *)[NSImage imageNamed:@"file_reveal_rollover"];
	_showButton.pushImage = (NSImage *)[NSImage imageNamed:@"file_reveal_pushed"];
	
	_cancelButton.image = (NSImage *)[NSImage imageNamed:@"file_stop"];
	_cancelButton.overImage = (NSImage *)[NSImage imageNamed:@"file_stop_rollover"];
	_cancelButton.pushImage = (NSImage *)[NSImage imageNamed:@"file_stop_pushed"];
}



/*
** TCFileCellView - Content
*/
#pragma mark - TCFileCellView - Content

- (void)setContent:(NSDictionary *)content
{
	NSAssert(content, @"content is nil");

	_content = content;
	
	NSImage		*icon = [content objectForKey:TCFileIconKey];
	NSString	*path = [content objectForKey:TCFileFilePathKey];
	NSString	*buddyName = [content objectForKey:TCFileBuddyNameKey];
	NSString	*buddyIdentifier = [content objectForKey:TCFileBuddyIdentifierKey];
	NSString	*txtStatus = [content objectForKey:TCFileStatusTextKey];
	tcfile_way	way = (tcfile_way)[[content objectForKey:TCFileWayKey] intValue];
	uint64_t	fileSize = [[content objectForKey:TCFileSizeKey] unsignedLongLongValue];
	uint64_t	fileCompletedSize = [[content objectForKey:TCFileCompletedKey] unsignedLongLongValue];
	double		fileDone = (double)fileCompletedSize / (double)fileSize;
	NSColor		*txtColor = nil;
	
	// Icon.
	_iconButton.image = icon;
	_iconButton.pushImage = [NSImage imageWithSize:icon.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		
		NSRect rect = NSMakeRect(0, 0, icon.size.width, icon.size.height);
		
		[icon drawInRect:rect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];

		[[NSColor colorWithWhite:0 alpha:0.5] set];
		
		NSRectFillUsingOperation(rect, NSCompositeSourceAtop);
		
		return YES;
	}];
	
	// Name.
	NSString *name = [path lastPathComponent];
	
	[_fileNameField setStringValue:name];
	
	// Indicator.
	[_transferIndicator setDoubleValue:fileDone];
	
	// Status.
	NSString *statusText;
	
	// > Build direction.
	NSString *directionText = nil;

	if (way == tcfile_upload)
		directionText = NSLocalizedString(@"file_progress_to", @"");
	else if (way == tcfile_download)
		directionText = NSLocalizedString(@"file_progress_from", @"");
	
	// > Build progress.
	NSString *progressText = nil;
	NSNumber *remainingTime = content[TCFileRemainingTimeKey];
	NSString *completedStr = SMStringFromBytesAmount(fileCompletedSize);
	NSString *totalStr = SMStringFromBytesAmount(fileSize);
	
	if (!remainingTime || [remainingTime doubleValue] == -2.0 || [remainingTime doubleValue] == 0)
		progressText = [NSString stringWithFormat:NSLocalizedString(@"file_progress", @""), completedStr, totalStr];
	else if ([remainingTime doubleValue] == -1.0)
		progressText = [NSString stringWithFormat:NSLocalizedString(@"file_progress_stalled", @""), completedStr, totalStr];
	else
		progressText = [NSString stringWithFormat:NSLocalizedString(@"file_progress_remaining", @""), completedStr, totalStr, SMStringFromSecondsAmount([remainingTime doubleValue])];

	// > Build final status.
	statusText = [NSString stringWithFormat:@"%@ %@ (%@) - %@", directionText, buddyName, buddyIdentifier, progressText];

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


NS_ASSUME_NONNULL_END
