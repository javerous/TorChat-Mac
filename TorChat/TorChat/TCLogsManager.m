/*
 *  TCLogsManager.m
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

#import "TCLogsManager.h"

#import "TCInfo.h"
#import "TCInfo+Render.h"


/*
** TCLogEntry - Private
*/
#pragma mark - TCLogEntry - Private

@interface TCLogEntry ()

+ (instancetype)logEntryWithKind:(TCLogKind)kind message:(NSString *)message;
+ (instancetype)logEntryWithTimestamp:(NSDate *)timestamp kind:(TCLogKind)kind message:(NSString *)message;

@end

@implementation TCLogEntry

+ (instancetype)logEntryWithKind:(TCLogKind)kind message:(NSString *)message
{
	return [self logEntryWithTimestamp:nil kind:kind message:message];
}

+ (instancetype)logEntryWithTimestamp:(NSDate *)timestamp kind:(TCLogKind)kind message:(NSString *)message
{
	TCLogEntry *entry = [[TCLogEntry alloc] init];

	if (!message)
		message = @"";
	
	if (!timestamp)
		timestamp = [NSDate date];
	
	entry->_timestamp = timestamp;
	entry->_kind = kind;
	entry->_message = message;
	
	return entry;
}

@end




/*
** TCLogsManager
*/
#pragma mark - TCLogsManager

@implementation TCLogsManager
{
	dispatch_queue_t		_localQueue;
	dispatch_queue_t		_observerQueue;
	
	NSMapTable				*_keyObservers;
	NSHashTable				*_allObserver;
	
	NSMutableDictionary		*_logs;
	NSMutableDictionary		*_names;
}


/*
** TCLogsManager - Instance
*/
#pragma mark - TCLogsManager - Instance

+ (TCLogsManager *)sharedManager
{
	static dispatch_once_t	onceToken;
	static TCLogsManager	*shr;
	
	dispatch_once(&onceToken, ^{
		shr = [[TCLogsManager alloc] init];
	});
	
	return shr;
}

- (id)init
{
    self = [super init];
	
    if (self)
	{
		// Create queue.
        _localQueue = dispatch_queue_create("com.torchat.app.logmanager.local", DISPATCH_QUEUE_SERIAL);
		_observerQueue = dispatch_queue_create("com.torchat.app.logmanager.observer", DISPATCH_QUEUE_SERIAL);
		
		// Build observers container.
		_keyObservers = [NSMapTable strongToWeakObjectsMapTable];
		_allObserver = [NSHashTable weakObjectsHashTable];
		
		// Build containers.
		_logs = [[NSMutableDictionary alloc] init];
		_names = [[NSMutableDictionary alloc] init];
    }
	
    return self;
}



/*
** TCLogsWindowController - Logs
*/
#pragma mark - TCLogsWindowController - Logs

- (void)addLogWithTimestamp:(NSDate *)timestamp key:(NSString *)key kind:(TCLogKind)kind content:(NSString *)content
{
	dispatch_sync(_localQueue, ^{
		
		// Create entry.
		TCLogEntry *entry = [TCLogEntry logEntryWithTimestamp:timestamp kind:kind message:content];
		
		// Build logs array for this key
		NSMutableArray *logs = [_logs objectForKey:key];

		if (!logs)
		{
			logs = [[NSMutableArray alloc] init];
			
			[_logs setObject:logs forKey:key];
		}
		
		// Add the log in the array.
		// > Remove first item if more than 500.
		if ([logs count] > 500)
			[logs removeObjectAtIndex:0];
		
		// > Add.
		[logs addObject:entry];
		
		// Give the item to the observers.
		// > Keyed observer.
		id <TCLogsObserver> kobserver = [_keyObservers objectForKey:key];
		
		if (kobserver)
		{
			dispatch_sync(_observerQueue, ^{
				[kobserver logManager:self updateForKey:key withEntries:@[entry]];
			});
		}
		
		// > Global observer.
		for (id <TCLogsObserver> observer in _allObserver)
		{
			dispatch_sync(_observerQueue, ^{
				[observer logManager:self updateForKey:key withEntries:@[entry]];
			});
		}
	});
}

