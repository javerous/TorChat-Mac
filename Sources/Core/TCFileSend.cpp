/*
 *  TCFileSend.cpp
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#include <uuid/uuid.h>

#include "TCFileSend.h"

#include "TCTools.h"



/*
** TCFileSend - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCFileSend - Constructor & Destructor

TCFileSend::TCFileSend(const std::string & _filePath)
{
	// -- Vars --
	_voffset = 0;
	_fpath = _filePath;
	
	// -- Open the file --
	_file = fopen(_filePath.c_str(), "r");
	
	if (!_file)
		throw std::string("core_fsend_err_cant_open");
	
	
	// -- Compute the file size --
	long tl;
	
	if (fseek(_file, 0, SEEK_END) < 0)
		throw std::string("core_fsend_err_cant_seek");
	
	if ((tl = ftell(_file)) < 0)
		throw std::string("core_fsend_err_cant_tell");
	
	if (fseek(_file, 0, SEEK_SET) < 0)
		throw std::string("core_fsend_err_cant_seek");
	
	_fsize = tl;
	
	
	// -- Set the block size --
	_bsize = 8192;
	
	
	// -- Compute uuid --
	uuid_t	out;
	char	cout[40];
	
	uuid_generate(out);
	uuid_unparse(out, cout);
	
	_uuid = cout;
	
	
	// -- Compute filename --
	char	*path = strdup(_filePath.c_str());
	char	*name = NULL;
	int		i, sz = strlen(path);
	
	for (i = sz - 1; i >= 0; i--)
	{
		if (path[i] == '/')
		{
			name = path + i + 1;
			break;
		}
	}
	
	if (!name)
		name = path;
	
	_fname = name;
	
	free(path);
}

TCFileSend::~TCFileSend()
{
	TCDebugLog("TCFileSend destructor");
	
	if (_file)
		fclose(_file);
	_file = NULL;
}



/*
** TCFileSend - Tools
*/
#pragma mark -
#pragma mark TCFileSend - Tools

std::string * TCFileSend::readChunk(void *chunk, uint64_t *chunksz, uint64_t *offset)
{
	if (!chunk)
		return NULL;
	
	// Get the current file position
	long	tl = ftell(_file);
	
	// Read a chunk of data
	size_t	sz = fread(chunk, 1, _bsize, _file);

	if (sz <= 0)
		return NULL;
	
	if (chunksz)
		*chunksz = sz;
	
	if (offset)
		*offset = tl;

	// Return the chunk MD5
	return createMD5(chunk, sz);
}

void TCFileSend::setNextChunkOffset(uint64_t offset)
{
	if (offset <= _voffset)
		return;
	
	// Set the file cursor
	fseek(_file, offset, SEEK_SET);
}


bool TCFileSend::isFinished()
{
	return ((_voffset + _bsize) >= _fsize);
}

uint64_t TCFileSend::validatedSize()
{
	uint64_t amount = _voffset + _bsize;
	
	if (amount > _fsize)
		amount = _fsize;
	
	return amount;
}

uint64_t TCFileSend::readSize()
{
	long	tl = ftell(_file);

	if (tl >= 0)
		return tl;
	else
		return 0;
}

void TCFileSend::setValidatedOffset(uint64_t offset)
{
	_voffset = offset;
}

