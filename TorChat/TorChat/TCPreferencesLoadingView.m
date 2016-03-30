/*
 *  TCPreferencesLoadingView.m
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

#import "TCPreferencesLoadingView.h"


/*
** TCPreferencesLoadingView
*/
#pragma mark - TCPreferencesLoadingView

@implementation TCPreferencesLoadingView
{
	IBOutlet NSProgressIndicator *progressView;
}


/*
** TCPreferencesLoadingView - NSView
*/
#pragma mark - TCPreferencesLoadingView - NSView

- (void)viewDidMoveToSuperview
{
	if (self.superview)
		[progressView startAnimation:nil];
	else
		[progressView stopAnimation:nil];
}

- (void)drawRect:(NSRect)dirtyRect
{
	NSBezierPath *frm = [NSBezierPath bezierPathWithRect:self.bounds];
	
	// Set the back color
	[[NSColor colorWithCalibratedWhite:1.0 alpha:0.7f] set];
	[frm fill];
}



/*
** TCPreferencesLoadingView - NSResponder
*/
#pragma mark - TCPreferencesLoadingView - NSResponder

- (void)mouseDown:(NSEvent *)theEvent
{
}

- (void)mouseDragged:(NSEvent *)theEvent
{
}

- (void)mouseUp:(NSEvent *)theEvent
{
}

- (void)mouseMoved:(NSEvent *)theEvent
{
}

- (void)mouseEntered:(NSEvent *)theEvent
{
}

- (void)mouseExited:(NSEvent *)theEvent
{
}

- (void)rightMouseDown:(NSEvent *)theEvent
{
}

- (void)rightMouseDragged:(NSEvent *)theEvent
{
}

- (void)rightMouseUp:(NSEvent *)theEvent
{
}

- (void)otherMouseDown:(NSEvent *)theEvent
{
}

- (void)otherMouseDragged:(NSEvent *)theEvent
{
}

- (void)otherMouseUp:(NSEvent *)theEvent
{
}

- (void)keyDown:(NSEvent *)theEvent
{
}

- (void)keyUp:(NSEvent *)theEvent
{
}

@end
