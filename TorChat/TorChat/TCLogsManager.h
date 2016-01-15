/*
 *  TCLogsManager.h
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
** Defines
*/
#pragma mark - Defines

#define TCLogsGlobalKey		@"_global_"



/*
** Forward
*/
#pragma mark - Forward

@class TCLogsManager;
@class TCLogEntry;

@class TCInfo;



/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCLogError,
	TCLogWarning,
	TCLogInfo
} TCLogKind;



/*
** TCLogsObserver
*/
@protocol TCLogsObserver <NSObject>

- (void)logManager:(TCLogsManager *)manager updateForKey:(NSString *)key withEntries:(NSArray *)entries;

@end



/*
** TCLogsManager
*/
#pragma mark - TCLogsManager

@interface TCLogsManager : NSObject

// -- Instance --
+ (TCLogsManager *)sharedManager;

// -- Logs --
- (void)addBuddyLogWithAddress:(NSString *)address name:(NSString *)name kind:(TCLogKind)kind message:(NSString *)message, ...;
- (void)addBuddyLogWithAddress:(NSString *)address name:(NSString *)name info:(TCInfo *)info;

- (void)addGlobalLogWithKind:(TCLogKind)kind message:(NSString *)message, ...;
- (void)addGlobalLogWithInfo:(TCInfo *)info;


// -- Properties --
- (NSString *)nameForKey:(NSString *)key;

// -- Observer --
- (void)addObserver:(id <TCLogsObserver>)observer forKey:(NSString *)key; // observer is weak referenced.
- (void)removeObserverForKey:(NSString *)key;

@end



/*
** TCLogEntry
*/
#pragma mark - TCLogEntry

@interface TCLogEntry : NSObject

@property (readonly, nonatomic) TCLogKind	kind;
@property (readonly, nonatomic) NSDate		*timestamp;
@property (readonly, nonatomic) NSString	*message;

@end
