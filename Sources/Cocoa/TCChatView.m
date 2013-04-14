/*
 *  TCChatView.m
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#import "TCChatView.h"

#import "TCChatBubble.h"
#import "TCChatPage.h"



/*
** TCChatView - Private
*/
#pragma mark -
#pragma mark TCChatView - Private

@interface TCChatView ()

- (void)scrollToEnd;

@end



/*
** TCChatView
*/
#pragma mark -
#pragma mark TCChatView

@implementation TCChatView


/*
** TCChatView - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCChatView - Constructor & Destructor

- (void)awakeFromNib
{
	NSSize sz = [self bounds].size;
	
	contentView = [[TCChatPage alloc] initWithFrame:NSMakeRect(0, 0, sz.width - 2, 0)];
	[contentView setAutoresizingMask: NSViewWidthSizable];
	
	event_font = [[NSFont fontWithName:@"Helvetica" size:12] retain];
	last_stamp = nil;
	
	[self setDocumentView:contentView];
}

- (void)dealloc
{
	[contentView release];
	[last_stamp release];
	[event_font release];
		
    [super dealloc];
}



/*
** TCChatView - Actions
*/
#pragma mark -
#pragma mark TCChatView - Actions

- (void)addTimeStamp
{
	float	stamp_height = 20.0f;
	NSRect	r = [contentView frame];
	
	if (last_stamp == nil)
		last_stamp = [[NSDate alloc] initWithTimeIntervalSinceNow: -100000];
	
	if ([last_stamp timeIntervalSinceNow] < -(60.0 * 5.0))
	{
		NSRect	new_area = NSMakeRect(0, r.size.height, r.size.width, stamp_height);
		NSColor	*color = [NSColor colorWithDeviceRed:0.47 green:0.47 blue:0.47 alpha:1.0];
		
		// Current date
		[last_stamp release];
		last_stamp = [[NSDate alloc] init];
		
		NSDateFormatter *format = [[[NSDateFormatter alloc] init] autorelease];
		
		[format setDateFormat:@"HH:mm:ss"];
				
		// Build the stamp
		NSString		*label = [format stringFromDate:last_stamp];
		NSTextField		*stamp = [[NSTextField alloc] initWithFrame:new_area];
		
		[stamp setFont:event_font];
		[stamp setEditable:NO];
		[stamp setSelectable:YES];
		[stamp setBordered:NO];
		[stamp setDrawsBackground:NO];

		[stamp setAlignment:NSCenterTextAlignment];
		[stamp setTextColor:color];
		
		[stamp setStringValue:label];
		
		
		// Add it to the view
		[contentView addSubview:stamp];
		
		// Refresh the current position
		r.size.height += stamp_height;
		[contentView setFrame:r];
		
		// Scroll to end
		[self scrollToEnd];
		
		// Clean
		[stamp release];
	}
}

- (void)addStatusMessage:(NSString *)msg fromUserName:(NSString *)userName
{
	float			stamp_height = 30.0f;
	NSRect			r = [contentView frame];
	NSString		*label = [NSString stringWithFormat: @"%@ : %@", userName, msg];
	NSRect			new_area = NSMakeRect(0, r.size.height, r.size.width, stamp_height);
	NSTextField		*stamp = [[NSTextField alloc] initWithFrame:new_area];	
	
	// Build the stamp
	[stamp setFont:event_font];
	[stamp setEditable:NO];
	[stamp setSelectable:YES];
	[stamp setBordered:NO];
	[stamp setDrawsBackground:NO];
	
	[stamp setAlignment:NSCenterTextAlignment];
	
	[stamp setStringValue:label];
	
	// Add it to the view
	[contentView addSubview:stamp];
	
	// Refresh the current position
	r.size.height += stamp_height;
	[contentView setFrame:r];
	
	// Scroll to end
	[self scrollToEnd];
	
	// Clean
	[stamp release];
}

- (void)addErrorMessage:(NSString *)msg
{
	float	stamp_height = 20.0f;
	NSRect	r = [contentView frame];

	NSRect	new_area = NSMakeRect(0, r.size.height, r.size.width, stamp_height);
	NSColor	*color = [NSColor colorWithDeviceRed:0.47 green:0.47 blue:0.47 alpha:1.0];
		
	// Build the stamp
	NSTextField		*stamp = [[NSTextField alloc] initWithFrame:new_area];
		
	[stamp setFont:[NSFont fontWithName:@"Verdana-Italic" size:10]];
	[stamp setEditable:NO];
	[stamp setSelectable:YES];
	[stamp setBordered:NO];
	[stamp setDrawsBackground:NO];
	
	[stamp.cell setLineBreakMode:NSLineBreakByTruncatingTail];
	[stamp setAlignment:NSLeftTextAlignment];
	[stamp setTextColor:color];
		
	[stamp setStringValue:msg];
		
		
	// Add it to the view
	[contentView addSubview:stamp];
		
	// Refresh the current position
	r.size.height += stamp_height;
	[contentView setFrame:r];
		
	// Scroll to end
	[self scrollToEnd];
		
	// Clean
	[stamp release];
}

- (void)appendToConversation:(NSString *)text fromUser:(tcchat_user)user
{
	if ([text length] == 0)
		text = @" ";
	
	[self addTimeStamp];
	
	TCChatBubble	*bubble = nil;
	NSRect			r = [contentView frame];
	float			delta = 0;
	tcbubble_style	style = 0;

	// Select style
	if (user == tcchat_local)
	{
		style = tcbubble_gray;
		delta = 50;
	}
	else if (user == tcchat_remote)
	{
		style = tcbubble_blue;
		delta = 0;
	}
	
	// Build a bubble
	bubble = [TCChatBubble bubbleWithText:text andStyle:style];
	[bubble setFrame:NSMakeRect(delta, r.size.height, r.size.width - 50, 100)];

	// Update current size
	r.size.height += [bubble frame].size.height;
	
	// Add the bubble to the document view
	[contentView addSubview:bubble];
	[contentView setFrame:r];
		
	// Scroll to end
	[self scrollToEnd];
}

- (void)scrollToEnd
{
	NSClipView	*content = [self contentView];
	NSPoint		pt = [content constrainScrollPoint:NSMakePoint(0, [contentView frame].size.height)];
	
	[content scrollToPoint:pt];
	
	[self reflectScrolledClipView:content];
}

@end
