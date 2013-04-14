/*
 *  TCChatsTableView.m
 *
 *  Copyright 2012 Avérous Julien-Pierre
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

@property (assign, nonatomic) id <TCChatsTableViewDropDelegate> dropDelegate;
@property (assign, nonatomic) TCChatsTableView					*tableView;
@property (assign, nonatomic) NSUInteger						dropRow;

@end

@implementation TCDropView

@synthesize dropDelegate;
@synthesize tableView;
@synthesize dropRow;

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

	[self.dropDelegate tableView:self.tableView droppedRow:self.dropRow toFrame:frame];

	return YES;
}

@end



/*
** TCChatsTableView ()
*/
#pragma mark - TCChatsTableView ()

@interface TCChatsTableView ()
{
	NSWindow	*window;
	
	NSImage		*dragImage;
	NSImage		*dropImage;
	
	TCDropView	*dropView;
	NSImageView	*dragView;
	
	BOOL		dropMode;
	
	NSIndexSet	*indexSet;
}

- (NSView *)searchViewAtPoint:(NSPoint)pt;

@end



/*
** TCChatsTableView
*/
#pragma mark - TCChatsTableView

@implementation TCChatsTableView


/*
** TCChatsTableView - Property
*/
#pragma mark - TCChatsTableView - Property

@synthesize dropDelegate;



/*
** TCChatsTableView - Drag & Drop
*/
#pragma mark - TCChatsTableView - Drag & Drop

- (NSImage *)dragImageForRowsWithIndexes:(NSIndexSet *)dragRows tableColumns:(NSArray *)tableColumns event:(NSEvent *)dragEvent offset:(NSPointPointer)dragImageOffset
{
	// FIXME: use dragImageOffset for drags
	
	// Store the drag image
	[dragImage release];
	dragImage = [[super dragImageForRowsWithIndexes:dragRows tableColumns:tableColumns event:dragEvent offset:dragImageOffset] retain];
	
	// Hold indexes
	[indexSet release];
	indexSet = [dragRows retain];
	
	// Show an empty one
	return [[[NSImage alloc] initWithSize:NSMakeSize(1, 1)] autorelease];
}

- (void)draggedImage:(NSImage *)anImage beganAt:(NSPoint)aPoint
{
	NSRect		winRect;
	NSSize		size;
	NSUInteger	drow;
	
	drow = [indexSet firstIndex];
	
	// Configure views
	// > Drag View
	[dragView release];
	dragView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, [dragImage size].width, [dragImage size].height)];
	[dragView setImageScaling:NSScaleToFit];
	[dragView setImage:dragImage];
	
	// > Drop View
	[dropView release];
	dropView = [[TCDropView alloc] initWithFrame:NSMakeRect(0, 0, [dropImage size].width, [dropImage size].height)];
	[dropView setImageScaling:NSScaleToFit];
	
	[dropImage release];
	dropImage = [[dropDelegate tableView:self dropImageForRow:drow] retain];

	[dropView setImage:dropImage];
	dropView.dropDelegate = dropDelegate;
	dropView.tableView = self;
	dropView.dropRow = drow;
	
	[dropView registerForDraggedTypes:[self registeredDraggedTypes]];

	// Compute window size
	winRect = NSMakeRect(0, 0, fmax([dropImage size].width, [dragImage size].width), fmax([dropImage size].height, [dragImage size].height));
		
	// Create the drop window
	window = [[NSWindow alloc] initWithContentRect:winRect 
										  styleMask:NSBorderlessWindowMask 
											backing:NSBackingStoreBuffered 
											  defer:NO];
	
	[window setReleasedWhenClosed:NO];
	[window setMovableByWindowBackground:NO];
	[window setLevel:NSMainMenuWindowLevel];
	[window setBackgroundColor:[NSColor clearColor]];
	[window setHasShadow:NO];
	[window setAlphaValue:0.7];
	[window setOpaque:NO];
	[window setIgnoresMouseEvents:YES];
	[[window contentView] setWantsLayer:YES];

	// Set the content view	
	size = [dragImage size];
		
	[[window contentView] addSubview:dragView];
	
	[dragView setFrame:NSMakeRect((NSWidth(winRect) - size.width) / 2.0, (NSHeight(winRect) - size.height) / 2.0, size.width, size.height)];

	// Show the drag & drop window
	[window setFrameOrigin:NSMakePoint(aPoint.x - winRect.size.width / 2.0, aPoint.y - winRect.size.height / 2.0)];
	[window orderFront:self];
}

- (void)draggedImage:(NSImage *)draggedImage movedTo:(NSPoint)screenPoint
{
	NSPoint	pt = [NSEvent mouseLocation];
	NSRect	frame = [window frame];
	NSRect	rect;
	
	NSView	*currentView = nil;
	NSView	*targetView = nil;
	NSSize	targetSize;
	
	NSView	*behindView;

	// Center window on cursor
	[window setFrameOrigin:NSMakePoint(pt.x - frame.size.width / 2.0, pt.y - frame.size.height / 2.0)];

	// Search view behind the drag window
	behindView = [self searchViewAtPoint:pt];
	
	// Convert view
	if (behindView && [[self registeredDraggedTypes] firstObjectCommonWithArray:[behindView registeredDraggedTypes]] != nil)
	{		
		if (dropMode == NO)
			return;
		
		dropMode = NO;
		
		currentView = dropView;
		targetView = dragView;
		targetSize = [dragImage size];
	}
	else
	{		
		if (dropMode == YES)
			return;
		
		dropMode = YES;

		currentView = dragView;
		targetView = dropView;
		targetSize = [dropImage size];
	}
	
	// > Ignore or allow events, to allow feed-back on table view re-ordering
	[window setIgnoresMouseEvents:(dropMode == NO)];
	
	// > Compute target view
	rect = NSMakeRect((NSWidth(frame) - targetSize.width) / 2.0, (NSHeight(frame) - targetSize.height) / 2.0, targetSize.width, targetSize.height);

	[targetView setFrame:[currentView frame]];
	
	// > Change the view
	[NSAnimationContext beginGrouping];
	{
		[[NSAnimationContext currentContext] setDuration:0.2];
		
		[[[window contentView] animator] replaceSubview:currentView with:targetView];
		[[targetView animator] setFrame:rect];
	}
	[NSAnimationContext endGrouping];
}

- (void)draggedImage:(NSImage *)anImage endedAt:(NSPoint)aPoint operation:(NSDragOperation)operation
{
	[window close];
	[window release];
	window = nil;
	
	[dragView release];
	dragView = nil;
	
	[dragImage release];
	dragImage = nil;
	
	[dropView release];
	dropView = nil;
	
	[dropImage release];
	dropImage = nil;
	
	[indexSet release];
	indexSet = nil;
	
	dropMode = NO;
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
	
	dragWid = [window windowNumber];
	
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
