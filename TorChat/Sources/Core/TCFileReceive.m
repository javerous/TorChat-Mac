/*
 *  TCFileReceive.cpp
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

#include <sys/stat.h>

#import "TCFileReceive.h"

#import "TCTools.h"



/*
** TCFileReceive - Private
*/
#pragma mark - TCFileReceive - Private

@interface TCFileReceive ()
{
	FILE		*_file;
	uint64_t	_nextStart;

}


@end



/*
** TCFileReceive
*/
#pragma mark - TCFileReceive

@implementation TCFileReceive


/*
** TCFileReceive - Instance
*/
#pragma mark - TCFileReceive - Instance

- (id)initWithUUID:(NSString *)uuid folder:(NSString *)folder fileName:(NSString *)fileName fileSize:(uint64_t)fileSize blockSiz:(uint64_t)blockSize
{
	if (!uuid || !folder || !fileName)
		return nil;
	
	self = [super init];
	
	if (self)
	{
		NSString *fullPath = [folder stringByAppendingPathComponent:fileName];
		struct stat	st;
		
		// Init vars
		_nextStart = 0;
		_uuid = uuid;
		_fileSize = fileSize;
		_blockSize = blockSize;
		
		// Check that the file already exist
		if (stat([fullPath UTF8String], &st) != 0)
		{
			_filePath = fullPath;
			_fileName = fileName;
			
			_file = fopen([fullPath UTF8String], "w");
			
			if (!_file)
				return nil;
			//throw std::string("core_frec_err_cant_open");
#warning Remove this localized string.
		}
		else
		{
			NSString	*ext = [fileName pathExtension];
			NSString	*name = [fileName stringByDeletingPathExtension];
			NSUInteger	idx = 1;

			if (!ext)
				ext = @"";

			// Search for a good name
			while (1)
			{
				NSString *tempName = [NSString stringWithFormat:@"%@-%lu.%@", name, idx, ext];
				NSString *tempPath = [folder stringByAppendingPathComponent:tempName];
								
				if (stat([tempPath UTF8String], &st) != 0)
				{
					_fileName = tempPath;
					_fileName = tempName;
					
					_file = fopen([tempPath UTF8String], "w");
					
					if (!_file)
						return nil;
					//throw std::string("core_frec_err_cant_open");
#warning Remove this localized string.
					break;
				}
				
				idx++;
			}
		}
	}
	
	return self;
}

- (void)dealloc
{
	if (_file)
		fclose(_file);
	
	_file = NULL;
}



/*
** TCFileReceive - Tools
*/
#pragma mark - TCFileReceive - Tools

- (BOOL)writeChunk:(const void *)bytes chunkSize:(uint64_t)chunkSize hash:(NSString *)hash offset:(uint64_t *)offset
{
	if (!offset)
		return NO;
	
	uint64_t	start = *offset;
	BOOL		result = YES;
	
	// Check that the offset is the one expected
	if (start > _nextStart)
	{
		*offset = _nextStart;
		return NO;
	}
	
	// Check the MD5
	NSString *md5 = createMD5(bytes, (size_t)(chunkSize));
	
	if ([md5 isEqualToString:hash])
	{
		// Write content
		fseek(_file, (long)start, SEEK_SET);
		fwrite(bytes, (size_t)(chunkSize), 1, _file);
		fflush(_file);
		
		// Update status
		_nextStart = start + chunkSize;
		
		*offset = start;
		result = YES;
	}
	else
	{
		*offset = start;
		result = NO;
	}
	
	// Return write result
	return result;
}

- (BOOL)isFinished
{
	return (_nextStart >= _fileSize);
}

- (uint64_t)receivedSize
{
	uint64_t result = _nextStart;
	
	if (result >= _fileSize)
		result = _fileSize;
	
	return result;
}

@end
