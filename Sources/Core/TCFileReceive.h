/*
 *  TCFileReceive.h
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



#ifndef _TCFILRECEIVE_H_
# define _TCFILRECEIVE_H_

# include <string>

# include "TCObject.h"



/*
** TCFileReceive
*/
#pragma mark -
#pragma mark TCFileReceive

class TCFileReceive : public TCObject
{
public:
	// -- Constructor & Destructor ---
	TCFileReceive(const std::string & uuid, const std::string & folder, const std::string & fileName, uint64_t fileSize, uint64_t blockSize);
	~TCFileReceive();
	
	// -- Tools --
	bool		writeChunk(const void *chunk, uint64_t chunksz, const std::string & hash, uint64_t *rOffset);
	
	bool		isFinished();
	uint64_t	receivedSize();

	// -- Accessors --
	const std::string &	uuid() const { return _uuid; };
	uint64_t 			fileSize() const { return _fsize; };
	uint16_t 			blockSize() const { return _bsize; };
	const std::string & fileName() const { return _fname; };
	const std::string & filePath() const { return _fpath; };
	
private:
	FILE		*_file;
	
	std::string _uuid;
	uint64_t	_fsize;
	uint16_t	_bsize;
	std::string	_fname;
	std::string	_fpath;
	
	uint64_t	nextStart;
};

#endif
