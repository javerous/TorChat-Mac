/*
 *  TCInfo.m
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

#import "TCInfo.h"


/*
** TCInfo - Private
*/
#pragma mark - TCInfo - Private

@interface TCInfo ()
{
	NSDate *_date;
	TCInfo *_info;
}

// -- Properties (RW) --
@property (assign, nonatomic) tcinfo_kind	kind;
@property (assign, nonatomic) int			infoCode;
@property (strong, nonatomic) id			context;

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

+ (TCInfo *)infoOfKind:(tcinfo_kind)kind infoCode:(int)code
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.infoCode = code;
	
	return info;
}

+ (TCInfo *)infoOfKind:(tcinfo_kind)kind infoCode:(int)code infoString:(NSString *)string
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.infoCode = code;
	info.infoString = string;
	
	return info;
}

+ (TCInfo *)infoOfKind:(tcinfo_kind)kind infoCode:(int)code infoString:(NSString *)string context:(id)context
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.infoCode = code;
	info.infoString = string;
	info.context = context;
	
	return info;
}

+ (TCInfo *)infoOfKind:(tcinfo_kind)kind infoCode:(int)code infoString:(NSString *)string info:(TCInfo *)sinfo
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.infoCode = code;
	info.infoString = string;
	info->_info = sinfo;
	
	return info;
}

+ (TCInfo *)infoOfKind:(tcinfo_kind)kind infoCode:(int)code infoString:(NSString *)string context:(id)context info:(TCInfo *)sinfo
{
	TCInfo *info = [[TCInfo alloc] init];
	
	info.kind = kind;
	info.infoCode = code;
	info.infoString = string;
	info.context = context;
	info->_info = sinfo;
	
	return info;
}

- (id)init
{
    self = [super init];
	
    if (self)
	{
		_date = [NSDate date];
    }
	
    return self;
}


/*
** TCInfo - Tools
*/
#pragma mark - TCInfo - Tools

- (NSString *)render
{
	NSMutableString	*result = [[NSMutableString alloc] init];
	
	// Add the log time.
	[result appendString:[_date description]];
	
	// Add the errcode
	[result appendFormat:@" - [%i]: ", _infoCode];
	
	// Add the info string
	if (_infoString)
		[result appendString:_infoString];
	
	// Ad the sub-info
	if (_info)
	{
		[result appendString:@" "];
		[result appendString:[_info _render]];
	}
		 
	return result;
}

- (NSString *)_render
{
	NSMutableString *result = [[NSMutableString alloc] init];
	
	// Add the errcode and the info
	[result appendFormat:@"{%i - ", _infoCode];
	 
	[result appendString:_infoString];
	
	 // Add the sub-info
	 if (_info)
	 {
		 [result appendString:@" "];
		 [result appendString:[_info _render]];
	 }
	 
	 [result appendString:@"}"];
	 
	 return result;
}

@end
