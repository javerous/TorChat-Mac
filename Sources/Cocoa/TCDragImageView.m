/*
 *  TCDragImageView.m
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



#import "TCDragImageView.h"



/*
** TCDragImageView - Private
*/
#pragma mark -
#pragma mark TCDragImageView - Private

@interface TCDragImageView ()

- (NSData *)pngImage;

@end



/*
** TCDragImageView
*/
#pragma mark -
#pragma mark TCDragImageView

@implementation TCDragImageView


/*
** TCDragImageView - Instance
*/
#pragma mark -
#pragma mark TCDragImageView - Instance

- (void)dealloc
{
    [_filename release];
	
    [super dealloc];
}



/*
** TCDragImageView - Public
*/
#pragma mark -
#pragma mark TCDragImageView - Public


- (void)setFilename:(NSString *)filename
{
	if (!filename)
		return;
	
	[filename retain];
	[_filename release];
	
	_filename = filename;
}



/*
** TCDragImageView - Drag
*/
#pragma mark -
#pragma mark TCDragImageView - Drag

- (void)mouseDown:(NSEvent *)event
{
	NSPasteboard	*dragPasteboard = [NSPasteboard pasteboardWithName:NSDragPboard];
	NSImage			*dragImage = [[NSImage alloc] initWithSize:[[self image] size]];
	NSPoint			pt = [self bounds].origin;
	
	// Add pasteboard type (png data, and defered file)	
	[dragPasteboard declareTypes:[NSArray arrayWithObjects:NSPasteboardTypePNG, NSFilesPromisePboardType, nil] owner:self];
	
	// Add defered file type
	[dragPasteboard setPropertyList:[NSArray arrayWithObject:@"png"] forType:NSFilesPromisePboardType];
		
	// Draw dragging image
	[dragImage lockFocus];
	{
		[[self image] dissolveToPoint:NSZeroPoint fraction:0.5];
	}
    [dragImage unlockFocus];
	
	// Start drag session
	[self dragImage:dragImage at:pt offset:NSZeroSize event:event pasteboard:dragPasteboard source:self slideBack:YES];

	// Release
	[dragImage release];
}

- (NSArray *)namesOfPromisedFilesDroppedAtDestination:(NSURL *)dropDestination
{
	NSData		*png = [self pngImage];
	NSString	*filename = [NSString stringWithFormat:@"%@.png", (_filename ? _filename : @"noname")];
	NSURL		*filepath;
	
	if (!png)
		return nil;
	
	filepath = [dropDestination URLByAppendingPathComponent:filename];
	
	if (!filepath)
		return nil;
	
	if ([png writeToURL:filepath atomically:NO] == NO)
		return nil;

	return [NSArray arrayWithObject:filename];
}

- (NSDragOperation)draggingSourceOperationMaskForLocal:(BOOL)flag
{
	return NSDragOperationCopy;
}

- (void)pasteboard:(NSPasteboard *)sender provideDataForType:(NSString *)type
{	
	if ([type compare:NSPasteboardTypePNG] == NSOrderedSame)
	{		
		NSData *png = [self pngImage];
				
		if (png)
			[sender setData:png forType:NSPasteboardTypePNG];
	}
}



/*
** TCDragImageView - Private
*/
#pragma mark -
#pragma mark TCDragImageView - Private

- (NSData *)pngImage
{
	CGImageRef			ref = [[self image] CGImageForProposedRect:NULL context:nil hints:nil];
	NSBitmapImageRep	*imp = [[NSBitmapImageRep alloc] initWithCGImage:ref];
	NSData				*png = [imp representationUsingType:NSPNGFileType properties:nil];
	
	[imp release];
	
	return png;
}

@end
