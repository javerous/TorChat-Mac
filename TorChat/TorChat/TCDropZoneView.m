/*
 *  TCDropZoneView.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
 *
 *  This file is part of TorChat.
 *
 *  TorProxifier is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  TorProxifier is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with TorProxifier.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import "TCDropZoneView.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCDropZoneView
*/
#pragma mark - TCDropZoneView

@implementation TCDropZoneView
{
	// Configuration.
	CGFloat _lineWidth;
	CGFloat	_linePattern[2];
	
	// Derivated values.
	CGFloat _marginSize;
	CGFloat _lineRadius;
}


/*
** TCDropZoneView - Instance
*/
#pragma mark - TCDropZoneView - Instance

- (void)commonInit
{
	// Properties.
	_lineWidth = 5.0;
	
	_linePattern[0] = 24.0;
	_linePattern[1] = 14.0;
	
	_marginSize = 10.0 + _lineWidth / 2.0;
	_lineRadius = (2.0 * _linePattern[0]) / M_PI; // compute radius so the curve is the exact same length than linePattern[0].
	
	_dashColor = [NSColor colorWithRed:(155.0 / 255.0) green:(155.0 / 255.0) blue:(155.0 / 255.0) alpha:1.0];
	
	// Drag & drop.
	[self registerForDraggedTypes:@[NSFilenamesPboardType]];
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
	self = [super initWithFrame:frameRect];
	
	if (self)
	{
		[self commonInit];
	}
	
	return self;
}

- (nullable instancetype)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	
	if (self)
	{
		[self commonInit];
	}
	
	return self;
}



/*
** TCDropZoneView - Tools
*/
#pragma mark - TCDropZoneView - Tools

- (NSSize)computeSizeForSymmetricalDashesWithMinWidth:(CGFloat)minWidth minHeight:(CGFloat)minHeight
{
	// Compute good height.
	CGFloat tMinHeight = 2.0 * (_lineRadius + _marginSize) + _linePattern[1];
	
	if (minHeight <= tMinHeight)
		minHeight = tMinHeight;
	else
	{
		CGFloat delta = minHeight - tMinHeight;
		CGFloat dcount = ceil(delta / (_linePattern[1] + _linePattern[0]));
		
		minHeight = tMinHeight + dcount * (_linePattern[1] + _linePattern[0]);
	}
	
	// Compute good width.
	CGFloat tMinWidth = 2.0 * (_lineRadius + _marginSize) + _linePattern[1];
	
	if (minWidth <= tMinWidth)
		minWidth = tMinWidth;
	else
	{
		CGFloat delta = minWidth - tMinWidth;
		CGFloat dcount = ceil(delta / (_linePattern[1] + _linePattern[0]));
		
		minWidth = tMinWidth + dcount * (_linePattern[1] + _linePattern[0]);
	}
	
	// Give result.
	return NSMakeSize(minWidth, minHeight);
}



/*
** TCDropZoneView - NSView
*/
#pragma mark - TCDropZoneView - NSView

- (void)drawRect:(NSRect)dirtyRect
{
	// Dashed line border.
	// > Configure.
	NSRect			insetFrame = NSInsetRect(self.bounds, _marginSize, _marginSize);
	NSBezierPath	*border = [NSBezierPath bezierPathWithRoundedRect:insetFrame xRadius:_lineRadius yRadius:_lineRadius];
	
	border.lineWidth = _lineWidth;
	[border setLineDash:_linePattern count:2 phase:0.0];

	// > Draw.
	[self.dashColor set];
	[border stroke];
	
	
	// Content.
	NSSize imgSize = NSZeroSize;
	NSSize strSize = NSZeroSize;

	// > Handle image size.
	NSImage *img = self.dropImage;
	
	if (img)
		imgSize = img.size;
	
	// > Handle text size.
	NSAttributedString *str = self.dropString;
	
	if (str)
		strSize = str.size;
	
	// > Compute size.
	CGFloat wholeHeight = imgSize.height + strSize.height;

	// > Draw image.
	if (img)
	{
		NSRect drawRect;
		
		drawRect.origin.x = insetFrame.origin.x + (insetFrame.size.width - imgSize.width) / 2.0;
		drawRect.origin.y = insetFrame.origin.y + (insetFrame.size.height - wholeHeight) / 2.0 + strSize.height;
		drawRect.size = imgSize;
		
		[img drawInRect:drawRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0f];
	}
	
	// > Draw string.
	if (str)
	{
		NSPoint drawPoint;
		
		drawPoint.x = insetFrame.origin.x + (insetFrame.size.width - strSize.width) / 2.0;
		drawPoint.y = insetFrame.origin.y + (insetFrame.size.height - wholeHeight) / 2.0;

		[str drawAtPoint:drawPoint];
	}
}



/*
** TCDropZoneView - NSDraggingDestination
*/
#pragma mark - TCDropZoneView - NSView

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	void (^droppedFilesHandler)(NSArray *files) = self.droppedFilesHandler;
	
	if (!droppedFilesHandler)
		return NSDragOperationNone;
	
	return NSDragOperationCopy;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
	void (^droppedFilesHandler)(NSArray *files) = self.droppedFilesHandler;
	
	if (!droppedFilesHandler)
		return NO;
	
	if ([pboard.types containsObject:NSFilenamesPboardType])
	{
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		droppedFilesHandler(files);

		return YES;
	}
	
	return NO;
}

@end


NS_ASSUME_NONNULL_END
