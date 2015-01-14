/*
 *  TCBuffer.h
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


#import <Foundation/Foundation.h>


/*
** TCBuffer
*/
#pragma mark - TCBuffer

@interface TCBuffer : NSObject

// -- Bytes --
- (void)pushBytes:(const void *)bytes ofSize:(NSUInteger)size copy:(BOOL)copy; 	// Insert at the beggin
- (void)appendBytes:(const void *)bytes ofSize:(NSUInteger)size copy:(BOOL)copy;	// Insert at the end

- (NSUInteger)readBytes:(void *)bytes ofSize:(NSUInteger)size; // Read data from beggin

// -- Tools --
- (NSData *)dataUpToCStr:(const char *)search includeSearch:(BOOL)includeSearch; // Read data up to the string "search"

- (void)clean;
- (void)print;

// -- Properties --
- (NSUInteger)size;

@end

