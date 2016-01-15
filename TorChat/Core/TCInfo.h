/*
 *  TCInfo.h
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

#import <Foundation/Foundation.h>


/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCInfoInfo,
	TCInfoWarning,
	TCInfoError,
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

@property (strong, nonatomic, readonly) NSString	*domain;
@property (assign, nonatomic, readonly)	int			code;
@property (strong, nonatomic, readonly)	id			context;

@property (strong, nonatomic, readonly) NSDate		*timestamp;

@property (strong, nonatomic, readonly) TCInfo		*subInfo;


// -- Instance --
+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code context:(id)context;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code info:(TCInfo *)info;
+ (TCInfo *)infoOfKind:(TCInfoKind)kind domain:(NSString *)domain code:(int)code context:(id)context info:(TCInfo *)info;

@end
