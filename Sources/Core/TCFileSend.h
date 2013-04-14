/*
 *  TCFileSend.h
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



#ifndef _TCFILESEND_H_
# define _TCFILESEND_H_

# include <string>

# include "TCObject.h"



/*
** TCFileSend
*/
#pragma mark -
#pragma mark TCFileSend

// == Class ==
class TCFileSend : public TCObject
{
public:
	// -- Constructor & Destructor ---
	TCFileSend(const std::string & filePath);
	~TCFileSend();
	
	// -- Tools --
	std::string *	readChunk(void *chunk, uint64_t *chunksz, uint64_t *offset);
	void			setNextChunkOffset(uint64_t offset);

	bool			isFinished();
	uint64_t		validatedSize();
	uint64_t		readSize();
	
	void			setValidatedOffset(uint64_t offset);
		
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
	std::string _fpath;
	
	uint64_t	_voffset;
};

#endif
