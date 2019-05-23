/*
 *  NSString+TCLayoutExtension.h
 *
 *  Copyright 2019 Avérous Julien-Pierre
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

#import <Cocoa/Cocoa.h>


NS_ASSUME_NONNULL_BEGIN


/*
** NSString - TCLayoutExtension
*/
#pragma mark - NSString - TCLayoutExtension

@interface NSString (TCLayoutExtension)

- (CGFloat)heightForDrawingWithFont:(NSFont *)font maxWidth:(CGFloat)width;

@end



/*
** NSAttributedString - TCLayoutExtension
*/
#pragma mark - NSAttributedString - TCLayoutExtension

@interface NSAttributedString (TCLayoutExtension)

- (CGFloat)heightForDrawingWithWidth:(float)width;

@end


NS_ASSUME_NONNULL_END
