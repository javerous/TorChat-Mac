/*
 *  TCLogsManager.h
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
** Defines
*/
#pragma mark - Defines

#define TCLogsGlobalKey		@"_global_"



/*
** Forward
*/
#pragma mark - Forward

@class TCLogsManager;



/*
** TCLogsObserver
*/
@protocol TCLogsObserver <NSObject>

- (void)logManager:(TCLogsManager *)manager updateForKey:(NSString *)key withContent:(id)content;

@end



/*
** TCLogsManager
*/
#pragma mark - TCLogsManager

@interface TCLogsManager : NSObject

// -- Instance --
+ (TCLogsManager *)sharedManager;

// -- Logs --
- (void)addBuddyLogEntryFromAddress:(NSString *)address name:(NSString *)name andText:(NSString *)log, ...;
- (void)addGlobalLogEntry:(NSString *)log, ...;
- (void)addGlobalAlertLog:(NSString *)log, ...;



// -- Properties --
- (NSString *)nameForKey:(NSString *)key;

// -- Observer --
- (void)addObserver:(id <TCLogsObserver>)observer forKey:(NSString *)key; // observer is weak referenced.
- (void)removeObserverForKey:(NSString *)key;

@end
