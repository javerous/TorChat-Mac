/*
 *  TCChatBubble.m
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import "TCChatBubble.h"

#import "NSString+TCExtension.h"



/*
** TCChatBubble - Private
*/
#pragma mark - TCChatBubble - Private

@interface TCChatBubble ()
{
    tcbubble_style	_style;
	NSTextField		*_field;
	NSFont			*_font;
}

- (NSRect)computeTextWithFrame:(NSRect)frame;

@end



/*
** TCChatBubble
*/
#pragma mark - TCChatBubble

@implementation TCChatBubble


/*
** TCChatBubble - Instance
*/
#pragma mark - TCChatBubble - Instance

+ (TCChatBubble *)bubbleWithText:(NSString *)_text andStyle:(tcbubble_style)_style
{
	TCChatBubble *result = [[TCChatBubble alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
	
	result->_style = _style;
	[result->_field setStringValue:_text];
	
	return result;
}

- (id)initWithFrame:(NSRect)frame
{
	self = [super initWithFrame:frame];
	
    if (self)
	{
		_font = [NSFont fontWithName:@"Helvetica" size:14];
		
		_field = [[NSTextField alloc] initWithFrame:frame];
		
		[_field setFont:_font];
		[_field setEditable:NO];
		[_field setSelectable:YES];
		[_field setBordered:NO];
		[_field setDrawsBackground:NO];
		
		[self addSubview:_field];
    }
    
    return self;
}



/*
** TCChatBubble - Draw
*/
#pragma mark - TCChatBubble - Draw

- (void)drawRect:(NSRect)dirtyRect
{
	// Blue Part
	static NSImage	*b_bl = nil;
	static NSImage	*b_bm = nil;
	static NSImage	*b_br = nil;
	
	static NSImage	*b_le = nil;
	static NSImage	*b_mi = nil;
	static NSImage	*b_ri = nil;
	
	static NSImage	*b_tl = nil;
	static NSImage	*b_tm = nil;
	static NSImage	*b_tr = nil;
		
	// Gray part
	static NSImage	*g_bl = nil;
	static NSImage	*g_bm = nil;
	static NSImage	*g_br = nil;
	
	static NSImage	*g_le = nil;
	static NSImage	*g_mi = nil;
	static NSImage	*g_ri = nil;
	
	static NSImage	*g_tl = nil;
	static NSImage	*g_tm = nil;
	static NSImage	*g_tr = nil;
	
	// Final part
	NSImage	*bl = nil;
	NSImage	*bm = nil;
	NSImage	*br = nil;
	
	NSImage	*le = nil;
	NSImage	*mi = nil;
	NSImage	*ri = nil;
	
	NSImage	*tl = nil;
	NSImage	*tm = nil;
	NSImage	*tr = nil;
	

	// Alloc bubble image part
	switch (_style)
	{
		case tcbubble_blue:
		{
			static dispatch_once_t onceToken;
			
			dispatch_once(&onceToken, ^{
				b_tl = [NSImage imageNamed: @"chat_bluebubble_topleft.png"];
				b_tr = [NSImage imageNamed: @"chat_bluebubble_topright.png"];
				b_bl = [NSImage imageNamed: @"chat_bluebubble_bottomleft.png"];
				b_br = [NSImage imageNamed: @"chat_bluebubble_bottomright.png"];
				b_mi = [NSImage imageNamed: @"chat_bluebubble_middle.png"];
				b_tm = [NSImage imageNamed: @"chat_bluebubble_topmiddle.png"];
				b_bm = [NSImage imageNamed: @"chat_bluebubble_bottommiddle.png"];
				b_le = [NSImage imageNamed: @"chat_bluebubble_left.png"];
				b_ri = [NSImage imageNamed: @"chat_bluebubble_right.png"];
			});
			
			bl = b_bl;
			bm = b_bm;
			br = b_br;
			
			le = b_le;
			mi = b_mi;
			ri = b_ri;
			
			tl = b_tl;
			tm = b_tm;
			tr = b_tr;
			
			break;
		}
			
		case tcbubble_gray:
		{
			
			static dispatch_once_t onceToken;
			
			dispatch_once(&onceToken, ^{
				g_tl = [NSImage imageNamed: @"chat_graybubble_topleft.png"];
				g_tr = [NSImage imageNamed: @"chat_graybubble_topright.png"];
				g_bl = [NSImage imageNamed: @"chat_graybubble_bottomleft.png"];
				g_br = [NSImage imageNamed: @"chat_graybubble_bottomright.png"];
				g_mi = [NSImage imageNamed: @"chat_graybubble_middle.png"];
				g_tm = [NSImage imageNamed: @"chat_graybubble_topmiddle.png"];
				g_bm = [NSImage imageNamed: @"chat_graybubble_bottommiddle.png"];
				g_le = [NSImage imageNamed: @"chat_graybubble_left.png"];
				g_ri = [NSImage imageNamed: @"chat_graybubble_right.png"];
			});
			
			bl = g_bl;
			bm = g_bm;
			br = g_br;
			
			le = g_le;
			mi = g_mi;
			ri = g_ri;
			
			tl = g_tl;
			tm = g_tm;
			tr = g_tr;
			
			break;
		}
	}
	
	// Obtain size
	NSSize sbl = [bl size];
	NSSize sbm = [bm size];
	NSSize sbr = [br size];
	
	NSSize sle = [le size];
	//NSSize smi = [mi size];
	NSSize sri = [ri size];
	
	NSSize stl = [tl size];
	NSSize stm = [tm size];
	NSSize str = [tr size];
	
	NSSize sme = [self frame].size;
	
	
	// Compute size & position
	NSRect rbl = NSMakeRect(0, 0, sbl.width, sbl.height);
	NSRect rbm = NSMakeRect(sbl.width, 0, sme.width - (sbl.width + sbr.width), sbm.height);
	NSRect rbr = NSMakeRect(sme.width - sbr.width, 0, sbr.width, sbr.height);
	
	NSRect rle = NSMakeRect(0, sbl.height, sle.width, sme.height - (sbl.height + stl.height));
	NSRect rmi = NSMakeRect(sle.width, sbm.height, sme.width - (sbl.width + sbr.width), sme.height - (sbl.height + stl.height));
	NSRect rri = NSMakeRect(sme.width - sri.width, sbr.height, sri.width, sme.height - (sbl.height + stl.height));
	
	NSRect rtl = NSMakeRect(0, sme.height - stl.height, stl.width, stl.height);
	NSRect rtm = NSMakeRect(stl.width, sme.height - stm.height, sme.width - (sbl.width + sbr.width), stm.height);
	NSRect rtr = NSMakeRect(sme.width - str.width, sme.height - str.height, str.width, str.height);

	
	// Draw parts
	[bl drawInRect:rbl fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[bm drawInRect:rbm fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[br drawInRect:rbr fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	[le drawInRect:rle fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[mi drawInRect:rmi fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[ri drawInRect:rri fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	
	[tl drawInRect:rtl fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[tm drawInRect:rtm fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	[tr drawInRect:rtr fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
}



/*
** TCChatBubble - Tools
*/
#pragma mark - TCChatBubble - Tools

- (NSRect)computeTextWithFrame:(NSRect)frame
{
	CGFloat	height = [_field.stringValue heightForDrawingWithFont:_font andWidth:(frame.size.width - 30.0f - 4.0f)];
	
	return NSMakeRect(15, 10, frame.size.width - 30, height);
}



/*
** TCChatBubble - Overwrite
*/
#pragma mark - TCChatBubble - Overwrite

- (void)setFrame:(NSRect)rect
{
	NSRect txtRect = [self computeTextWithFrame:rect];

	[_field setFrame:txtRect];
	[super setFrame:NSMakeRect(rect.origin.x, rect.origin.y, rect.size.width, txtRect.size.height + 21)];
}

@end


