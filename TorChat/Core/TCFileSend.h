/*
 *  TCFileSend.h
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


/*
** TCFileSend
*/
#pragma mark - TCFileSend

@interface TCFileSend : NSObject

// -- Properties --
@property (strong, nonatomic, readonly) NSString	*uuid;
@property (assign, nonatomic, readonly) uint64_t	fileSize;
@property (assign, nonatomic, readonly) uint16_t	blockSize;
@property (strong, nonatomic, readonly) NSString	*fileName;
@property (strong, nonatomic, readonly) NSString	*filePath;

// -- Instance --
- (id)initWithFilePath:(NSString *)filePath;

// -- Tools --
- (NSString *)readChunk:(void *)bytes chunkSize:(uint64_t *)chunkSize fileOffset:(uint64_t *)fileOffset;
- (void)setNextChunkOffset:(uint64_t)offset;

- (BOOL)isFinished;
- (uint64_t)validatedSize;
- (uint64_t)readSize;

- (void)setValidatedOffset:(uint64_t)offset;

@end
