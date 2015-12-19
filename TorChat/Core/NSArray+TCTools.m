/*
 *  NSArray+TCTools.m
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

#import "NSArray+TCTools.h"


/*
** NSArray (TCTools)
*/
#pragma mark - NSArray (TCTools)

@implementation NSArray (TCTools)

- (NSData *)joinWithCStr:(const char *)str
{
	return [self joinFromIndex:0 withCStr:str];
}

- (NSData *)joinFromIndex:(NSUInteger)index withCStr:(const char *)str
{
	NSMutableData	*result = [[NSMutableData alloc] init];
	NSUInteger		i, count = [self count];
	size_t			str_len = 0;
	
	if (str)
		str_len = strlen(str);
	
	for (i = index; i < count; i++)
	{
		id object = [self objectAtIndex:i];
		
		if ([object isKindOfClass:[NSString class]])
			object = [object dataUsingEncoding:NSUTF8StringEncoding];
		
		if ([object isKindOfClass:[NSData class]] == NO)
			continue;
		
		if ([result length] > 0 && str_len > 0)
			[result appendBytes:str length:str_len];
		
		[result appendData:object];
	}
	
	return result;
}

@end
