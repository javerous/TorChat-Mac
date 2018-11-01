/*
 *  TCFileHelper.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCFileHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Prototypes
*/
#pragma mark - Prototypes

static BOOL TCFileRandomize(NSString *path);



/*
** Publics
*/
#pragma mark - Publics

BOOL TCFileSecureRemove(NSString *path)
{
	if (path.length == 0)
		return NO;
	
	if (TCFileRandomize(path) == NO)
		return NO;
	
	return [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
}



/*
** Private
*/
#pragma mark - Private

static BOOL TCFileRandomize(NSString *path)
{
	assert(path);
	
	FILE *f = fopen(path.fileSystemRepresentation, "r+");
	
	if (!f)
		return NO;
	
	// Get file size.
	if (fseek(f, 0, SEEK_END) != 0)
		goto error;
	
	long flength = ftell(f);
	
	if (flength < 0)
		goto error;
	
	if (fseek(f, 0, SEEK_SET) != 0)
		goto error;
	
	// Write random bytes.
	uint8_t rndBuffer[1024];
	
	while (flength > 0)
	{
		size_t rndLen = MIN(flength, sizeof(rndBuffer));
		
		arc4random_buf(rndBuffer, rndLen);
		
		if (fwrite(rndBuffer, rndLen, 1, f) != 1)
			goto error;
		
		flength -= rndLen;
	}
	
	// Close & return.
	fclose(f);
	return YES;
	
error:
	fclose(f);
	return NO;
}


NS_ASSUME_NONNULL_END
