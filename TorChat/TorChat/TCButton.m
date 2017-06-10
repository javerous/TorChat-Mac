/*
 *  TCButton.m
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

#import "TCButton.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCButtonContext
*/
#pragma mark - TCButtonContext

@interface TCButtonContext : NSObject

@property (assign, nonatomic) BOOL isOver;
@property (assign, nonatomic) BOOL isPushed;

@end

@implementation TCButtonContext

@end



/*
** TCButton
*/
#pragma mark - TCButton

@implementation TCButton
{
	id _monitor;
}


/*
** TCButton - Instance
*/
#pragma mark - TCButton - Instance

- (void)dealloc
{
	[NSEvent removeMonitor:_monitor];
}



/*
** TCButton - NSView
*/
#pragma mark - TCButton - OverWrite

- (void)drawRect:(NSRect)dirtyRect
{
	if (_actionHandler == nil)
	{
		[_image drawInRect:self.bounds];
		return;
	}
	
	if (_context.isOver)
	{
		if (_context.isPushed)
			[_pushImage drawInRect:self.bounds];
		else
		{
			if (_overImage)
				[_overImage drawInRect:self.bounds];
			else
				[_image drawInRect:self.bounds];
		}
	}
	else
		[_image drawInRect:self.bounds];
}

- (void)viewDidMoveToWindow
{
	[super viewDidMoveToWindow];

	if (self.window)
	{
		if (!_context)
			_context = [TCButton createEmptyContext];
		
		if (!_monitor)
			[self monitorEvents];
		
		[self setNeedsDisplay:YES];
	}
	else
	{
		if (_monitor)
		{
			[NSEvent removeMonitor:_monitor];
			_monitor = nil;
		}
	}
}



/*
** TCButton - Context
*/
#pragma mark - TCButton - Context

+ (TCButtonContext *)createEmptyContext
{
	return [[TCButtonContext alloc] init];
}

- (void)setContext:(TCButtonContext *)context
{
	_context = context;
	
	[self setNeedsLayout:YES];
}



/*
** TCButton - Content
*/
#pragma mark - TCButton - Content

- (void)setImage:(NSImage *)img
{
	_image = img;
	[self setNeedsDisplay:YES];
}

- (void)setOverImage:(NSImage *)img
{
	_overImage = img;
	[self setNeedsDisplay:YES];
	[self monitorEvents];
}

- (void)setPushImage:(NSImage *)img
{
	_pushImage = img;
	[self setNeedsDisplay:YES];
}




/*
** TCButton - Tools
*/
#pragma mark - TCButton - Tools

- (void)monitorEvents
{
	__weak TCButton *weakButton = self;
	NSEventMask		mask = NSLeftMouseDownMask | NSLeftMouseUpMask |  NSLeftMouseDraggedMask;
	
	if (_overImage)
		mask |= NSMouseMovedMask;
	
	if (_monitor)
		[NSEvent removeMonitor:_monitor];
	
	_monitor = [NSEvent addLocalMonitorForEventsMatchingMask:mask handler:^NSEvent * _Nullable(NSEvent * _Nonnull event) {
		
		if ([weakButton handleEvent:event])
			return nil;
		
		return event;
	}];
}

- (BOOL)handleEvent:(NSEvent *)event
{
	if (self.window == nil || self.window.keyWindow == NO)
		return NO;
	
	NSPoint windowMouseLocation = self.window.mouseLocationOutsideOfEventStream;
	NSPoint mouseLocation = [self convertPoint:windowMouseLocation fromView:nil];
	BOOL	isOver = NSPointInRect(mouseLocation, self.bounds);

	BOOL needUpdate = NO;
	BOOL captureEvent = NO;

	if (isOver != _context.isOver)
	{
		needUpdate = YES;
		_context.isOver = isOver;
	}

	switch (event.type)
	{
		case NSLeftMouseDown:
		{
			if (_context.isOver)
			{
				if (_context.isPushed == NO)
				{
					_context.isPushed = YES;
					needUpdate = YES;
				}
				
				captureEvent = YES;
			}
			
			break;
		}
			
		case NSLeftMouseUp:
		{
			if (_context.isOver && _context.isPushed)
			{
				void (^actionHandler)(TCButton *) = self.actionHandler;
				
				if (actionHandler)
					actionHandler(self);
			}
			
			if (_context.isPushed == YES)
			{
				_context.isPushed = NO;
				needUpdate = YES;
			}
			
			break;
		}
			
		case NSLeftMouseDragged:
		{
			if (_context.isPushed == NO)
			{
				_context.isOver = NO;
				needUpdate = YES;
			}

			break;
		}
			
		case NSMouseMoved:
		{
			break;
		}
			
		default:
			return NO;
	}
	
	if (needUpdate)
		[self setNeedsDisplay:YES];
	
	return captureEvent;
}

@end


NS_ASSUME_NONNULL_END
