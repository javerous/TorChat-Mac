/*
 *  TCValue.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

#import "TCValue.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCValue
*/
#pragma mark - TCValue

@implementation TCValue
{
	__weak id _object;
}

+ (TCValue *)valueWithWeakObject:(id)object
{
	return [[[self class] alloc] initWithWeakObject:object];
}

- (instancetype)initWithWeakObject:(id)object
{
	self = [super init];
	
	if (self)
	{
		_object = object;
	}
	
	return self;
}

- (nullable id)object
{
	return _object;
}

@end


NS_ASSUME_NONNULL_END
