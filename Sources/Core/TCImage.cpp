/*
 *  TCImage.cpp
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



#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdio.h>

#include "TCImage.h"



/*
** Defines
*/
#pragma mark -
#pragma mark Defines

#define BytesPerPixel		3
#define BytesPerPixelAlpha	1



/*
** TCImage
*/
#pragma mark -
#pragma mark TCImage

TCImage::TCImage(const TCImage &image) :
	width(image.width),
	height(image.height)
{
	if (image.bitmap)
	{
		size_t size = width * height * BytesPerPixel;
		
		bitmap = malloc(size);
		
		if (bitmap)
			memcpy(bitmap, image.bitmap, size);
	}
	else
		bitmap = NULL;
	
	if (image.bitmapAlpha)
	{
		size_t size = width * height * BytesPerPixelAlpha;
		
		bitmapAlpha = malloc(size);
		
		if (bitmapAlpha)
			memcpy(bitmapAlpha, image.bitmapAlpha, size);
	}
	else
		bitmapAlpha = NULL;
	
	if (image.mixedBitmap)
	{
		size_t size = (width * height * BytesPerPixel) + (width * height * BytesPerPixelAlpha);
		
		mixedBitmap = malloc(size);
		
		if (mixedBitmap)
		{
			memcpy(mixedBitmap, image.mixedBitmap, size);
			mixedRendered = true;
		}
		else
			mixedRendered = false;
	}
	else
	{
		mixedBitmap = NULL;
		mixedRendered = false;
	}
}

TCImage::TCImage(size_t _width, size_t _height) :
	width(_width),
	height(_height),
	bitmap(NULL),
	bitmapAlpha(NULL),
	mixedBitmap(NULL),
	mixedRendered(false)
{
}

TCImage::~TCImage()
{
	if (mixedBitmap)
		free(mixedBitmap);
	
	if (bitmapAlpha)
		free(bitmapAlpha);
	
	if (bitmap)
		free(bitmap);
}

bool TCImage::setBitmap(const void *data, size_t size)
{
	// Clean mixed cache
	if (mixedRendered)
	{
		free(mixedBitmap);
		mixedBitmap = NULL;
		mixedRendered = false;
	}
	
	// Clean and copy bitmap
	if (bitmap)
		free(bitmap);
	
	bitmap = NULL;
	
	// Copy data
	if (data && size == width * height * BytesPerPixel)
	{
		bitmap = malloc(size);
		
		if (!bitmap)
			return false;
		
		memcpy(bitmap, data, size);
		
		return true;
	}
		
	return false;
}

bool TCImage::setAlphaBitmap(const void *data, size_t size)
{
	// Clean mixed cache
	if (mixedRendered)
	{
		free(mixedBitmap);
		mixedBitmap = NULL;
		mixedRendered = false;
	}
	
	// Clean and copy bitmap
	if (bitmapAlpha)
		free(bitmapAlpha);
	
	// Copy data
	if (data && size == width * height * BytesPerPixelAlpha)
	{
		bitmapAlpha = malloc(size);
		
		if (!bitmapAlpha)
			return false;
		
		memcpy(bitmapAlpha, data, size);
		
		return true;
	}
	
	return false;
}

const void * TCImage::getMixedBitmap()
{
	if (mixedBitmap && mixedRendered)
		return mixedBitmap;
	
	if (!bitmap)
		return NULL;
	
	size_t	i, size = (width * height * BytesPerPixel) + (width * height * BytesPerPixelAlpha);
	uint8_t	*rBitmap = (uint8_t *)bitmap;
	uint8_t	*rABitmap = (uint8_t *)bitmapAlpha;
	
	// FIXME: use BytesPerPixel & BytesPerPixelAlpha to know channel pixel size

	if (!mixedBitmap)
		mixedBitmap = malloc(size);
	
	for (i = 1; i <= size; i++)
	{
		if (i % 4 == 0)
		{
			if (rABitmap)
			{
				((uint8_t *)mixedBitmap)[i - 1] = *rABitmap;
				rABitmap++;
			}
			else
				((uint8_t *)mixedBitmap)[i - 1] = 0xff;
		}
		else
		{
			((uint8_t *)mixedBitmap)[i - 1] = *rBitmap;
			rBitmap++;
		}
	}

	mixedRendered = true;
	
	return mixedBitmap;
}

