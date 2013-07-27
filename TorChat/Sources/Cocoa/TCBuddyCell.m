/*
 *  TCBuddyCell.m
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



#import "TCBuddyCell.h"



/*
** TCBuddyCell
*/
#pragma mark - TCBuddyCell

@implementation TCBuddyCell


/*
** TCBuddyCell - Instance
*/
#pragma mark - TCBuddyCell - Instance

- (id)initImageCell:(NSImage *)anImage
{
	self = [super initImageCell:nil];
	
	if (self)
	{
	}
	
	return self;
}

- (id)initTextCell:(NSString *)aString
{
	self = [super initTextCell:@""];
	
	if (self)
	{
	}
	
	return self;
}



/*
** TCBuddyCell - Draw
*/
#pragma mark - TCBuddyCell - Draw

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	NSDictionary *content = [self objectValue];
	
	if ([content isKindOfClass:[NSDictionary class]] == NO)
		return;
	
	NSString	*pname = [content objectForKey:TCBuddyCellNameKey];
	NSString	*address = [content objectForKey:TCBuddyCellAddressKey];
	NSColor		*txtColor = nil;
	float		dy = 3.0;
		
	// -- Draw name --
	if ([pname length] > 0)
	{
		if ([self isHighlighted])
			txtColor = [NSColor whiteColor];
		else
			txtColor = [NSColor blackColor];
		
		NSRect					r;
		NSMutableParagraphStyle	*paragraphStyle = [[NSMutableParagraphStyle alloc] init];		
		NSDictionary			*nmAttribute = [NSDictionary dictionaryWithObjectsAndKeys:	[NSFont systemFontOfSize:12],	NSFontAttributeName,
																							txtColor,						NSForegroundColorAttributeName,
																							paragraphStyle,					NSParagraphStyleAttributeName,
																							nil];

		[paragraphStyle setLineBreakMode:NSLineBreakByTruncatingTail];
		
		r = NSMakeRect(cellFrame.origin.x + 2, cellFrame.origin.y + dy, cellFrame.size.width - 4, cellFrame.size.height);

		[pname drawInRect:r withAttributes:nmAttribute];
				
		dy += 19.0;
	}
	else
		dy += 9.0;
	
	// -- Draw address --
	if ([self isHighlighted])
		txtColor = [NSColor whiteColor];
	else
		txtColor = [NSColor grayColor];
	
	NSDictionary	*stAttribute = [NSDictionary dictionaryWithObjectsAndKeys:	[NSFont fontWithName:@"Arial" size:11],	NSFontAttributeName,
																				txtColor,								NSForegroundColorAttributeName,
																				nil];
	
	[address drawAtPoint:NSMakePoint(cellFrame.origin.x + 2, cellFrame.origin.y + dy) withAttributes:stAttribute];
}

@end
