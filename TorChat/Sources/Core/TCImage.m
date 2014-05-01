/*
 *  TCImage.cpp
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


#import "TCImage.h"



/*
** Defines
*/
#pragma mark - Defines

#define BytesPerPixel		3
#define BytesPerPixelAlpha	1



/*
** TCImage - Private
*/
#pragma mark - TCImage - Private

@interface TCImage ()
{
	NSUInteger	_width;
	NSUInteger	_height;
	
	NSData		*_bitmap;
	NSData		*_bitmapAlpha;
	
	NSData		*_mixedBitmap;
	BOOL		_mixedRendered;
}

@end



/*
** TCImage
*/
#pragma mark - TCImage

@implementation TCImage


/*
** TCImage - Instance
*/
#pragma mark - TCImage - Instance

- (id)initWithWidth:(NSUInteger)width andHeight:(NSUInteger)height
{
	self = [super init];
	
	if (self)
	{
		if (width == 0 || height == 0)
			return nil;
		
		_width = width;
		_height = height;
	}
	
	return self;
}

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (id)initWithImage:(UIImage *)image
#else
- (id)initWithImage:(NSImage *)image
#endif
{
	if (!image)
		return nil;
	
	self = [super init];
	
	if (self)
	{
		// FIXME: build the TCImage size from [NSImage size] instead of static 64x64 ?
		
		// Build an empty bitmap image.
		CGColorSpaceRef	rgb = CGColorSpaceCreateDeviceRGB();
		CGContextRef	bitmapContext = CGBitmapContextCreateWithData(NULL, 64, 64, 8, 64 * 4, rgb, (CGBitmapInfo)kCGImageAlphaPremultipliedLast, NULL, NULL);
		
		if (!bitmapContext)
		{
			CGColorSpaceRelease(rgb);
			return nil;
		}
		
		// Compute output rect.
		CGRect	outRect;
		CGSize	selfSize = [image size];
		
		if (selfSize.width > selfSize.height)
		{
			CGFloat outHeight = (64.0f * selfSize.height) / selfSize.width;
			
			outRect = CGRectMake(0, (64.0f - outHeight) / 2.0f, 64, outHeight);
		}
		else
		{
			CGFloat outWidth = (64.0f * selfSize.width) / selfSize.height;
			
			outRect = CGRectMake((64.0f - outWidth) / 2.0f, 0, outWidth, 64);
		}
		
		// Draw image resized on this bitmap.
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
		UIGraphicsPushContext(bitmapContext);
		{
			CGContextTranslateCTM(bitmapContext, 0.0f, 64);
			CGContextScaleCTM(bitmapContext, 1.0f, -1.0f);
			
			[image drawInRect:outRect blendMode:kCGBlendModeNormal alpha:1.0];
		}
		UIGraphicsPopContext();
#else
		[NSGraphicsContext saveGraphicsState];
		[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:(void *)bitmapContext flipped:NO]];
		{
			[image drawInRect:outRect fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0];
		}
		[NSGraphicsContext restoreGraphicsState];
#endif

		// Kill the pre-multiplied alpha and build separated parts.
		size_t				i, j, k;

		size_t				bitmapSz = 64 * 64 * 3;
		unsigned char		*bitmap = (unsigned char *)malloc(bitmapSz);
		
		size_t				bitmapAlphaSz = 64 * 64 * 1;
		unsigned char		*bitmapAlpha = (unsigned char *)malloc(bitmapAlphaSz);
		
		size_t				fullSz = bitmapSz + bitmapAlphaSz;
		unsigned char		*full = CGBitmapContextGetData(bitmapContext);

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
		
		// Build result.
		_width = 64;
		_height = 64;
		
		[self setBitmap:[[NSData alloc] initWithBytesNoCopy:bitmap length:bitmapSz freeWhenDone:YES]];
		[self setBitmapAlpha:[[NSData alloc] initWithBytesNoCopy:bitmapAlpha length:bitmapAlphaSz freeWhenDone:YES]];
		
		// Clean.
		CGColorSpaceRelease(rgb);
		CGContextRelease(bitmapContext);
	}

	return self;
}



