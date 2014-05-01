/*
 *  TCChatTextField.m
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



#import "TCChatTextField.h"

#import "NSString+TCExtension.h"



/*
** TCChatTextField
*/
#pragma mark - TCChatTextField

@implementation TCChatTextField

- (void)awakeFromNib
{
	[self setPreferredMaxLayoutWidth:(self.frame.size.width - 8.0)];
}

- (void)setFrame:(NSRect)frameRect
{
	[super setFrame:frameRect];
	
	[self setPreferredMaxLayoutWidth:(frameRect.size.width - 8.0)];
}

- (NSSize)intrinsicContentSize
{
	// We have to overwrite this method because preferredMaxLayoutWidth doesn't work on editable NSTextField.
	// We dont use [self.cell cellSizeForBounds:] because this method doesn't handle text content when editing.

	NSString *text = [self stringValue];
	
	if ([text length] == 0)
		text = @" ";
	
	NSFont	*font = [self font];
	CGFloat	width = [self preferredMaxLayoutWidth];
	CGFloat	height = [text heightForDrawingWithFont:font andWidth:width];
	
	return NSMakeSize(width, height);
}

- (void)textDidChange:(NSNotification *)aNotification
{
	// We have to invalidate intrinsic content size on text change, because system compute it only on sendAction.

	[self invalidateIntrinsicContentSize];
}

@end
