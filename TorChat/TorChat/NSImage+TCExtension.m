/*
 *  NSImage+TCExtension.m
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



#import "NSImage+TCExtension.h"



/*
** NSImage + TCExtension
*/
#pragma mark - NSImage + TCExtension

@implementation NSImage (TCExtension)

- (NSImage *)flipHorizontally
{
    NSSize	size = self.size;
    NSImage	*result = [NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect dstRect) {
		
		NSAffineTransform *translate = [NSAffineTransform transform];
		
		[translate translateXBy:size.width yBy:0];
		[translate scaleXBy:-1 yBy:1];
		[translate concat];
		
		[self drawAtPoint:NSZeroPoint fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		
		return YES;
	}];
	
    return result;
}

@end
