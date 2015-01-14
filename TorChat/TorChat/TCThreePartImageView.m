/*
 *  TCThreePartImageView.m
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



#import "TCThreePartImageView.h"



/*
** TCThreePartImageView
*/
#pragma mark - TCThreePartImageView

@implementation TCThreePartImageView


/*
** TCThreePartImageView - Draw
*/
#pragma mark - TCThreePartImageView - Draw

- (void)drawRect:(NSRect)dirtyRect
{
	[super drawRect:dirtyRect];
	
	NSImage *startCap = _startCap;
	NSImage *centerFill = _centerFill;
	NSImage *endCap = _endCap;

	
	if (!startCap || !centerFill || !endCap)
		return;
	
	NSSize size = self.frame.size;
	
	NSDrawThreePartImage(NSMakeRect(0, 0, size.width, size.height), startCap, centerFill, endCap, _vertical, NSCompositeSourceOver, 1.0, self.isFlipped);
}

@end
