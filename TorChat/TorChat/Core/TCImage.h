/*
 *  TCImage.h
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

#import <Foundation/Foundation.h>

#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
#	import <UIKit/UIKit.h>
#else
#	import <AppKit/AppKit.h>
#endif


NS_ASSUME_NONNULL_BEGIN


/*
** TCImage
*/
#pragma mark - TCImage

@interface TCImage : NSObject <NSCopying>

// -- Instance --
- (instancetype)initWithWidth:(NSUInteger)width height:(NSUInteger)height NS_DESIGNATED_INITIALIZER;
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
- (nullable instancetype)initWithImage:(UIImage *)image NS_DESIGNATED_INITIALIZER;
#else
- (nullable instancetype)initWithImage:(NSImage *)image NS_DESIGNATED_INITIALIZER;
#endif

- (instancetype)init NS_UNAVAILABLE;

// -- Content --
- (BOOL)setBitmap:(NSData *)bitmap;
- (BOOL)setBitmapAlpha:(NSData *)bitmap;

- (NSData *)bitmap;
- (NSData *)bitmapAlpha;

@property (nullable, nonatomic, readonly, copy) NSData *bitmapMixed;

// -- Properties --
@property (nonatomic, readonly) NSUInteger width;
@property (nonatomic, readonly) NSUInteger height;

// -- Representation --
#if defined(TARGET_OS_IPHONE) && TARGET_OS_IPHONE
@property (nullable, nonatomic, readonly, copy) UIImage *imageRepresentation;
#else
@property (nullable, nonatomic, readonly, copy) NSImage *imageRepresentation;
#endif
@end


NS_ASSUME_NONNULL_END

