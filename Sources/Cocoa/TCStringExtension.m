/*
 *  TCStringExtension.m
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



#import "TCStringExtension.h"



/*
** NSString - TCStringExtension
*/
#pragma mark -
#pragma mark NSString - TCStringExtension

@implementation NSString (TCStringExtension)

// == Compute string height ==
- (float)heightForDrawingWithFont:(NSFont *)font andWidth:(float)width
{
	// http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
	
	NSTextStorage	*textStorage = [[[NSTextStorage alloc] initWithString:self] autorelease];
	NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(width, FLT_MAX)] autorelease];
	NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
	
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	
	[textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [textStorage length])];
	[textContainer setLineFragmentPadding:0];
	[layoutManager setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility] ;

		
	(void) [layoutManager glyphRangeForTextContainer:textContainer];
	return [layoutManager usedRectForTextContainer:textContainer].size.height;
}

- (NSString *)realPath
{
	const char	*path = [self UTF8String];
	char		*rpath;
	NSString	*result;
		
	if (!path)
		return nil;

	rpath = realpath(path, NULL);

	if (!rpath)
		return nil;

	result = [NSString stringWithUTF8String:rpath];
	
	free(rpath);
	
	return result;
}

@end



/*
** NSAttributedString - TCStringExtension
*/
#pragma mark -
#pragma mark NSAttributedString - TCStringExtension

@implementation NSAttributedString (TCStringExtension)

// == Compute string height ==
- (float)heightForDrawingWithWidth:(float)width
{
	// http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
	
	NSTextStorage	*textStorage = [[[NSTextStorage alloc] initWithAttributedString:self] autorelease];
	NSTextContainer *textContainer = [[[NSTextContainer alloc] initWithContainerSize: NSMakeSize(width, FLT_MAX)] autorelease];
	NSLayoutManager *layoutManager = [[[NSLayoutManager alloc] init] autorelease];
	
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	
	[textContainer setLineFragmentPadding:0];
	//[layoutManager setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility] ;
	
	(void) [layoutManager glyphRangeForTextContainer:textContainer];
	return [layoutManager usedRectForTextContainer:textContainer].size.height;
}

@end
