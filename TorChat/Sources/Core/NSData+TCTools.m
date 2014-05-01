/*
 *  NSData+TCTools.m
 *
 *  Copyright 2014 Avérous Julien-Pierre
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

- (NSArray *)explodeWithMaxFields:(NSUInteger)count withFieldSeparator:(const char *)separator
{
	// Check args.
	if (count == 0 || !separator)
		return nil;
	
	size_t sepSize = strlen(separator);
	
	if (sepSize == 0)
		return nil;
	
	const void		*bytes = [self bytes];
	NSUInteger		lasti, i;
	NSUInteger		length = [self length];
	NSUInteger		fields = 0;
	NSMutableArray	*result = [[NSMutableArray alloc] init];
	
	
	lasti = 0;
	i = 0;
	
	while (i < length)
	{
		if (i + sepSize > length)
			break;
		
		if (memcmp(bytes + i, separator, sepSize) == 0)
		{
			[result addObject:[NSData dataWithBytes:(bytes + lasti) length:(i - lasti)]];
			fields++;
			
			i += sepSize;
			lasti = i;
		}
		else
			i++;
		
		if (fields >= count)
			break;
	}
	
	if (length - lasti > 0)
		[result addObject:[NSData dataWithBytes:(bytes + lasti) length:(length - lasti)]];
	
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
			i += replace_len;
		}
		else
			i++;
	}
}



@end
