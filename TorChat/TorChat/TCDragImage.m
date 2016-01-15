/*
 *  TCDragImage.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
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

#import "TCDragImage.h"


/*
** TCDragImage
*/
#pragma mark - TCDragImage

@implementation TCDragImage


/*
** TCDragImage - Instance
*/
#pragma mark - TCDragImage - Instance

- (id)initWithImage:(NSImage *)image andName:(NSString *)name
{
	if (!image || [name length] == 0)
		return nil;
	
	self = [super init];
	
	if (self)
	{
		_image = image;
		_name = name;
	}
	
	return self;
}



/*
** TCDragImage - NSPasteboardWriting
*/
#pragma mark - TCDragImage - NSPasteboardWriting

- (NSArray *)writableTypesForPasteboard:(NSPasteboard *)pasteboard
{
	return @[ NSPasteboardTypePNG, (NSString *)kPasteboardTypeFileURLPromise ];
}

- (id)pasteboardPropertyListForType:(NSString *)type
{
	if ([type isEqualToString:NSPasteboardTypePNG])
	{
		return [self pngImage];
	}
	else if ([type isEqualToString:(NSString *)kPasteboardTypeFileURLPromise])
	{
		OSStatus err;
		
		// Get drag pastboard.
		PasteboardRef pasteboard = NULL;
		
		err = PasteboardCreate((__bridge CFStringRef)NSDragPboard, &pasteboard);
		
		if (err != noErr)
			return nil;
		
		// Get current drag location.
		CFURLRef urlRef = NULL;

		err = PasteboardCopyPasteLocation(pasteboard, &urlRef);
		
		if (err != noErr)
		{
			CFRelease(pasteboard);
			return nil;
		}
		
		// Build final path.
		NSURL *url = (__bridge_transfer NSURL *)urlRef;

		url = [[url URLByAppendingPathComponent:_name] URLByAppendingPathExtension:@"png"];

		// Write file.
		[[self pngImage] writeToURL:url atomically:NO];

		// Clean.
		CFRelease(pasteboard);
		
		// Return path.
		return [url absoluteString];
	}
	
	return nil;
}



/*
 ** TCDragImage - Helpers
 */
#pragma mark - TCDragImage - Helpers

- (NSData *)pngImage
{
	CGImageRef			ref = [[self image] CGImageForProposedRect:NULL context:nil hints:nil];
	NSBitmapImageRep	*imp;
	NSData				*png;
	
	if (!ref)
		return nil;
	
	imp = [[NSBitmapImageRep alloc] initWithCGImage:ref];
	
	if (!imp)
		return nil;
	
	png = [imp representationUsingType:NSPNGFileType properties:@{ }];
	
	return png;
}

@end