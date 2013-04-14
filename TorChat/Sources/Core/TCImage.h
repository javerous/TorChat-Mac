/*
 *  TCImage.h
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



#ifndef _TCIMAGE_H_
# define _TCIMAGE_H_

# include <sys/types.h>

# include "TCObject.h"



/*
** TCImage
*/
#pragma mark - TCImage

class TCImage : public TCObject
{
public:
	TCImage(const TCImage &image);
	TCImage(size_t width, size_t height);
	~TCImage();
	
	bool		setBitmap(const void *data, size_t size);
	bool		setAlphaBitmap(const void *data, size_t size);
	
	const void	*getBitmap() const { return bitmap; };
	size_t		getBitmapSize() const { return width * height * 3; };
	
	const void	*getBitmapAlpha() const { return bitmapAlpha; };
	size_t		getBitmapAlphaSize() const { return width * height * 1; };
	
	const void	*getMixedBitmap();
	
	size_t		getWidth() const { return width; };
	size_t		getHeight() const { return height; };
	
private:
	size_t		width;
	size_t		height;
	
	void		*bitmap;
	void		*bitmapAlpha;
	
	void		*mixedBitmap;
	bool		mixedRendered;
};

#endif
