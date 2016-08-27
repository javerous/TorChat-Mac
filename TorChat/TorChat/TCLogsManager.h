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


NS_ASSUME_NONNULL_BEGIN


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

@class SMInfo;



/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, TCLogKind) {
	TCLogError,
	TCLogWarning,
	TCLogInfo
};



/*
** TCLogsObserver
*/
@protocol TCLogsObserver <NSObject>

- (void)logManager:(TCLogsManager *)manager updatedKey:(NSString *)key updatedEntries:(NSArray *)entries;

@end



/*
** TCLogsManager
*/
#pragma mark - TCLogsManager

@interface TCLogsManager : NSObject

// -- Instance --
+ (TCLogsManager *)sharedManager;

// -- Logs --
- (void)addBuddyLogWithBuddyIdentifier:(NSString *)identifier name:(nullable NSString *)name kind:(TCLogKind)kind message:(NSString *)message, ...;
- (void)addBuddyLogWithBuddyIdentifier:(NSString *)identifier name:(nullable NSString *)name info:(SMInfo *)info;

- (void)addGlobalLogWithKind:(TCLogKind)kind message:(NSString *)message, ...;
- (void)addGlobalLogWithInfo:(SMInfo *)info;

// -- Properties --
- (nullable NSString *)nameForKey:(NSString *)key;

// -- Observer --
- (void)addObserver:(id <TCLogsObserver>)observer forKey:(nullable NSString *)key; // observer is weak referenced.
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


NS_ASSUME_NONNULL_END
