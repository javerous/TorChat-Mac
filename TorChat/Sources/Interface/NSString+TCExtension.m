/*
 *  NSString+TCExtension.m
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



#import "NSString+TCExtension.h"



/*
** NSString - TCExtension
*/
#pragma mark - NSString - TCExtension

@implementation NSString (TCExtension)

// == Compute string height ==
- (CGFloat)heightForDrawingWithFont:(NSFont *)font andWidth:(CGFloat)width
{
	// http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
	
	NSTextStorage	*textStorage = [[NSTextStorage alloc] initWithString:self];
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(width, FLT_MAX)];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
	
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	
	[textStorage addAttribute:NSFontAttributeName value:font range:NSMakeRange(0, [textStorage length])];
	[textContainer setLineFragmentPadding:0];
	[layoutManager setTypesetterBehavior:NSTypesetterLatestBehavior];
	
	(void) [layoutManager glyphRangeForTextContainer:textContainer];
	
	return [layoutManager usedRectForTextContainer:textContainer].size.height + 6.0; // This value is empiric. Why it's always so hard to have a good computation of a text size ?
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

- (NSString *)stringByEscapingXMLEntities
{
	return (__bridge_transfer NSString *)CFXMLCreateStringByEscapingEntities(kCFAllocatorDefault, (__bridge CFStringRef)self, NULL);
}

@end



/*
** NSAttributedString - TCExtension
*/
#pragma mark - NSAttributedString - TCExtension

@implementation NSAttributedString (TCExtension)

// == Compute string height ==
- (CGFloat)heightForDrawingWithWidth:(float)width
{
	// http://developer.apple.com/mac/library/documentation/Cocoa/Conceptual/TextLayout/Tasks/StringHeight.html
	
	NSTextStorage	*textStorage = [[NSTextStorage alloc] initWithAttributedString:self];
	NSTextContainer *textContainer = [[NSTextContainer alloc] initWithContainerSize: NSMakeSize(width, FLT_MAX)];
	NSLayoutManager *layoutManager = [[NSLayoutManager alloc] init];
	
	[layoutManager addTextContainer:textContainer];
	[textStorage addLayoutManager:layoutManager];
	
	[textContainer setLineFragmentPadding:0];
	//[layoutManager setTypesetterBehavior:NSTypesetterBehavior_10_2_WithCompatibility] ;
	
	(void) [layoutManager glyphRangeForTextContainer:textContainer];
	
	return [layoutManager usedRectForTextContainer:textContainer].size.height;
}

@end
