/*
 *  TCInfo.h
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


#import <Foundation/Foundation.h>


/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCInfoError,
	TCInfoWarning,
	TCInfoInfo
} TCInfoKind;



/*
** Forward
*/
#pragma mark - Forward

@class TCInfo;



/*
** TCInfo
*/
#pragma mark - TCInfo

@interface TCInfo : NSObject

// -- Properties --
@property (assign, nonatomic, readonly) TCInfoKind	kind;
@property (assign, nonatomic, readonly)	int			infoCode;
@property (strong, nonatomic, readonly)	id			context;
@property (strong, nonatomic)			NSString	*infoString;

// -- Instance --
+ (TCInfo *)infoOfKind:(TCInfoKind)kind infoCode:(int)code;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind infoCode:(int)code infoString:(NSString *)string;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind infoCode:(int)code infoString:(NSString *)string context:(id)context;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind infoCode:(int)code infoString:(NSString *)string info:(TCInfo *)info;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind infoCode:(int)code infoString:(NSString *)string context:(id)context info:(TCInfo *)info;

// -- Tools --
- (NSString *)render;

@end
