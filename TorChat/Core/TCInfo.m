/*
 *  TCInfo.m
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

#import "TCInfo.h"


/*
** TCInfo - Private
*/
#pragma mark - TCInfo - Private

@interface TCInfo ()

// -- Properties (RW) --
@property (assign, nonatomic) TCInfoKind	kind;
@property (strong, nonatomic) NSString		*domain;
@property (assign, nonatomic) int			code;
@property (strong, nonatomic) id			context;
@property (strong, nonatomic) TCInfo		*subInfo;

@end



/*
** TCInfo
*/
#pragma mark - TCInfo

@implementation TCInfo


/*
** TCInfo - Instance
*/
#pragma mark - TCInfo - Instance

+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	
	return info;
}

+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code context:(id)context
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	info.context = context;
	
	return info;
}

+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code info:(TCInfo *)sinfo
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	info.subInfo = sinfo;
	
	return info;
}

+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code context:(id)context info:(TCInfo *)sinfo
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.domain = domain;
	info.code = code;
	info.context = context;
	info.subInfo = sinfo;
	
	return info;
}

- (id)init
{
    self = [super init];
	
    if (self)
	{
		_timestamp = [NSDate date];
    }
	
    return self;
}

@end
