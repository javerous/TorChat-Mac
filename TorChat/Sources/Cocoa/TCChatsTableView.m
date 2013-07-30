/*
 *  TCChatsTableView.m
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



#import "TCChatsTableView.h"



/*
** TCDropView
*/
#pragma mark - TCDropView

@interface TCDropView : NSImageView

@property (weak, nonatomic)		id <TCChatsTableViewDropDelegate>	dropDelegate;
@property (weak, nonatomic)		TCChatsTableView					*tableView;
@property (assign, nonatomic)	NSUInteger							dropRow;

@end

@implementation TCDropView

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{	
	return NSDragOperationMove;
}

- (void)draggingEnded:(id < NSDraggingInfo >)sender
{
}

- (BOOL)prepareForDragOperation:(id < NSDraggingInfo >)sender
{
	return YES;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
	NSRect frame = [self.window frame];
	
	[self.window orderOut:self];

	// Send to delegate.
	id <TCChatsTableViewDropDelegate> dropDelegate = _dropDelegate;
	
	[dropDelegate tableView:self.tableView droppedRow:self.dropRow toFrame:frame];

	return YES;
}

@end



/*
** TCChatsTableView ()
*/
#pragma mark - TCChatsTableView ()

@interface TCChatsTableView ()
{
	NSWindow	*_window;
	
	NSImage		*_dragImage;
	NSImage		*_dropImage;
	
	TCDropView	*_dropView;
	NSImageView	*_dragView;
	
	BOOL		_dropMode;
	
	NSIndexSet	*_indexSet;
}

- (NSView *)searchViewAtPoint:(NSPoint)pt;

@end



/*
** TCChatsTableView
*/
#pragma mark - TCChatsTableView

@implementation TCChatsTableView


/*
** TCChatsTableView - Drag & Drop
*/
#pragma mark - TCChatsTableView - Drag & Drop

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
	// FIXME: use dragImageOffset for drags
	
	// Store the drag image
	_dragImage = [super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset];
	
	// Hold indexes
	_indexSet = dragRows;
	
	// Show an empty one
	return [[NSImage alloc] initWithSize:NSMakeSize(1, 1)];
}

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)aPoint
{
	NSRect		winRect;
	NSSize		size;
	NSUInteger	drow;
	
	drow = [_indexSet firstIndex];
	
	// Configure views
	// > Drag View
	_dragView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, [_dragImage size].width, [_dragImage size].height)];
	[_dragView setImageScaling:NSScaleToFit];
	[_dragView setImage:_dragImage];
	
	// > Drop View
	_dropView = [[TCDropView alloc] initWithFrame:NSMakeRect(0, 0, [_dropImage size].width, [_dropImage size].height)];
	[_dropView setImageScaling:NSScaleToFit];
	
	// >> Get drop image.
	id <TCChatsTableViewDropDelegate> dropDelegate = _dropDelegate;
	
	_dropImage = [dropDelegate tableView:self dropImageForRow:drow];

	// >> Set image.
	[_dropView setImage:_dropImage];
	_dropView.dropDelegate = dropDelegate;
	_dropView.tableView = self;
	_dropView.dropRow = drow;
	
	[_dropView registerForDraggedTypes:[self registeredDraggedTypes]];

	// Compute window size
	winRect = NSMakeRect(0, 0, fmax([_dropImage size].width, [_dragImage size].width), fmax([_dropImage size].height, [_dragImage size].height));
		
	// Create the drop window
	_window = [[NSWindow alloc] initWithContentRect:winRect
										  styleMask:NSBorderlessWindowMask 
											backing:NSBackingStoreBuffered 
											  defer:NO];
	
	[_window setReleasedWhenClosed:NO];
	[_window setMovableByWindowBackground:NO];
	[_window setLevel:NSMainMenuWindowLevel];
	[_window setBackgroundColor:[NSColor clearColor]];
	[_window setHasShadow:NO];
	[_window setAlphaValue:0.7];
	[_window setOpaque:NO];
	[_window setIgnoresMouseEvents:YES];
	[[_window contentView] setWantsLayer:YES];

	// Set the content view	
	size = [_dragImage size];
		
	[[_window contentView] addSubview:_dragView];
	
	[_dragView setFrame:NSMakeRect((NSWidth(winRect) - size.width) / 2.0, (NSHeight(winRect) - size.height) / 2.0, size.width, size.height)];

	// Show the drag & drop window
	[_window setFrameOrigin:NSMakePoint(aPoint.x - winRect.size.width / 2.0, aPoint.y - winRect.size.height / 2.0)];
	[_window orderFront:self];
}

- (void)draggedImage:(NSImage *)draggedImage movedTo:(NSPoint)screenPoint
{
	NSPoint	pt = [NSEvent mouseLocation];
	NSRect	frame = [_window frame];
	NSRect	rect;
	
	NSView	*currentView = nil;
	NSView	*targetView = nil;
	NSSize	targetSize;
	
	NSView	*behindView;

	// Center window on cursor
	[_window setFrameOrigin:NSMakePoint(pt.x - frame.size.width / 2.0, pt.y - frame.size.height / 2.0)];

	// Search view behind the drag window
	behindView = [self searchViewAtPoint:pt];
	
	// Convert view
	if (behindView && [[self registeredDraggedTypes] firstObjectCommonWithArray:[behindView registeredDraggedTypes]] != nil)
	{		
		if (_dropMode == NO)
			return;
		
		_dropMode = NO;
		
		currentView = _dropView;
		targetView = _dragView;
		targetSize = [_dragImage size];
	}
	else
	{		
		if (_dropMode == YES)
			return;
		
		_dropMode = YES;

		currentView = _dragView;
		targetView = _dropView;
		targetSize = [_dropImage size];
	}
	
	// > Ignore or allow events, to allow feed-back on table view re-ordering
	[_window setIgnoresMouseEvents:(_dropMode == NO)];
	
	// > Compute target view
	rect = NSMakeRect((NSWidth(frame) - targetSize.width) / 2.0, (NSHeight(frame) - targetSize.height) / 2.0, targetSize.width, targetSize.height);

	[targetView setFrame:[currentView frame]];
	
	// > Change the view
	[NSAnimationContext beginGrouping];
	{
		[[NSAnimationContext currentContext] setDuration:0.2];
		
		[[[_window contentView] animator] replaceSubview:currentView with:targetView];
		[[targetView animator] setFrame:rect];
	}
	[NSAnimationContext endGrouping];
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	[_window close];
	_window = nil;
	
	_dragView = nil;
	_dragImage = nil;
	_dropView = nil;
	_dropImage = nil;
	_indexSet = nil;

	_dropMode = NO;
}



/*
** TCChatsTableView - Tools
*/
#pragma mark - TCChatsTableView - Tools

- (NSView *)searchViewAtPoint:(NSPoint)pt
{
	NSInteger	dragWid;
	NSInteger	targetWid;
	NSWindow	*twindow;
	NSView		*tview;
	
	dragWid = [_window windowNumber];
	
	// Search the window of this point
	targetWid = [NSWindow windowNumberAtPoint:pt belowWindowWithWindowNumber:0];
	
	if (targetWid == dragWid)
		targetWid = [NSWindow windowNumberAtPoint:pt belowWindowWithWindowNumber:dragWid];
	
	twindow = [[NSApplication sharedApplication] windowWithWindowNumber:targetWid];
	
	if (!twindow)
		return nil;
	
	// Search the view of this point
	tview = [[twindow contentView] hitTest:[twindow convertScreenToBase:pt]];
	
	return tview;
}

@end
