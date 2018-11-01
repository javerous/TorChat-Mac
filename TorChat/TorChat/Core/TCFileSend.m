/*
 *  TCFileSend.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCFileSend.h"

#import "TCTools.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCFileSend - Private
*/
#pragma mark - TCFileSend - Private

@interface TCFileSend ()
{
	// Real file send.
	FILE		*_file;
	
	// Virtual file send.
	NSData		*_data;
	NSUInteger	_dataOffset;

	// Context.
	uint64_t	_validatedOffset;
}

@end



/*
** TCFileSend
*/
#pragma mark - TCFileSend

@implementation TCFileSend


/*
** TCFileSend - Instance
*/
#pragma mark - TCFileSend - Instance

- (nullable instancetype)initWithFilePath:(NSString *)filePath
{
	self = [super init];
	
	if (self)
	{
		_validatedOffset = (uint64_t)-1;
		_blockSize = 8192;

		_uuid = [NSUUID UUID].UUIDString;
		
		// Open the file.
		_file = fopen(filePath.UTF8String, "r");
		
		if (!_file)
			return nil;
		
		// File Size.
		long tl;
		
		if (fseek(_file, 0, SEEK_END) < 0)
			return nil;
		
		if ((tl = ftell(_file)) < 0)
			return nil;

		if (fseek(_file, 0, SEEK_SET) < 0)
			return nil;

		_fileSize = (uint64_t)tl;
		_fileName = filePath.lastPathComponent;
		_filePath = filePath;
	}
	
	return self;
}

- (instancetype)initWithFileData:(NSData *)data fileName:(NSString *)fileName
{
	self = [super init];
	
	if (self)
	{
		_validatedOffset = (uint64_t)-1;
		_blockSize = 8192;
		
		_uuid = [NSUUID UUID].UUIDString;

		// Handle info.
		_fileSize = data.length;
		_fileName = fileName;
		_filePath = nil;
		
		_data = data;
		_dataOffset = 0;
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCFileSend dealloc");
	
	if (_file)
		fclose(_file);
	
	_file = NULL;
}



/*
** TCFileSend - Tools
*/
#pragma mark - TCFileSend - Tools

- (nullable NSString *)readChunk:(void *)bytes chunkSize:(uint64_t *)chunkSize fileOffset:(uint64_t *)fileOffset
{
	NSAssert(bytes, @"bytes is NULL");

	if (_file)
	{
		// Get the current file position.
		long tl = ftell(_file);
		
		if (tl < 0)
			return nil;
		
		// Read a chunk of data.
		size_t size = fread(bytes, 1, _blockSize, _file);
		
		if (size <= 0)
			return nil;
		
		if (chunkSize)
			*chunkSize = size;
		
		if (fileOffset)
			*fileOffset = (uint64_t)tl;
		
		// Return the chunk MD5.
		return hashMD5([NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:NO]);
	}
	else if (_data)
	{
		if (_dataOffset >= _data.length)
			return nil;
		
		NSUInteger size = MIN(_data.length - _dataOffset, _blockSize);
		
		if (size <= 0)
			return nil;
		
		[_data getBytes:bytes range:NSMakeRange(_dataOffset, size)];
		
		if (chunkSize)
			*chunkSize = size;
		
		if (fileOffset)
			*fileOffset = _dataOffset;
		
		_dataOffset += size;
		
		// Return the chunk MD5.
		return hashMD5([NSData dataWithBytesNoCopy:bytes length:size freeWhenDone:NO]);
	}
	
	return nil;
}

- (void)setNextChunkOffset:(uint64_t)offset
{
	if (_validatedOffset != (uint64_t)-1 && offset <= _validatedOffset)
		return;
	
	// Set the file cursor
	if (_file)
		fseek(_file, (long)offset, SEEK_SET);
	else if (_data)
		_dataOffset = offset;
}

- (BOOL)isFinished
{
	if (_validatedOffset == (uint64_t)-1)
		return NO;
	
	return ((_validatedOffset + _blockSize) >= _fileSize);
}

- (uint64_t)validatedSize
{
	if (_validatedOffset == (uint64_t)-1)
		return 0;
	
	uint64_t amount = _validatedOffset + _blockSize;
	
	if (amount > _fileSize)
		amount = _fileSize;
	
	return amount;
}

- (uint64_t)readSize
{
	if (_file)
	{
		long tl = ftell(_file);
	
		if (tl >= 0)
			return (uint64_t)tl;
		else
			return 0;
	}
	else if (_data)
	{
		return _dataOffset;
	}
	
	return 0;
}

- (void)setValidatedOffset:(uint64_t)offset
{
	_validatedOffset = offset;
}

@end


NS_ASSUME_NONNULL_END
