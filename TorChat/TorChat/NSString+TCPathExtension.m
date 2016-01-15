/*
 *  NSString+TCPathExtension.m
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

#import "NSString+TCPathExtension.h"


/*
** NSString - TCPathExtension
*/
#pragma mark - NSString - TCPathExtension

@implementation NSString (TCPathExtension)

- (NSString *)stringByCanonizingPath
{
	const char	*path = [self UTF8String];
	char		*rpath;
	NSString	*result;
	
	if (!path)
		return nil;
	
	rpath = realpath(path, NULL);
	
	if (!rpath)
		return nil;
	
	result = [NSString stringWithUTF8String:rpath];
	
	free(rpath);
	
	return result;
}


- (NSString *)stringWithPathRelativeTo:(NSString *)anchorPath
{
	// Code by Hilton Campbell / http://stackoverflow.com/questions/6539273/objective-c-code-to-generate-a-relative-path-given-a-file-and-a-directory
	
	NSArray *pathComponents = [self pathComponents];
	NSArray *anchorComponents = [anchorPath pathComponents];
	
	NSUInteger componentsInCommon = MIN([pathComponents count], [anchorComponents count]);
	
	for (NSUInteger i = 0, n = componentsInCommon; i < n; i++)
	{
		if (![[pathComponents objectAtIndex:i] isEqualToString:[anchorComponents objectAtIndex:i]])
		{
			componentsInCommon = i;
			break;
		}
	}
	
	NSUInteger numberOfParentComponents = [anchorComponents count] - componentsInCommon;
	NSUInteger numberOfPathComponents = [pathComponents count] - componentsInCommon;
	
	NSMutableArray *relativeComponents = [NSMutableArray arrayWithCapacity:numberOfParentComponents + numberOfPathComponents];
	
	for (NSInteger i = 0; i < numberOfParentComponents; i++)
	{
		[relativeComponents addObject:@".."];
	}
	
	[relativeComponents addObjectsFromArray: [pathComponents subarrayWithRange:NSMakeRange(componentsInCommon, numberOfPathComponents)]];
	
	return [NSString pathWithComponents:relativeComponents];
}

@end
