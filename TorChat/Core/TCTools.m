/*
 *  TCTools.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
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
NSString * hashMD5(NSData *data)
{
	static char hex[] = "0123456789abcdef";

	CC_MD5_CTX	state;
	uint8_t		digest[CC_MD5_DIGEST_LENGTH];
	char		string[CC_MD5_DIGEST_LENGTH * 2 + 1];
	unsigned	i = 0;

	// Compute MD5.
	CC_MD5_Init(&state);

	CC_MD5_Update(&state, [data bytes], (CC_LONG)[data length]);
	
	CC_MD5_Final(digest, &state);
	
	// Create hexa representaion.
	for (i = 0; i < CC_MD5_DIGEST_LENGTH; i++)
	{
		string[i * 2] = hex[(digest[i] >> 4) & 0xf];
		string[(i * 2) + 1] = hex[digest[i] & 0xf];
	}
	
	string[i * 2] = '\0';

	// Return result.
	return [[NSString alloc] initWithCString:string encoding:NSASCIIStringEncoding];
}
