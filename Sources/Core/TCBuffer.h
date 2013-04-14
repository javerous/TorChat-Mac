/*
 *  TCBuffer.h
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



#ifndef _TCBUFFER_H_
# define _TCBUFFER_H_

# include <sys/types.h>
# include <string>

# include "TCObject.h"



/*
** Types
*/
#pragma mark -
#pragma mark Types

typedef struct _tc_items tc_items;



/*
** TCBuffer
*/
#pragma mark -
#pragma mark TCBuffer

// == Class ==
class TCBuffer : public TCObject
{
public:
	
	// -- Constructor & Destructor --
	TCBuffer();
	~TCBuffer();
	
	// -- Data --
	void	pushData(const void *data, size_t size, bool copy);		// Insert at the beggin
	void	appendData(const void *data, size_t size, bool copy);	// Insert at the end
	
	size_t	readData(void *buffer, size_t size);					// Read data from beggin
	
	// -- Tools --
	std::string *createStringSearch(const std::string &search, bool returnSearch); // Read data up to the string "search"
	
	void		clean();
	void		print();
	
	// -- Property --
	size_t	size();

private:
	tc_items	*items;
	
};

#endif