- (void)addBuddyLogWithAddress:(NSString *)address name:(NSString *)name kind:(TCLogKind)kind message:(NSString *)message, ...
{
	va_list		ap;
	NSString	*msg;
	
	// Render string
	va_start(ap, message);
	
	msg = [[NSString alloc] initWithFormat:NSLocalizedString(message, @"") arguments:ap];
	
	va_end(ap);
	
	// Add the alias
	dispatch_async(_localQueue, ^{
		[_names setObject:name forKey:address];
	});
		
	// Add the rendered log.
	[self addLogWithTimestamp:nil key:address kind:kind content:msg];
}

- (void)addBuddyLogWithAddress:(NSString *)address name:(NSString *)name info:(TCInfo *)info
{
	// Add the alias
	dispatch_async(_localQueue, ^{
		[_names setObject:name forKey:address];
	});
	
	// Convert kind.
	TCLogKind kind;
	
	switch (info.kind)
	{
		case TCInfoError:
			kind = TCLogError;
			break;

		case TCInfoWarning:
			kind = TCLogWarning;
			break;

		case TCInfoInfo:
			kind = TCLogInfo;
			break;
	}
	
	// Add the rendered log.
	[self addLogWithTimestamp:info.timestamp key:address kind:kind content:[info renderComplete]];
}


- (void)addGlobalLogWithKind:(TCLogKind)kind message:(NSString *)message, ...
{
	va_list		ap;
	NSString	*msg;
	
	// Render the full string
	va_start(ap, message);
	
	msg = [[NSString alloc] initWithFormat:NSLocalizedString(message, @"") arguments:ap];
	
	va_end(ap);
	
	// Add the log
	[self addLogWithTimestamp:nil key:TCLogsGlobalKey kind:kind content:msg];
}

- (void)addGlobalLogWithInfo:(TCInfo *)info;
{
	// Convert kind.
	TCLogKind kind;
	
	switch (info.kind)
	{
		case TCInfoError:
			kind = TCLogError;
			break;
			
		case TCInfoWarning:
			kind = TCLogWarning;
			break;
			
		case TCInfoInfo:
			kind = TCLogInfo;
			break;
	}
	
	// Add the log
	[self addLogWithTimestamp:info.timestamp key:TCLogsGlobalKey kind:kind content:[info renderComplete]];
}

- (NSArray *)allKeys
{
	__block NSArray *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = [_logs allKeys];
	});
	
	return result;
}

- (NSArray *)logsForKey:(NSString *)key
{
	if (!key)
		return nil;
	
	__block NSArray *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = [_logs[key] copy];
	});
	
	return result;
}



/*
** TCLogsWindowController - Properties
*/
#pragma mark - TCLogsWindowController - Properties

- (NSString *)nameForKey:(NSString *)key
{
	if (!key)
		return nil;
	
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = _names[key];
	});
	
	return result;
}



/*
** TCLogsWindowController - Observer
*/
#pragma mark - TCLogsWindowController - Observer

- (void)addObserver:(id <TCLogsObserver>)observer forKey:(NSString *)key
{
	if (!observer)
		return;
	
	// Build obserever item
	dispatch_async(_localQueue, ^{
		
		// Add it for this address
		if (key)
			[_keyObservers setObject:observer forKey:key];
		else
			[_allObserver addObject:observer];
		
		// Give the current content
		if (key)
		{
			NSArray *items = [[_logs objectForKey:key] copy];
		
			if (items)
			{
				dispatch_async(_observerQueue, ^{
					[observer logManager:self updateForKey:key withEntries:items];
				});
			}
		}
		else
		{
			for (NSString *akey in _logs)
			{
				NSArray *items = [[_logs objectForKey:akey] copy];
		
				dispatch_async(_observerQueue, ^{
					[observer logManager:self updateForKey:akey withEntries:items];
				});
			}
		}
	});
}

- (void)removeObserverForKey:(NSString *)key
{
	if (!key)
		return;
	
	dispatch_async(_localQueue, ^{
		[_keyObservers removeObjectForKey:key];
	});
}

@end
