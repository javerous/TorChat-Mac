/*
 *  NSWindow+Content.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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


#include <objc/runtime.h>

#import "NSWindow+Content.h"

static char pendingSwitchKey;

@implementation NSWindow (Content)

- (void)switchContentToView:(NSView *)view animated:(BOOL)animated completionHandler:(dispatch_block_t)handler
{
	// Handle pending switch.
	NSMutableArray *pending = objc_getAssociatedObject(self, &pendingSwitchKey);
	
	if (pending)
	{
		if (handler)
			[pending addObject:@{ @"view" : view, @"animated" : @(animated), @"handler" : handler }];
		else
			[pending addObject:@{ @"view" : view, @"animated" : @(animated) }];

		return;
	}
	
	// Switch.
	[self _switchContentToView:view animated:animated completionHandler:handler];
}

- (void)_switchContentToView:(NSView *)newWiew animated:(BOOL)animated completionHandler:(dispatch_block_t)handler
{
	NSView *oldView = self.contentView.subviews.firstObject;
	
	// Compute target window rect.
	NSRect	windowRect = self.frame;
	NSSize	windowContentSize = self.contentView.frame.size;
	
	CGFloat	previousWidth = windowRect.size.width;
	CGFloat	previousHeight = windowRect.size.height;
	
	NSSize	newViewSize = newWiew.frame.size;
	
	windowRect.size.width = (windowRect.size.width - windowContentSize.width) + newViewSize.width;
	windowRect.size.height = (windowRect.size.height - windowContentSize.height) + newViewSize.height;
	
	if (self.isSheet)
		windowRect.origin.x -= (windowRect.size.width - previousWidth) / 2.0;
	else
	{
		//windowRect.origin.x -= (windowRect.size.width - previousWidth) / 2.0;
		windowRect.origin.y -= (windowRect.size.height - previousHeight);
	}
	
	if (animated)
	{
		// Add the new view to window.
		newWiew.alphaValue = 0.0;
		
		[self.contentView addSubview:newWiew];
		
		// Call handler.
		if (handler)
			handler();
		
		// Simplify constraints for animation.
		[self.contentView removeConstraints:self.contentView.constraints];
		
		[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]" options:0 metrics:nil views:@{ @"view" : newWiew }]];
		[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]" options:0 metrics:nil views:@{ @"view" : newWiew }]];
		
		if (oldView)
		{
			[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]" options:0 metrics:nil views:@{ @"view" : oldView }]];
			[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]" options:0 metrics:nil views:@{ @"view" : oldView }]];
		}
		
		// Create pending.
		objc_setAssociatedObject(self, &pendingSwitchKey, [[NSMutableArray alloc] init], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		
		// Animate switching.
		[NSAnimationContext beginGrouping];
		{
			[NSAnimationContext currentContext].duration = 0.2;//0.125;
			
			[[NSAnimationContext currentContext] setCompletionHandler:^{
				
				// Remove old view.
				[oldView removeFromSuperview];
				
				oldView.alphaValue = 1.0;
				
				// Set hard constraint on new view.
				[self.contentView removeConstraints:self.contentView.constraints];
				
				[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{ @"view" : newWiew }]];
				[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{ @"view" : newWiew }]];
				
				
				// Launch pending switch.
				[self _relaunchPending];
			}];
			
			newWiew.animator.alphaValue = 1.0;
			oldView.animator.alphaValue = 0.0;
			
			//if (oldView)
				[self.animator setFrame:windowRect display:YES];
		}
		[NSAnimationContext endGrouping];
	}
	else
	{
		// Replace view.
		[oldView removeFromSuperview];
		[self.contentView addSubview:newWiew];
		
		// Set hard constraint on new view.
		[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:@{ @"view" : newWiew }]];
		[NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:@{ @"view" : newWiew }]];
		
		// Resize.
		//if (oldView)
			[self setFrame:windowRect display:NO];

		// Call handler.
		if (handler)
			handler();
		
		// Launch pending switch.
		[self _relaunchPending];
	}
}

- (void)_relaunchPending
{
	// Fetch pending array.
	NSMutableArray *pendings = objc_getAssociatedObject(self, &pendingSwitchKey);
	
	if (!pendings)
		return;
	
	if (pendings.count == 0)
	{
		objc_setAssociatedObject(self, &pendingSwitchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		return;
	}
	
	// Pop first pending.
	NSDictionary *pending = pendings[0];
	
	[pendings removeObjectAtIndex:0];
	
	// Remove pending array.
	if (pending.count == 0)
	{
		objc_setAssociatedObject(self, &pendingSwitchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
		return;
	}
	
	// Relaunch pending.
	NSView				*view = pending[@"view"];
	NSNumber			*animated = pending[@"animated"];
	dispatch_block_t	handler = pending[@"handler"];
	
	[self _switchContentToView:view animated:animated.boolValue completionHandler:handler];
}

@end
