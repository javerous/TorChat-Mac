/*
 *  TCFileSend.cpp
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

#import "TCFileSend.h"

#import "TCTools.h"
#import "TCDebugLog.h"



/*
** TCFileSend - Private
*/
#pragma mark - TCFileSend - Private

@interface TCFileSend ()
{
	FILE		*_file;

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

- (id)initWithFilePath:(NSString *)filePath
{
	self = [super init];
	
	if (self)
	{
		// Init vars.
		_validatedOffset = (uint64_t)-1;
		_filePath = filePath;
		
		// Open the file.
		_file = fopen([_filePath UTF8String], "r");
		
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
				
		// BLock size.
		_blockSize = 8192;
		
		// UUID.
		uuid_t	out;
		char	cout[40];
		
		uuid_generate(out);
		uuid_unparse(out, cout);
		
		_uuid = [[NSString alloc] initWithCString:cout encoding:NSASCIIStringEncoding];
		
		// Filename.
		_fileName = [_filePath lastPathComponent];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog("TCFileSend destructor");
	
	if (_file)
		fclose(_file);
	
	_file = NULL;
}



/*
** TCFileSend - Tools
*/
#pragma mark - TCFileSend - Tools

- (NSString *)readChunk:(void *)bytes chunkSize:(uint64_t *)chunkSize fileOffset:(uint64_t *)fileOffset
{
	if (!bytes)
		return nil;

	// Get the current file position.
	long tl = ftell(_file);
	
	if (tl < 0)
		return nil;

	// Read a chunk of data.
	size_t sz = fread(bytes, 1, _blockSize, _file);
	
	if (sz <= 0)
		return nil;

	if (chunkSize)
		*chunkSize = sz;
	
	if (fileOffset)
		*fileOffset = (uint64_t)tl;
	
	// Return the chunk MD5.
	return hashMD5([NSData dataWithBytesNoCopy:bytes length:sz freeWhenDone:NO]);
}

- (void)setNextChunkOffset:(uint64_t)offset
{
	if (_validatedOffset != (uint64_t)-1 && offset <= _validatedOffset)
		return;
	
	// Set the file cursor
	fseek(_file, (long)offset, SEEK_SET);
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
	long tl = ftell(_file);
	
	if (tl >= 0)
		return (uint64_t)tl;
	else
		return 0;
}

- (void)setValidatedOffset:(uint64_t)offset
{
	_validatedOffset = offset;
}

@end
