/*
 *  TCTools.cpp
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



#include <stdlib.h>
#include <fcntl.h>

#include <openssl/md5.h>

#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/buffer.h>

#include "TCTools.h"



/*
** Network
*/
#pragma mark -
#pragma mark Network

// == Use async I/O on a socket ==
bool doAsyncSocket(int sock)
{
	// Set as non blocking
	int arg = fcntl(sock, F_GETFL, NULL);
	
	if (arg == -1)
		return false;
	
	arg |= O_NONBLOCK;
	arg = fcntl(sock, F_SETFL, arg);
	
	if (arg == -1)
		return false;
	
	return true;
}



/*
** Strings
*/
#pragma mark -
#pragma mark Strings

// == Explode a string in an array, using a delimiter ==
std::vector<std::string> * createExplode(const std::string &_s, const std::string &e)
{
    std::string                 s = _s;
	std::vector<std::string>    *ret = new std::vector<std::string>;
	
	int	iPos = s.find(e, 0);
	int	iPit = e.length();
	
	while (iPos > -1)
	{
		ret->push_back(s.substr(0, iPos));
		
		s.erase(0, iPos + iPit);
		
		iPos = s.find(e, 0);
	}

	ret->push_back(s);
	
	return ret;
}

// == Glue items in an array with a delimiter ==
std::string * createJoin(const std::vector<std::string> &items, const std::string &glue)
{
	std::string	*result = new std::string;
	size_t		i, cnt = items.size();
	
	if (cnt == 0)
		return result;
	
	for (i = 0; i < cnt - 1; i++)
	{
		result->append(items[i]);
		result->append(glue);
	}
	
	if (cnt > 0)
		result->append(items[cnt - 1]);
	
	return result;
}

std::string * createJoin(const std::vector<std::string> &items, size_t start, const std::string &glue)
{
	std::string	*result = new std::string;
	size_t		i, cnt = items.size();
	
	if (cnt == 0)
		return result;
	
	for (i = start; i < cnt - 1; i++)
	{
		result->append(items[i]);
		result->append(glue);
	}
	
	if (cnt > 0)
		result->append(items[cnt - 1]);
	
	return result;
}

// == Replace all occurrence of a string by another one ==
std::string * createReplaceAll(const std::string &s, const std::string &o, const std::string &r)
{
	std::string				*ret = new std::string(s);
	
	for (std::string::size_type i = ret->find(o, 0); i != std::string::npos; i = ret->find(o, i + r.size()))
	{
		ret->replace(i, o.size(), r);
	}

	return ret;
}



/*
** Data
*/
#pragma mark -
#pragma mark Data

// == Search a chunk of data in another chunk of data ==
ssize_t memsearch(const uint8_t *token, size_t token_sz, const uint8_t *data, size_t data_sz)
{
	size_t	pos = 0;
	size_t	i = 0;
	
	while (token_sz <= data_sz)
	{
		for (i = 0; i < token_sz; i++)
		{
			if (data[i] != token[i])
				break;
		}
		
		if (i >= token_sz)
			return pos;
		
		pos++;
		data++;
		data_sz--;
	}
	
	return -1;
}



/*
** Hash
*/
#pragma mark -
#pragma mark Hash

// == Build the MD5 of a chunk of data ==
std::string * createMD5(const void *data, size_t size)
{
	MD5_CTX			state;
	unsigned char	digest[MD5_DIGEST_LENGTH];
	int				di = 0;
	int				rc;
	char			hex[16] = "0123456789abcdef";
	
	static char		temp[100];

	MD5_Init(&state);

	MD5_Update(&state, data, size);
	
	MD5_Final(digest, &state);
	
	for (di = 0, rc = 0; di < MD5_DIGEST_LENGTH; ++di, rc += 2)
	{
		temp[rc] = hex[digest[di] >> 4];
		temp[rc + 1] = hex[digest[di] & 15];
	}
	
	temp[rc] = '\0';

	return new std::string(temp);
}



/*
** Encode
*/
#pragma mark -
#pragma mark Encode

// == Encode to base 64 a chunk of data ==
std::string * createEncodeBase64(const void *data, size_t size)
{
	BIO		*bmem, *b64;
	BUF_MEM	*bptr;
	
	// Create BIO
	b64 = BIO_new(BIO_f_base64());
	bmem = BIO_new(BIO_s_mem());
	
	b64 = BIO_push(b64, bmem);
	
	// Write the data to encode
	BIO_write(b64, data, size);
	(void)BIO_flush(b64);
	BIO_get_mem_ptr(b64, &bptr);

	// Build result
	std::string *res = new std::string(bptr->data, bptr->length); // Skip new line
	
	// Clean
	BIO_free_all(b64);
	
	return res;
}

// == Decode from base 64 a chunk of data ==
bool createDecodeBase64(const std::string &data, size_t *osize, void **odata)
{
	if (!osize || !odata)
		return false;
	
	BIO		*b64, *bmem;
	int		readlen = -1;
	uint8_t	*buffer;
	

	// Create BIO for base 64
	b64 = BIO_new(BIO_f_base64());
	if (!b64)
		return false;
	
	bmem = BIO_new_mem_buf((void *)data.data(), (int)data.size());
	if (!bmem)
		return false;
	
	b64 = BIO_push(b64, bmem);
	if (!b64)
		return false;
	
	
	// Read the data to decode
	buffer = (uint8_t *)malloc(data.size() + 1);
	
	if (buffer)
	{
		readlen = BIO_read(b64, buffer, data.size());
		
		if (readlen <= 0)
			return false;
		
		buffer[readlen] = 0;
	}
	
	// Free
	BIO_free_all(b64);
	
	// Give result
	*osize = readlen;
	*odata = buffer;
	
	return true;
}
