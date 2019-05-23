/*
 *  TCFileCellView.m
 *
 *  Copyright 2019 Avérous Julien-Pierre
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
	
	NSNumber				*transferRemainingTime = content[TCFileTransferRemainingTimeKey];
	uint64_t				transferCompletedSize = [content[TCFileTransferCompletedKey] unsignedLongLongValue];
	NSString				*transferStatusText = content[TCFileTransferStatusTextKey];
	TCFileTransferDirection	transferDirection = (TCFileTransferDirection)[content[TCFileTransferDirectionKey] intValue];

	
	NSImage		*icon = content[TCFileIconKey];
	NSString	*fileName = content[TCFileFileNameKey];
	NSString	*buddyName = content[TCFileBuddyNameKey];
	NSString	*buddyIdentifier = content[TCFileBuddyIdentifierKey];
	uint64_t	fileSize = [content[TCFileSizeKey] unsignedLongLongValue];
	double		fileDone = (double)transferCompletedSize / (double)fileSize;
	NSColor		*txtColor = nil;
	

	// Icon.
	_iconButton.image = icon;
	_iconButton.pushImage = [NSImage imageWithSize:icon.size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		
		NSRect rect = NSMakeRect(0, 0, icon.size.width, icon.size.height);
		
		[icon drawInRect:rect fromRect:NSZeroRect operation:NSCompositingOperationSourceOver fraction:1.0f];

		[[NSColor colorWithWhite:0 alpha:0.5] set];
		
		NSRectFillUsingOperation(rect, NSCompositingOperationSourceAtop);
		
		return YES;
	}];
	
	// Name.
	_fileNameField.stringValue = fileName;
	
	// Indicator.
	_transferIndicator.doubleValue = fileDone;
	
	// Status.
	NSString *statusText;
	
	// > Build direction.
	NSString *directionText = nil;

	if (transferDirection == TCFileTransferDirectionUpload)
		directionText = NSLocalizedString(@"file_progress_to", @"");
	else if (transferDirection == TCFileTransferDirectionDownload)
		directionText = NSLocalizedString(@"file_progress_from", @"");
	
	// > Build progress.
	NSString *progressText = nil;
	NSString *completedStr = SMStringFromBytesAmount(transferCompletedSize);
	NSString *totalStr = SMStringFromBytesAmount(fileSize);
	
	if (!transferRemainingTime || transferRemainingTime.doubleValue == -2.0 || transferRemainingTime.doubleValue == 0)
		progressText = [NSString stringWithFormat:NSLocalizedString(@"file_progress", @""), completedStr, totalStr];
	else if (transferRemainingTime.doubleValue == -1.0)
		progressText = [NSString stringWithFormat:NSLocalizedString(@"file_progress_stalled", @""), completedStr, totalStr];
	else
		progressText = [NSString stringWithFormat:NSLocalizedString(@"file_progress_remaining", @""), completedStr, totalStr, SMStringFromSecondsAmount(transferRemainingTime.doubleValue)];

	// > Build final status.
	statusText = [NSString stringWithFormat:@"%@ %@ (%@) - %@", directionText, buddyName, buddyIdentifier, progressText];

	_transferStatusField.textColor = txtColor;
	_transferStatusField.stringValue = statusText;
	
	// Status.
	_transferDirectionField.textColor = [NSColor grayColor];
	_transferDirectionField.stringValue = transferStatusText;
}



/*
** TCFileCellView - NSTableCellView
*/
#pragma mark - TCFileCellView - NSTableCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    super.backgroundStyle = style;
	
    switch (style)
	{
        case NSBackgroundStyleLight:
			_transferDirectionField.textColor = [NSColor grayColor];
            break;
			
        case NSBackgroundStyleDark:
        default:
			_transferDirectionField.textColor = [NSColor whiteColor];
            break;
    }
}

@end


NS_ASSUME_NONNULL_END
