/*
 *  TCSocket.m
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



#import "TCButton.h"



/*
** TCButton Private
*/
#pragma mark - TCButton Private

@interface TCButton ()
{
    NSImage					*_image;
	NSImage					*_rollOverImage;
	
	BOOL					_isOver;
		
	NSTrackingRectTag		_tracking;
}

- (void)configure;
- (void)loadImage;
- (void)resetTracking;

@end



/*
** TCButton
*/
#pragma mark - TCButton

@implementation TCButton


/*
** TCButton - Instance
*/
#pragma mark - TCButton - Instance

- (id)init
{
	self = [super init];
	
    if (self)
	{
		[self configure];
	}
    
    return self;
}

- (id)initWithFrame:(NSRect)rect
{
	self = [super initWithFrame:rect];
	
	if (self)
	{
		[self configure];
	}
	
	return self;
}

- (id)initWithCoder:(NSCoder *)coder
{
	self = [super initWithCoder:coder];
	
	if (self)
	{
		[self configure];
	}
	
	return self;
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];

	if (_tracking)
		 [self removeTrackingRect:_tracking];
}



/*
** TCButton - Overwrite
*/
#pragma mark - TCButton - OverWrite

- (void)viewWillMoveToWindow:(NSWindow *)newWindow
{
    if ([self window] && _tracking)
	{
        [self removeTrackingRect:_tracking];
		_tracking = 0;
    }
}

- (void)removeFromSuperview
{
	if (_tracking)
		[self removeTrackingRect:_tracking];

	[super removeFromSuperview];
}

- (void)removeFromSuperviewWithoutNeedingDisplay
{
	if (_tracking)
		[self removeTrackingRect:_tracking];

	[super removeFromSuperviewWithoutNeedingDisplay];
}

- (void)setFrame:(NSRect)frame
{
	NSRect prev = [self frame];
	
	[super setFrame:frame];
	
	if (prev.size.width != frame.size.width || prev.size.height != frame.size.height)
		[self resetTracking];
}

- (void)viewDidMoveToWindow
{
	if ([self window])
	{
		[self resetTracking];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(frameDidChange:) name:NSWindowDidResizeNotification object:[self window]];
	}
	else
	{
		if (_tracking)
			[self removeTrackingRect:_tracking];
		
		_tracking = 0;
		
		[[NSNotificationCenter defaultCenter] removeObserver:self name:NSWindowDidResizeNotification object:nil];
	}
}

- (void)frameDidChange:(NSNotification *)aNotification
{	
	[self resetTracking];
}



/*
** TCButton - Tracking
*/
#pragma mark - TCButton - Tracking

- (void)mouseEntered:(NSEvent *)theEvent
{	
	_isOver = YES;
	
	[self loadImage];
	
	id <TCButtonDelegate> delegate = _delegate;
	
	if ([delegate respondsToSelector:@selector(button:isRollOver:)])
		[delegate button:self isRollOver:YES];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	_isOver = NO;
	
	[self loadImage];
	
	id <TCButtonDelegate> delegate = _delegate;

	if ([delegate respondsToSelector:@selector(button:isRollOver:)])
		[delegate button:self isRollOver:NO];
}



/*
** TCButton - States
*/
#pragma mark - TCButton - States

- (void)setImage:(NSImage *)img
{
	_image = img;
	
	[self loadImage];
}

- (void)setPushImage:(NSImage *)img
{
	[self setAlternateImage:img];
}

- (void)setRollOverImage:(NSImage *)img
{
	_rollOverImage = img;
	
	[self loadImage];
}



/*
** TCButton - Tools
*/
#pragma mark - TCButton - Tools

- (void)configure
{
	[self setBordered:NO];
	[self setButtonType:NSMomentaryChangeButton];

	[self resetTracking];
}

- (void)resetTracking
{
	NSRect trackingRect = [self frame];
	
	trackingRect.origin = NSZeroPoint;
	trackingRect.size = NSMakeSize(trackingRect.size.width, trackingRect.size.height);
	
	if (_tracking)
		[self removeTrackingRect:_tracking];
		
	_tracking = [self addTrackingRect:trackingRect owner:self userData:nil assumeInside:NO];
}

- (void)loadImage
{
	if (_isOver)
		[super setImage:_rollOverImage];
	else
		[super setImage:_image];
}

@end
