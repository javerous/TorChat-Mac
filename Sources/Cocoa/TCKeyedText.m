/*
 *  TCKeyedText.m
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



#import "TCKeyedText.h"



/*
** TCKeyedText - Private
*/
#pragma mark -
#pragma mark TCKeyedText - Private

@interface TCKeyedText ()

- (void)addValue:(NSAttributedString *)value color:(NSColor *)color row:(NSUInteger)row column:(NSUInteger)column alignment:(NSTextAlignment)alignment;

@end



/*
** TCKeyedText
*/
#pragma mark -
#pragma mark TCKeyedText

@implementation TCKeyedText


/*
** TCKeyedText - Instance
*/
#pragma mark -
#pragma mark TCKeyedText - Instance

- (id)initWithKeySize:(NSUInteger)ksize
{
    if ((self = [super init]))
	{
		// Allocate
		result = [[NSMutableAttributedString alloc] init];
		table = [[NSTextTable alloc] init];
		nline = [[NSAttributedString alloc] initWithString:@"\n"];

		
		// Configure
		[table setNumberOfColumns:2];
		[table setLayoutAlgorithm:NSTextTableAutomaticLayoutAlgorithm];
		[table setHidesEmptyCells:YES];

		// Hold arguments
		keySize = ksize;
    }
    
    return self;
}

- (void)dealloc
{
	[nline release];
	[table release];
	[result release];
	
    [super dealloc];
}



/*
** TCKeyedText - Public
*/
#pragma mark -
#pragma mark TCKeyedText - Public

- (void)addLineWithKey:(NSString *)key andContent:(NSString *)content
{
	NSAttributedString	*akey = [[NSAttributedString alloc] initWithString:key];
	NSAttributedString	*acontent = [[NSAttributedString alloc] initWithString:content];
	
	[self addAttributedLineWithKey:akey andContent:acontent];
	
	[akey release];
	[acontent release];
}

- (void)addAttributedLineWithKey:(NSAttributedString *)key andContent:(NSAttributedString *)content;
{
	[self addValue:key color:[NSColor grayColor] row:rowIndex column:0 alignment:NSRightTextAlignment];
	[self addValue:content color:nil row:rowIndex column:1 alignment:NSLeftTextAlignment];
	
	rowIndex++;
}

- (NSAttributedString *)renderedText
{
	return result;
}



/*
** TCKeyedText - Internal
*/
#pragma mark -
#pragma mark TCKeyedText - Internal

- (void)addValue:(NSAttributedString *)value color:(NSColor *)color row:(NSUInteger)row column:(NSUInteger)column alignment:(NSTextAlignment)alignment
{
	NSTextTableBlock		*block = [[NSTextTableBlock alloc] initWithTable:table startingRow:(NSInteger)row rowSpan:1 startingColumn:(NSInteger)column columnSpan:1];
	NSMutableParagraphStyle	*style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	NSUInteger				textLength = [result length];
	
	// Configure the text block
	[block setVerticalAlignment:NSTextBlockTopAlignment];
	
	[block setWidth:5.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinYEdge];
	[block setWidth:5.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxYEdge];
	[block setWidth:1.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMinXEdge];
	[block setWidth:5.0f type:NSTextBlockAbsoluteValueType forLayer:NSTextBlockPadding edge:NSMaxXEdge];
	
	// Set the size of the first column
	if (column == 0)
		[block setValue:keySize type:NSTextBlockAbsoluteValueType forDimension:NSTextBlockWidth];
	
	// Configure the style with the block
	[style setTextBlocks:[NSArray arrayWithObject:block]];
	
	// Set the text aligment in the style
	[style setAlignment:alignment];
	
	// Add the value on the result string
	[result appendAttributedString:value];
	[result appendAttributedString:nline];
	
	// Apply color
	if (color)
		[result addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(textLength, [result length] - textLength)];
	
	// Apply style
	[result addAttribute:NSParagraphStyleAttributeName value:style range:NSMakeRange(textLength, [result length] - textLength)];
	
	// Release
	[style release];
	[block release];
}

@end
