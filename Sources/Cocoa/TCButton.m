/*
 *  TCSocket.m
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



#import "TCButton.h"



/*
** TCButton Private
*/
#pragma mark -
#pragma mark TCButton Private

@interface TCButton ()
	- (void)_configure;
	- (void)_loadImage;
	- (void)_resetTracking;
@end



/*
** TCButton
*/
#pragma mark -
#pragma mark TCButton

@implementation TCButton

@synthesize delegate;



/*
** TCButton - Instance
*/
#pragma mark -
#pragma mark TCButton - Instance

- (id)init
{
    if ((self = [super init]))
	{
		[self _configure];
	}
    
    return self;
}

- (id)initWithFrame:(NSRect)rect
{
	if ((self = [super initWithFrame:rect]))
	{
		[self _configure];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	if ((self = [super initWithCoder:coder]))
	{
		[self _configure];
	}
	
	return self;
}

- (void)dealloc
{
	[rollOverImage release];
	[image release];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];

	if (tracking)
		 [self removeTrackingRect:tracking];
    
    [super dealloc];
}



/*
** TCButton - Overwrite
*/
#pragma mark -
#pragma mark TCButton - OverWrite

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if ([self window] && tracking)
	{
        [self removeTrackingRect:tracking];
		tracking = 0;
    }
}

- (void)removeFromSuperview
{
	if (tracking)
		[self removeTrackingRect:tracking];

	[super removeFromSuperview];
}

- (void)removeFromSuperviewWithoutNeedingDisplay
{
	if (tracking)
		[self removeTrackingRect:tracking];

	[super removeFromSuperviewWithoutNeedingDisplay];
}

- (void)setFrame:(NSRect)frame
{
	NSRect prev = [self frame];
	
	[super setFrame:frame];
	
	if (prev.size.width != frame.size.width || prev.size.height != frame.size.height)
		[self _resetTracking];
}

- (void)viewDidMoveToWindow
{
	if ([self window])
	{
		[self _resetTracking];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameDidChange:) name:NSWindowDidResizeNotification object:[self window]];
	}
	else
	{
		if (tracking)
			[self removeTrackingRect:tracking];
		tracking = 0;
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];
	}
}

- (void)frameDidChange:(NSNotification *)aNotification
{	
	[self _resetTracking];
}



/*
** TCButton - Tracking
*/
#pragma mark -
#pragma mark TCButton - Tracking

- (void)mouseEntered:(NSEvent *)theEvent
{	
	isOver = YES;
	[self _loadImage];
	
	if ([delegate respondsToSelector:@selector(button:isRollOver:)])
		[delegate button:self isRollOver:YES];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	isOver = NO;
	[self _loadImage];
	
	if ([delegate respondsToSelector:@selector(button:isRollOver:)])
		[delegate button:self isRollOver:NO];
}



/*
** TCButton - States
*/
#pragma mark -
#pragma mark TCButton - States

- (void)setImage:(NSImage *)img
{
	[img retain];
	[image release];
	
	image = img;
	
	[self _loadImage];
}

- (void)setPushImage:(NSImage *)img
{
	[self setAlternateImage:img];
}

- (void)setRollOverImage:(NSImage *)img
{
	[img retain];
	[rollOverImage release];
	
	rollOverImage = img;
	
	[self _loadImage];
}



/*
** TCButton - Tools
*/
#pragma mark -
#pragma mark TCButton - Tools

- (void)_configure
{
	[self setBordered:NO];
	[self setButtonType:NSMomentaryChangeButton];

	[self _resetTracking];
}

- (void)_resetTracking
{
	NSRect trackingRect = [self frame];
	
	trackingRect.origin = NSZeroPoint;
	trackingRect.size = NSMakeSize(trackingRect.size.width, trackingRect.size.height);
	
	if (tracking)
		[self removeTrackingRect:tracking];
		
	tracking = [self addTrackingRect:trackingRect owner:self userData:nil assumeInside:NO];
}

- (void)_loadImage
{
	if (isOver)
		[super setImage:rollOverImage];
	else
		[super setImage:image];
}

@end
