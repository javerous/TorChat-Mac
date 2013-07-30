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

#import "TCTools.h"



/*
** Network
*/
#pragma mark - Network

// == Use async I/O on a socket ==
BOOL doAsyncSocket(int sock)
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
** Hash
*/
#pragma mark - Hash

// == Build the MD5 of a chunk of data ==
NSString *	createMD5(const void *data, size_t size)
{
#warning XXX check this code.
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

	return [[NSString alloc] initWithCString:temp encoding:NSASCIIStringEncoding];
}



/*
** Encode
*/
#pragma mark - Encode

// == Encode to base 64 a chunk of data ==
NSString * createEncodeBase64(const void *data, size_t size)
{
#warning XXX check this code.

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
	return [[NSString alloc] initWithData:output encoding:NSASCIIStringEncoding];
}

// == Decode from base 64 a chunk of data ==
BOOL createDecodeBase64(NSString *input, size_t *osize, void **odata)
{
#warning XXX check this code.

	if (!odata || !osize)
		return false;
	
	NSData			*output = nil;
	SecTransformRef transform;
	
	// Create transform.
	transform = SecDecodeTransformCreate(kSecBase64Encoding, NULL);
	
    if (!transform)
        return NO;
	
	// Execute transform.
    if (SecTransformSetAttribute(transform, kSecTransformInputAttributeName, (__bridge CFTypeRef)input, NULL))
        output = (__bridge_transfer NSData *)SecTransformExecute(transform, NULL);
	
	CFRelease(transform);
	
	// Create result.
	if (!output)
		return NO;
	
	*odata = malloc([output length]);
	*osize = [output length];
	
	memcpy(*odata, [output bytes], [output length]);
	
    return YES;
}
