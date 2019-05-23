/*
 *  TCDragImage.h
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

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


/*
** TCDragImage - Interface
*/
#pragma mark - TCDragImage

@interface TCDragImage : NSObject < NSPasteboardWriting>

// -- Instance --
- (instancetype)initWithImage:(NSImage *)image name:(NSString *)name NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

// -- Properties --
@property (strong, nonatomic, readonly) NSImage		*image;
@property (strong, nonatomic, readonly) NSString	*name;

@end


NS_ASSUME_NONNULL_END
