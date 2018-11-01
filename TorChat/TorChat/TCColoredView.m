/*
 *  TCColoredView.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCColoredView.h"


/*
** TCColoredView
*/
#pragma mark - TCColoredView


/*
** TCColoredView
*/
#pragma mark - TCColoredView

@implementation TCColoredView

- (void)drawRect:(NSRect)dirtyRect
{
    [super drawRect:dirtyRect];
	
	[_color set];
	
	[[NSBezierPath bezierPathWithRect:dirtyRect] fill];
}

- (void)setColor:(NSColor *)color
{
	_color = color;
	[self setNeedsDisplay:YES];
}

@end
