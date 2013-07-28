/*
 *  TCTools.cpp
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


#import <CommonCrypto/CommonCrypto.h>

#include <stdlib.h>
#include <fcntl.h>

#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/buffer.h>

#include "TCTools.h"



/*
** Network
*/
#pragma mark - Network

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
#pragma mark - Strings

// == Explode a string in an array, using a delimiter ==
std::vector<std::string> * createExplode(const std::string &_s, const std::string &e)
{
    std::string                 s = _s;
	std::vector<std::string>    *ret = new std::vector<std::string>;
	
	size_t	iPos = s.find(e, 0);
	size_t	iPit = e.length();
	
	while (iPos != s.npos)
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
** Hash
*/
#pragma mark - Hash

// == Build the MD5 of a chunk of data ==
std::string * createMD5(const void *data, size_t size)
{
	CC_MD5_CTX			state;
	unsigned char	digest[CC_MD5_DIGEST_LENGTH];
	int				di = 0;
	int				rc;
	char			hex[16] = { '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f' };
	
	static char		temp[100];

	CC_MD5_Init(&state);

	CC_MD5_Update(&state, data, size);
	
	CC_MD5_Final(digest, &state);
	
	for (di = 0, rc = 0; di < CC_MD5_DIGEST_LENGTH; ++di, rc += 2)
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
#pragma mark - Encode

// == Encode to base 64 a chunk of data ==
std::string * createEncodeBase64(const void *data, size_t size)
{
	if (!data || size == 0)
		return NULL;
	
	NSData			*input = [[NSData alloc] initWithBytesNoCopy:(void *)data length:size];
	NSData			*output = nil;
	SecTransformRef transform;
	
	// Create transform.
	transform = SecEncodeTransformCreate(kSecBase64Encoding, NULL);
	
    if (!transform)
        return nil;
	
	// Execute transform.
    if (SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFTypeRef)input, NULL))
        output = (__bridge_transfer NSData *)SecTransformExecute(transform, NULL);
	
	  CFRelease(transform);
	
	// Create string.
	std::string *result = new std::string((char *)[output bytes], (size_t)[output length]);
	
    return result;
}

// == Decode from base 64 a chunk of data ==
bool createDecodeBase64(const std::string &data, size_t *osize, void **odata)
{
	if (!odata || !osize)
		return false;
	
	NSString		*input = [[NSString alloc] initWithCString:data.c_str() encoding:NSASCIIStringEncoding];
	NSData			*output = nil;
	SecTransformRef transform;
	
	// Create transform.
	transform = SecDecodeTransformCreate(kSecBase64Encoding, NULL);
	
    if (!transform)
        return nil;
	
	// Execute transform.
    if (SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFTypeRef)input, NULL))
        output = (__bridge_transfer NSData *)SecTransformExecute(transform, NULL);
	
	CFRelease(transform);
	
	// Create result.
	if (!output)
		return false;
	
	*odata = malloc([output length]);
	*osize = [output length];
	
	memcpy(*odata, [output bytes], [output length]);
	
    return true;
}
