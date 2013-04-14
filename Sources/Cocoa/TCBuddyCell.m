/*
 *  TCBuddyCell.m
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



#import "TCBuddyCell.h"



/*
** TCBuddyCell
*/
#pragma mark -
#pragma mark TCBuddyCell

@implementation TCBuddyCell


/*
** TCBuddyCell - Instance
*/
#pragma mark -
#pragma mark TCBuddyCell - Instance

- (id)initWithCoder:(NSCoder *)decoder
{
	if ((self = [super initWithCoder:decoder]))
	{
	}
	
	return self;
}

- (id)initImageCell:(NSImage *)anImage
{
	if ((self = [super initImageCell:nil]))
	{
	}
	
	return self;
}

- (id)initTextCell:(NSString *)aString
{
	if ((self = [super initTextCell:@""]))
	{
	}
	
	return self;
}


- (id)init
{
    if ((self = [super init]))
	{
    }
    
    return self;
}

- (void)dealloc
{
    
    [super dealloc];
}



/*
** TCBuddyCell - Draw
*/
#pragma mark -
#pragma mark TCBuddyCell - Draw

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{

	NSDictionary *content = [self objectValue];
	
	if ([content isKindOfClass:[NSDictionary class]] == NO)
		return;
	
	NSString	*alias = [content objectForKey:TCBuddyCellAliasKey];
	NSString	*pname = [content objectForKey:TCBuddyCellProfileNameKey];
	NSString	*address = [content objectForKey:TCBuddyCellAddressKey];
	NSColor		*txtColor = nil;
		
	// -- Draw name --
	if ([self isHighlighted])
		txtColor = [NSColor whiteColor];
	else
		txtColor = [NSColor blackColor];
	
	
	
	NSDictionary	*nmAttribute = [NSDictionary dictionaryWithObjectsAndKeys:	[NSFont systemFontOfSize:12],	NSFontAttributeName,
																				txtColor,						NSForegroundColorAttributeName,
																				nil];
	
	[alias drawAtPoint:NSMakePoint(cellFrame.origin.x + 2, cellFrame.origin.y + 3) withAttributes:nmAttribute];

	
	// -- Draw address --
	if ([self isHighlighted])
		txtColor = [NSColor whiteColor];
	else
		txtColor = [NSColor grayColor];
	
	NSString		*sub;
	NSDictionary	*stAttribute = [NSDictionary dictionaryWithObjectsAndKeys:	[NSFont fontWithName:@"Arial" size:11],	NSFontAttributeName,
																				txtColor,								NSForegroundColorAttributeName,
																				nil];
	
	if ([pname length] > 0)
		sub = [NSString stringWithFormat:@"%@ (\"%@\")", address, pname];
	else
		sub = address;
	
	[sub drawAtPoint:NSMakePoint(cellFrame.origin.x + 2, cellFrame.origin.y + 19) withAttributes:stAttribute];
}

@end
