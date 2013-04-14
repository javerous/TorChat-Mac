/*
 *  TCChatPage.m
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



#import "TCChatPage.h"



/*
** TCChatPage
*/
#pragma mark -
#pragma mark TCChatPage

@implementation TCChatPage


/*
** TCChatPage - Overwrite
*/
#pragma mark -
#pragma mark TCChatPage - Overwrite

- (BOOL)isFlipped
{
	return YES;
}

- (void)setFrame:(NSRect)rect
{
	CGFloat delta = rect.size.width - self.frame.size.width;
	
	// Update items
	float	current_y = 0;
	NSArray	*views = self.subviews;
	
	for (NSView *view in views)
	{
		// Update size & origin
		NSRect r = [view frame];
		
		r.size.width += delta;
		r.origin.y = current_y;
		
		[view setFrame:r];
		
		// Update current y
		r = [view frame];		
		current_y += r.size.height;
	}
	
	// Update my size
	rect.size.height = current_y;
	[super setFrame:rect];
}

@end
