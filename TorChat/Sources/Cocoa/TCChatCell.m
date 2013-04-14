/*
 *  TCChatCell.m
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



#import "TCChatCell.h"


/*
** TCChatCell
*/
#pragma mark - TCChatCell

@implementation TCChatCell


/*
** TCChatCell - Instance
*/
#pragma mark - TCChatCell - Instance

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
** TCChatCell - Draw
*/
#pragma mark - TCChatCell - Draw

- (void)drawInteriorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	static NSImage			*lb, *cb, *rb;
	static dispatch_once_t	onceToken;
	
	NSDictionary	*content = [self objectValue];
	NSPoint			org = cellFrame.origin;
	NSSize			sz = cellFrame.size;
	
	if ([content isKindOfClass:[NSDictionary class]] == NO)
		return;
	
	// -- Once load --
	dispatch_once(&onceToken, ^{
		
		lb = [[NSImage imageNamed:@"balloon_left.png"] retain];
		cb = [[NSImage imageNamed:@"balloon_center.png"] retain];
		rb = [[NSImage imageNamed:@"balloon_rigth.png"] retain];
	});
	
	// -- Over --
	NSNumber *over = [content objectForKey:TCChatCellMouseOverKey];
	
	if ([over boolValue] && ![self isHighlighted])
	{
		[NSGraphicsContext saveGraphicsState];
		{
			NSRect line;

			// > Back
			[[NSColor colorWithCalibratedRed:(204.0 / 255.0) green:(209.0 / 255.0) blue:(217.0 / 255.0) alpha:1.0] set];
			
			line = NSMakeRect(0, cellFrame.origin.y, [controlView frame].size.width, cellFrame.size.height);
			[[NSBezierPath bezierPathWithRect:line] fill];
			
			// > Top + bottom
			[[NSColor colorWithCalibratedRed:(188.0 / 255.0) green:(193.0 / 255.0) blue:(200.0 / 255.0) alpha:1.0] set];
			
			line = NSMakeRect(0, cellFrame.origin.y - 1, [controlView frame].size.width, 1);
			[[NSBezierPath bezierPathWithRect:line] fill];
			
			line = NSMakeRect(0, cellFrame.origin.y + cellFrame.size.height, [controlView frame].size.width, 1);
			[[NSBezierPath bezierPathWithRect:line] fill];
		}
		[NSGraphicsContext restoreGraphicsState];
	}
	
	// -- Accessory --
	NSView *accessory = [content objectForKey:TCChatCellAccessoryKey];
	
	if (accessory)
	{
		NSSize asize = [accessory frame].size;

		[accessory setFrame:NSMakeRect(sz.width - asize.width, org.y + (sz.height - asize.height) / 2.0, asize.width, asize.height)];
		
		sz.width -= asize.width;
	}
	
	
	// -- Avatar --
	NSImage *avatar = [content objectForKey:TCChatCellAvatarKey];
	
	if (!avatar)
		avatar = [NSImage imageNamed:NSImageNameUser];
	
	[avatar setSize:NSMakeSize(28, 28)];

	[avatar drawInRect:NSMakeRect(org.x + 5, org.y + 3, 28, 28) fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];

	
	// -- Name --
	NSString				*name = [content objectForKey:TCChatCellNameKey];
	NSString				*text = [content objectForKey:TCChatCellChatTextKey];
	NSDictionary			*attributes;
	NSMutableParagraphStyle *truncateStyle = [[[NSMutableParagraphStyle alloc] init] autorelease];
	CGFloat					dy = 3;
	NSColor					*fontColor;
	NSShadow				*shadow = nil;
	
	// > Set break mode
	[truncateStyle setLineBreakMode:NSLineBreakByTruncatingTail];

	// > Set delta drawing
	if (text)
		dy = 0;
	else
		dy = 8;
	
	// > Set color & shadow
	if ([self isHighlighted])
	{
		NSSize	shadowOffset = { .width = 1.0, .height = -1.5};
		
		// > Build & set shadow
		shadow = [[NSShadow alloc] init];

		[shadow setShadowOffset:shadowOffset];
		[shadow setShadowColor:[NSColor colorWithDeviceRed:(127.0/255.0) green:(140.0/255.0) blue:(160.0/255.0) alpha:1.0]];
		
		fontColor = [NSColor whiteColor];
	}
	else
	{
		fontColor = [NSColor blackColor];
	}
	
	// > Build attribute
	attributes = [NSDictionary dictionaryWithObjectsAndKeys:
				  [NSFont systemFontOfSize:12], NSFontAttributeName,
				  fontColor,					NSForegroundColorAttributeName,
				  truncateStyle,				NSParagraphStyleAttributeName,
				  nil];
	
	// > Draw name
	[NSGraphicsContext saveGraphicsState];
	{
		[shadow set];	
		[name drawInRect:NSMakeRect(org.x + 42, org.y + dy, sz.width - org.x - 50, 20) withAttributes:attributes];
	}
	[NSGraphicsContext restoreGraphicsState];
	
	// > Clean
	[shadow release];
	
	// -- Last unread message --
	if (text)
	{
		NSSize	slb = [lb size];
		NSSize	scb = [cb size];
		NSSize	srb = [rb size];
		NSRect	rlb;
		NSRect	rcb;
		NSRect	rrb;
		NSRect	rtxt;
		
		NSSize	stxt;
		
		// > Build attributes
		attributes = [NSDictionary dictionaryWithObjectsAndKeys:
					  [NSFont systemFontOfSize:10], NSFontAttributeName,
					  [NSColor blackColor],			NSForegroundColorAttributeName,
					  truncateStyle,				NSParagraphStyleAttributeName,
					  nil];
		
		// > Compute nominal text size
		stxt = [text sizeWithAttributes:attributes];
		
		stxt.width = ceil(stxt.width);
		stxt.height = ceil(stxt.height);
		
		dy = 15;
				
		// > Compute rects
		rlb = NSMakeRect(28 + org.x, dy + org.y, slb.width, slb.height);
		rcb = NSMakeRect(28 + org.x + slb.width, dy + org.y, stxt.width, scb.height);
		rrb = NSMakeRect(28 + org.x + slb.width + stxt.width, dy + org.y, srb.width, srb.height);
		rtxt = NSMakeRect(27 + org.x + slb.width, dy + org.y + 2, stxt.width, stxt.height);
		
		// > Check size & recompute
		if (rrb.origin.x + rrb.size.width > org.x + sz.width)
		{
			CGFloat dw = (rrb.origin.x + rrb.size.width) - (org.x + sz.width);
			
			rcb = NSMakeRect(28 + org.x + slb.width, dy + org.y, stxt.width - dw, scb.height);
			rrb = NSMakeRect(28 + org.x + slb.width + stxt.width - dw, dy + org.y, srb.width, srb.height);
			rtxt = NSMakeRect(27 + org.x + slb.width, dy + org.y + 2, stxt.width - dw, stxt.height);
		}
		
		if (rcb.size.width >= 2)
		{
			[lb drawInRect:rlb fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
			[cb drawInRect:rcb fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
			[rb drawInRect:rrb fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];		
	
			[text drawInRect:rtxt withAttributes:attributes];
		}
	}
}

@end