/*
** TCImage - NSCopying
*/
#pragma mark - TCImage - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
	TCImage *copy = [[TCImage allocWithZone:zone] init];
	
	copy->_width = _width;
	copy->_height = _height;
	copy->_bitmap = _bitmap;
	copy->_bitmapAlpha = _bitmapAlpha;
	copy->_mixedBitmap = _mixedBitmap;
	copy->_mixedRendered = _mixedRendered;

	return copy;
}



/*
** TCImage - Content
*/
#pragma mark - TCImage - Content

- (BOOL)setBitmap:(NSData *)bitmap
{
	if ([bitmap length] == 0)
		return NO;
	
	// Clean mixed cache.
	if (_mixedRendered)
	{
		_mixedBitmap = NULL;
		_mixedRendered = NO;
	}
	
	// Clean.
	_bitmap = nil;
	
	// Copy data
	if ([bitmap length] == _width * _height * BytesPerPixel)
	{
		_bitmap = bitmap;
		return YES;
	}
	
	return NO;
}

- (BOOL)setBitmapAlpha:(NSData *)bitmap
{
	// Clean mixed cache.
	if (_mixedRendered)
	{
		_mixedBitmap = nil;
		_mixedRendered = NO;
	}
	
	// Copy data.
	if ([bitmap length] == _width * _height * BytesPerPixelAlpha)
	{
		_bitmapAlpha = bitmap;
		return YES;
	}
	
	return NO;
}

- (NSData *)bitmap
{
	return _bitmap;
}

- (NSData *)bitmapAlpha
{
	return _bitmapAlpha;
}

- (NSData *)bitmapMixed
{
	if (_mixedBitmap && _mixedRendered)
		return _mixedBitmap;
	
	if (!_bitmap)
		return nil;
	
	size_t			i, size = (_width * _height * BytesPerPixel) + (_width * _height * BytesPerPixelAlpha);
	const uint8_t	*rBitmap = (uint8_t *)[_bitmap bytes];
	const uint8_t	*rABitmap = (uint8_t *)[_bitmapAlpha bytes];
	
	// FIXME: use BytesPerPixel & BytesPerPixelAlpha to know channel pixel size
	
	uint8_t *mixedBitmap = (uint8_t *)malloc(size);
	
	for (i = 1; i <= size; i++)
	{
		if (i % 4 == 0)
		{
			if (rABitmap)
			{
				mixedBitmap[i - 1] = *rABitmap;
				rABitmap++;
			}
			else
				mixedBitmap[i - 1] = 0xff;
		}
		else
		{
			mixedBitmap[i - 1] = *rBitmap;
			rBitmap++;
		}
	}
	
	_mixedRendered = YES;
	_mixedBitmap = [[NSData alloc] initWithBytesNoCopy:mixedBitmap length:size freeWhenDone:YES];
	
	return _mixedBitmap;
}

- (NSUInteger)width
{
	return _width;
}

- (NSUInteger)height
{
	return _height;
}



/*
** TCImage - Representation
*/
#pragma mark - TCImage - Representation

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (UIImage *)imageRepresentation
#else
- (NSImage	*)imageRepresentation
#endif
{
	// Create data provider from mixed data.
	NSData				*mixedData = [self bitmapMixed];
	CGDataProviderRef	data;
	
	if (!mixedData)
		return nil;

	data = CGDataProviderCreateWithCFData((__bridge CFDataRef)mixedData);
	
	// Create color space.
	CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
	
	// Create Core Graphic image.
	CGImageRef imageRef = NULL;

	if (data && rgb)
		imageRef = CGImageCreate((size_t)_width, (size_t)_height, 8, 32, (size_t)(4 * _width), rgb, (CGBitmapInfo)kCGImageAlphaLast, data, NULL, TRUE, kCGRenderingIntentDefault);
	
	// Create image.
	id image = nil;

	if (imageRef)
	{
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
		image = [[UIImage alloc] initWithCGImage:imageRef];
#else
		image = [[NSImage alloc] initWithCGImage:imageRef size:NSZeroSize];
#endif
	}
	
	// Clean.
	CGColorSpaceRelease(rgb);
	CGDataProviderRelease(data);
	CGImageRelease(imageRef);
	
	// Return.
	return image;
}

@end
