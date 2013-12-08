//
//  TCChatTextField.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 08/12/2013.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

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
