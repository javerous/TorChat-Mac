/*
 *  TCLogsController.h
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#import <Cocoa/Cocoa.h>



/*
** TCLogsController
*/
#pragma mark -
#pragma mark TCLogsController

@interface TCLogsController : NSObject
{
	IBOutlet NSWindow		*mainWindow;
	IBOutlet NSTableView	*entriesView;
	IBOutlet NSTableView	*logsView;
	
	dispatch_queue_t		mainQueue;

@private
    NSMutableDictionary		*logs;
	NSMutableArray			*klogs;
	NSMutableDictionary		*knames;

	NSMutableArray			*allLogs;			
	NSString				*allLastKey;
	
	NSMutableDictionary		*observers;
	
	NSCell					*separatorCell;
	NSCell					*textCell;
}

// -- Singleton --
+ (TCLogsController *)sharedController;

// -- Interface --
- (IBAction)showWindow:(id)sender;

// -- Tools --
- (void)addBuddyLogEntryFromAddress:(NSString *)address name:(NSString *)name andText:(NSString *)log, ...;
- (void)addGlobalLogEntry:(NSString *)log, ...;
- (void)addGlobalAlertLog:(NSString *)log, ...;

// -- Observer --
- (void)setObserver:(id)object withSelector:(SEL)selector forKey:(NSString *)key;
- (void)removeObserverForKey:(NSString *)key;


@end
