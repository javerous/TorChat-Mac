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


/*
** TCImage
*/
#pragma mark - TCImage

@interface TCImage : NSObject <NSCopying>

// -- Instance --
- (id)initWithWidth:(NSUInteger)width andHeight:(NSUInteger)height;
- (id)initWithImage:(NSImage *)image;

// -- Content --
- (BOOL)setBitmap:(NSData *)bitmap;
- (BOOL)setBitmapAlpha:(NSData *)bitmap;

- (NSData *)bitmap;
- (NSData *)bitmapAlpha;

- (NSData *)bitmapMixed;

// -- Properties --
- (NSUInteger)width;
- (NSUInteger)height;

// -- Representation --
- (NSImage *)imageRepresentation;

@end
