/*
 *  TCFileReceive.cpp
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



#include <sys/stat.h>

#include "TCFileReceive.h"

#include "TCTools.h"



/*
** TCFileReceive - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCFileReceive - Constructor & Destructor

TCFileReceive::TCFileReceive(const std::string & uuid, const std::string & folder, const std::string & fileName, uint64_t fileSize, uint64_t blockSize)
{
	std::string	fullpath = folder + "/" + fileName;
	struct stat	st;
	
	// Init vars
	nextStart = 0;
	_uuid = uuid;
	_fsize = fileSize;
	_bsize = blockSize;
	
	// Check that the file already exist
	if (stat(fullpath.c_str(), &st) != 0)
	{
		_fpath = fullpath;
		_fname = fileName;
		
		_file = fopen(fullpath.c_str(), "w");
				
		if (!_file)
			throw std::string("core_frec_err_cant_open");
	}
	else
	{
		std::vector<std::string>	*its = createExplode(fileName, ".");
		std::string					*name, *ext;
		char						buffer[512];
		uint32_t					idx = 1;
		
		// Get the extension
		if (its->size() > 1)
		{
			ext = new std::string(".");
			ext->append(its->at(its->size() - 1));
			
			its->erase(its->begin() + (its->size() - 1));
		}
		else
			ext = new std::string("");
		
		// Get the name
		name = createJoin(*its, ".");
		
		// Search for a good name
		while (1)
		{
			snprintf(buffer, sizeof(buffer), "-%u", idx);
			
			fullpath = folder + "/" + *name + buffer + *ext;
						
			if (stat(fullpath.c_str(), &st) != 0)
			{
				_fpath = fullpath;
				_fname = *name + buffer + *ext;
				
				_file = fopen(fullpath.c_str(), "w");
								
				if (!_file)
					throw std::string("core_frec_err_cant_open");
				
				break;
			}
			
			idx++;
		}
		
		// Clean
		delete its;
		delete name;
		delete ext;
	}
}

TCFileReceive::~TCFileReceive()
{	
	if (_file)
		fclose(_file);
	_file = NULL;
}



/*
** TCFileReceive - Tools
*/
#pragma mark -
#pragma mark TCFileReceive - Tools

bool TCFileReceive::writeChunk(const void *chunk, uint64_t chunksz, const std::string & hash, uint64_t *rOffset)
{
	if (!rOffset)
		return false;
	
	uint64_t start = *rOffset;
	bool	result = true;
	
	// Check that the offset is the one expected
	if (start > nextStart)
	{
		*rOffset = nextStart;
		return false;
	}
	
	// Check the MD5
	std::string *md5 = createMD5(chunk, chunksz);
	
	if (md5->compare(hash) == 0)
	{		
		// Write content
		fseek(_file, start, SEEK_SET);
		fwrite(chunk, chunksz, 1, _file);
		fflush(_file);
		
		// Update status
		nextStart = start + chunksz;
		
		*rOffset = start;
		result = true;
	}
	else
	{
		*rOffset = start;
		result = false;
	}
	
	// Clean
	delete md5;
	
	// Return write result
	return result;
}

bool TCFileReceive::isFinished()
{	
	return (nextStart >= _fsize);
}

uint64_t TCFileReceive::receivedSize()
{
	uint64_t result = nextStart;
	
	if (result >= _fsize)
		result = _fsize;
	
	return result;
}
