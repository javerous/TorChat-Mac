/*
 *  TCOImageExtension.mm
 *
 *  Copyright 2012 Avérous Julien-Pierre
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



#import "TCImageExtension.h"

#include "TCImage.h"



/*
** NSImage - TCImageExtension
*/
#pragma mark - NSImage - TCImageExtension

@implementation NSImage (TCImageExtension)

- (id)initWithTCImage:(TCImage *)image
{
	if (!image)
		return nil;
	
	self = [self initWithSize:NSMakeSize(image->getWidth(), image->getHeight())];
	
	if (self)
	{
		const unsigned char	*plane = (const unsigned char *)image->getMixedBitmap();
		
		if (plane)
		{
			unsigned char		*planes[] = { (unsigned char *)plane };
			NSBitmapImageRep	*rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
																			pixelsWide:(NSInteger)image->getWidth()
																			pixelsHigh:(NSInteger)image->getHeight()
																		 bitsPerSample:8
																	   samplesPerPixel:4
																			  hasAlpha:YES
																			  isPlanar:NO
																		colorSpaceName:NSDeviceRGBColorSpace
																		  bitmapFormat:NSAlphaNonpremultipliedBitmapFormat
																		   bytesPerRow:0
																		  bitsPerPixel:0];
			
			if (rep)
				[self addRepresentation:rep];
		}
	}
	
	return self;
}

- (TCImage *)createTCImage
{
	// FIXME: build the TCImage size from [NSImage size] instead of static 64x64 ?
	
	/*
	 TorChat use separated bitmap for picture and mask. The picture is not pre-multiplied with alpha.
	 Working on not alpha pre-multiplied is a _ploud_ with Core Graphic !!
	 - We can't build a context with a NSBitmapImageRep configured with NSAlphaNonpremultipliedBitmapFormat
	 - We can't build a CGBitmapContext with kCGImageAlphaLast
	 
	 -> Grrrr !
	*/
	
	size_t				bitmapSz = 64 * 64 * 3;
	unsigned char		*bitmap;

	size_t				bitmapAlphaSz = 64 * 64 * 1;
	unsigned char		*bitmapAlpha;

	size_t				fullSz = bitmapSz + bitmapAlphaSz;
	unsigned char		*full = (unsigned char *)calloc(1, fullSz);
	
	size_t				i, j, k;
	
	unsigned char		*planes[] = { full };
	NSBitmapImageRep	*imageRep;
	NSRect				outRect;
	NSSize				selfSize;
	
	if (!full)
		return NULL;
		
	// Build an empty bitmap image
	imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:planes
													   pixelsWide:64
													   pixelsHigh:64
													bitsPerSample:8
												  samplesPerPixel:4
														 hasAlpha:YES
														 isPlanar:NO
												   colorSpaceName:NSDeviceRGBColorSpace
													 bitmapFormat:0
													  bytesPerRow:(64 * 4)
													 bitsPerPixel:32];
	
	
	if (!imageRep)
		return NULL;
	
	// Compute out rect
	selfSize = [self size];
	
	if (selfSize.width > selfSize.height)
	{
		CGFloat outHeight = (64.0f * selfSize.height) / selfSize.width;
		
		outRect = NSMakeRect(0, (64.0f - outHeight) / 2.0f, 64, outHeight);
	}
	else
	{
		CGFloat outWidth = (64.0f * selfSize.width) / selfSize.height;
		
		outRect = NSMakeRect((64.0f - outWidth) / 2.0f, 0, outWidth, 64);
	}
	
	
	// Draw ourself resized on this bitmap
	[NSGraphicsContext saveGraphicsState];
	{
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithBitmapImageRep:imageRep]];
		
		[self drawInRect:outRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
	}
	[NSGraphicsContext restoreGraphicsState];
	
	// Kill the pre-multiplied alpha (f*cking Core Graphic) and build separated parts
	bitmap = (unsigned char *)malloc(bitmapSz);
	bitmapAlpha = (unsigned char *)malloc(bitmapAlphaSz);
	
	for (i = 0, j = 0, k = 0; i < fullSz; i += 4, j += 3, k++)
	{
		uint8_t r = full[i];
		uint8_t g = full[i + 1];
		uint8_t b = full[i + 2];
		uint8_t a = full[i + 3];
		
		if (a > 0)
		{
			double da = (double)a / 255.0;
	
			bitmap[j] = (uint8_t)((double)r / da);
			bitmap[j + 1] = (uint8_t)((double)g / da);
			bitmap[j + 2] = (uint8_t)((double)b / da);
		}
		else
		{
			bitmap[j] = r;
			bitmap[j + 1] = g;
			bitmap[j + 2] = b;
		}
		
		bitmapAlpha[k] = a;
	}
	
	// Build result
	TCImage *result = new TCImage(64, 64);
	
	result->setBitmap(bitmap, bitmapSz);
	result->setAlphaBitmap(bitmapAlpha, bitmapAlphaSz);
	
	// Clean
	free(full);
	free(bitmap);
	free(bitmapAlpha);
	
	return result;
}

@end
