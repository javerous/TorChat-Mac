/*
 *  TCBuffer.cpp
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



#include <string.h>
#include <stdlib.h>
#include <stdio.h>

#include "TCBuffer.h"

#include "TCTools.h"



/*
** Types
*/
#pragma mark - Types

typedef struct _tc_item tc_item;

struct _tc_item
{
	void	*data;
	size_t	size;
	
	tc_item *next;
	tc_item *prev;
};

struct _tc_items
{
	tc_item	*first;
	tc_item	*last;
	
	size_t	size;
};



/*
** TCBuffer - Instance
*/
#pragma mark - TCBuffer - Instance

TCBuffer::TCBuffer()
{
	items = static_cast<tc_items *>(malloc(sizeof(tc_items)));
	
	items->first = NULL;
	items->last = NULL;
	items->size = 0;
}

TCBuffer::~TCBuffer()
{
	TCDebugLog("TCBuffer Destructor");
	
	clean();
	
	free(items);
}



/*
** TCBuffer - Data
*/
#pragma mark - TCBuffer - Data

// == Insert data at the beggin ==
void TCBuffer::pushData(const void *data, size_t size, bool copy)
{
	if (size == 0 || !data)
		return;
	
	tc_item	*item = static_cast<tc_item *>(malloc(sizeof(tc_item)));
	
	// Set data
	if (copy)
	{
		item->data = malloc(size);
		
		memcpy(item->data, data, size);
	}
	else
		item->data = (void *)data;
	
	// Set others
	item->size = size;
	item->prev = NULL;
	item->next = NULL;
	
	// Insert it
	if (items->first)
	{
		item->next = items->first;
		items->first->prev = item;
	}
	items->first = item;
	
	if (!items->last)
		items->last = item;
	
	// Update global size
	items->size += size;
}

// == Append data at the end ==
void TCBuffer::appendData(const void *data, size_t size, bool copy)
{
	if (size == 0 || !data)
		return;
	
	tc_item	*item = static_cast<tc_item *>(malloc(sizeof(tc_item)));
	
	// Set data
	if (copy)
	{
		item->data = malloc(size);
		
		memcpy(item->data, data, size);
	}
	else
		item->data = (void *)data;
	
	// Set others
	item->size = size;
	item->prev = NULL;
	item->next = NULL;
	
	// Insert it
	item->prev = items->last;
	
	if (items->last)
		items->last->next = item;
	
	items->last = item;
	
	if (!items->first)
		items->first = item;
	
	// Update global size
	items->size += size;
}

// == Pop data from the buffer ==
size_t TCBuffer::readData(void *buffer, size_t size)
{	
	if (!buffer || !size)
		return 0;
	
	size_t	readden = 0;
	tc_item	*item  = items->first;
	
	if (size > items->size)
		size = items->size;
	
	while (size > 0 && item)
	{
		// Compute size to read from the item
		size_t part = 0;
		
		if (item->size > size)
			part = size;
		else
			part = item->size;
		
		// Write them
		memcpy(buffer, item->data, part);
		
		// Update status
		buffer = (char *)buffer + part;
		size -= part;
		readden += part;
		
		tc_item	*tmp = item;
			
		// Go on next
		item = item->next;
			
		// Remove item
		items->first = tmp->next;
		if (!items->first)
			items->last = NULL;
			
		if (tmp->next)
			tmp->next->prev = NULL;
		
		// The block is removed, remove its size
		items->size -= tmp->size;
		
		// Reinsert remening data
		if (part < tmp->size)
		{
			size_t	rest = tmp->size - part;
			void	*buff = malloc(rest);
			
			memcpy(buff, (char *)tmp->data + part, rest);
			
			pushData(buff, rest, false);
		}

		// Clean item
		free(tmp->data);
		free(tmp);
	}
	
	return readden;
}



/*
** TCBuffer - Tools
*/
#pragma mark - TCBuffer - Tools

// == Pop a string from the buffer, up to a search string ==
std::string * TCBuffer::createStringSearch(const std::string &search, bool returnSearch)
{
	bool		found = false;
	size_t		sz = 0;
	tc_item		*item = items->first;
	
	const char *c_search = search.c_str();
	size_t		c_size = search.size();
	
	size_t		pos = 0;
	
	while (item)
	{
		pos = memsearch((uint8_t *)c_search, c_size, (uint8_t *)item->data, item->size);

		if (pos != static_cast<size_t>(-1))
		{
			sz += pos + c_size;
			found = true;
			
			break;
		}
		
		sz += item->size;
		item = item->next;
	}
	
	if (found && sz > 0)
	{
		char		*result = static_cast<char *>(malloc(sz));
		std::string	*rresult = NULL;
		
		readData(result, sz);
		
		if (!returnSearch)
			sz -= c_size;
		
		rresult = new std::string(result, sz);
		free(result);
		
		return rresult;
	}
	
	return NULL;
}

// == Clean buffer content ==
void TCBuffer::clean()
{
	tc_item	*item, *nitem;
	
	item = items->first;
	
	while (item)
	{
		nitem = item->next;
		
		free(item->data);
		free(item);
		
		item = nitem;
	}
	
	items->first = NULL;
	items->last = NULL;
	items->size = 0;
}

// == Print buffer, for debug ==
void TCBuffer::print()
{
	tc_item	*item = items->first;
	
	fprintf(stderr, "First = %p\n", item);
	
	while (item)
	{
		fprintf(stderr, "(%p; %016lu) -> ", item->data, item->size);
		
		item = item->next;
	}
	
	fprintf(stderr, "x\n");
}



/*
** TCBuffer - Property
*/
#pragma mark - TCBuffer - Property

size_t TCBuffer::size()
{
	return items->size;
}



