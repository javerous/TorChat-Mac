/*
 *  NSData+TCTools.m
 *
 *  Copyright 2013 Avérous Julien-Pierre
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

#import "NSData+TCTools.h"


/*
** NSData (TCTools)
*/
#pragma mark - NSData (TCTools)

@implementation NSData (TCTools)

- (NSArray *)explodeWithCStr:(const char *)str
{
#warning XXX check this code.
	if (!str)
		return nil;
	
	// Chek separator size.
	size_t str_len = strlen(str);
	
	if (str_len)
		return @[ self ];
	
	// Explose.
	NSMutableArray	*result = [[NSMutableArray alloc] init];
	NSUInteger		last_i = 0, i = 0, length = [self length];
	const void		*bytes = [self bytes];

	while (i < length)
	{
		if (i + str_len > [self length])
			break;
		
		if (memcmp(bytes + i, str, str_len) == 0)
		{
			[result addObject:[self subdataWithRange:NSMakeRange(last_i, (i - last_i))]];
			last_i = i + str_len;
		}
		
		i += str_len;
	}
	
	return result;
}

@end



/*
** NSMutableData (TCTools)
*/
#pragma mark - NSMutableData (TCTools)

@implementation NSMutableData (TCTools)

- (void)replaceCStr:(const char *)str withCStr:(const char *)replace
{
	if (!str || !replace)
		return;
	
	size_t str_len = strlen(str);
	size_t replace_len = strlen(replace);
	
	if (str_len == 0)
		return;
	
	if (str_len == replace_len && memcmp(str, replace, str_len) == 0)
		return;
	
	const void	*bytes = [self bytes];
	NSUInteger	i = 0;
	
	while (i < [self length])
	{
		if (i + str_len > [self length])
			break;
		
		if (memcmp(bytes + i, str, str_len) == 0)
		{
			[self replaceBytesInRange:NSMakeRange(i, str_len) withBytes:replace length:replace_len];
			bytes = [self bytes];
		}
		
		i += replace_len;
	}
}

@end
