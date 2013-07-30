/*
 *  TCLogsController.m
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import "TCLogsController.h"

#define TCLogsAllKey		@"_all_"
#define TCLogsGlobalKey		@"_global_"
#define TCLogsSeparatorKey	@"_separator_"

#define TCLogsContentKey	@"content"
#define TCLogsTitleKey		@"title"



/*
** TCCellSeparator
*/
#pragma mark - TCCellSeparator

@interface TCCellSeparator : NSCell

@end


@implementation TCCellSeparator

- (id)initTextCell:(NSString *)aString
{
	self = [super initTextCell:@""];
	
	if (self)
	{
	}
	
	return self;
}

- (id)initImageCell:(NSImage *)anImage
{
	self = [super initImageCell:nil];
	
	if (self)
	{
	}
	
	return self;
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView
{
	float			height = 1;
	NSRect			rpath = NSMakeRect(cellFrame.origin.x + 3, cellFrame.origin.y + (cellFrame.size.height - height) / 2.0f, cellFrame.size.width - 6, height);
	NSBezierPath	*path = [NSBezierPath bezierPathWithRect:rpath];
	
	[[NSColor grayColor] set];
	
	[path fill];
}

@end



/*
** TCLogsController - Private
*/
#pragma mark - TCLogsController - Private

@interface TCLogsController ()
{
	NSMutableDictionary		*_logs;
	NSMutableArray			*_klogs;
	NSMutableDictionary		*_kalias;
	
	NSMutableArray			*_allLogs;
	NSString				*_allLastKey;
	
	NSMutableDictionary		*_observers;
	
	NSCell					*_separatorCell;
	NSCell					*_textCell;
	
	dispatch_queue_t		_localQueue;
}

- (void)addLogEntry:(NSString *)key withContent:(NSString *)text;

@end



/*
** TCLogsController
*/
#pragma mark - TCLogsController

@implementation TCLogsController


/*
** TCLogsController - Constructor & Destructor
*/
#pragma mark - TCLogsController - Constructor & Destructor

+ (TCLogsController *)sharedController
{
	static dispatch_once_t	pred;
	static TCLogsController	*shr;
	
	dispatch_once(&pred, ^{
		shr = [[TCLogsController alloc] init];
	});
	
	return shr;
}

- (id)init
{
	self = [super init];
	
    if (self)
	{
		// Build a working queue
		_localQueue = dispatch_queue_create("com.torchat.cocoa.logs.local", DISPATCH_QUEUE_SERIAL);
		
		// Build logs containers
		_logs = [[NSMutableDictionary alloc] init];
		_klogs = [[NSMutableArray alloc] init];
		_kalias = [[NSMutableDictionary alloc] init];
		_allLogs = [[NSMutableArray alloc] init];
		
		[_klogs addObject:TCLogsAllKey];
		[_klogs addObject:TCLogsGlobalKey];
		
		// Build observers container
		_observers = [[NSMutableDictionary alloc] init];
		
		// Build cell
		_separatorCell = [[TCCellSeparator alloc] initTextCell:@""];
		_textCell = [[NSTextFieldCell alloc] initTextCell:@""];
		
		// Load the nib
		[[NSBundle mainBundle] loadNibNamed:@"LogsWindow" owner:self topLevelObjects:nil];
    }
    
    return self;
}



/*
** TCLogsController - Interface
*/
#pragma mark - TCLogsController - Interface

- (IBAction)showWindow:(id)sender
{
	[_mainWindow makeKeyAndOrderFront:sender];
}



/*
** TCLogsController - NSTableView
*/
#pragma mark - TCLogsController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
#warning FIXME: klog should duplicated in main queue. using another queue there is not a good idea.
	if (aTableView == _entriesView)
	{
		__block NSUInteger cnt = 0;
		
		dispatch_sync(_localQueue, ^{
			cnt = [_klogs count];
		});
		
		return (NSInteger)cnt;
	}
	else if (aTableView == _logsView)
	{
		NSInteger			kindex = [_entriesView selectedRow];
		__block NSUInteger	cnt = 0;
		
		dispatch_sync(_localQueue, ^{
			
			if (kindex < 0 || kindex >= [_klogs count])
				return;
			
			NSString *key = [_klogs objectAtIndex:(NSUInteger)kindex];
			
			if ([key isEqualToString:TCLogsAllKey])
			{
				cnt = [_allLogs count];
			}
			else if ([key isEqualToString:TCLogsGlobalKey])
			{
				cnt = [[_logs objectForKey:TCLogsGlobalKey] count];
			}
			else if ([key isEqualToString:TCLogsSeparatorKey])
			{
				cnt = 0;
			}
			else
			{
				cnt = [[_logs objectForKey:key] count];
			}
		});
		
		return (NSInteger)cnt;
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == _entriesView)
	{
		__block NSString *str =  nil;
		
		dispatch_sync(_localQueue, ^{
			
			if (rowIndex < 0 || rowIndex > [_klogs count])
				return ;
			
			NSString *key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
			
			if ([key isEqualToString:TCLogsAllKey])
				str = NSLocalizedString(@"logs_all_logs", @"");
			else if ([key isEqualToString:TCLogsGlobalKey])
				str = NSLocalizedString(@"logs_global_logs", @"");
			else
				str = [_kalias objectForKey:key];
		});
		
		return str;
	}
	else if (aTableView == _logsView)
	{
		NSInteger			kindex = [_entriesView selectedRow];
		__block NSString	*str =  nil;
		
		dispatch_sync(_localQueue, ^{
			
			if (kindex < 0 || kindex >= [_klogs count])
				return;
			
			NSString *key = [_klogs objectAtIndex:(NSUInteger)kindex];
			
			if ([key isEqualToString:TCLogsAllKey])
			{
				if (rowIndex < 0 || rowIndex >= [_allLogs count])
					return;
				
				NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
				
				str = [item objectForKey:TCLogsContentKey];
				
				if ([[item objectForKey:TCLogsTitleKey] boolValue])
				{
					if ([str isEqualToString:TCLogsGlobalKey])
						str = NSLocalizedString(@"logs_global_logs", @"");
					else
						str = [NSString stringWithFormat:@"%@ (%@)", [_kalias objectForKey:str], str];
				}
			}
			else if ([key isEqualToString:TCLogsGlobalKey])
			{
				NSArray *array = [_logs objectForKey:TCLogsGlobalKey];
				
				if (rowIndex < 0 || rowIndex >= [array count])
					return;
				
				str = [array objectAtIndex:(NSUInteger)rowIndex];
			}
			else if ([key isEqualToString:TCLogsSeparatorKey])
			{
			}
			else
			{
				NSArray *array = [_logs objectForKey:key];
				
				if (rowIndex < 0 || rowIndex >= [array count])
					return;
				
				str = [array objectAtIndex:(NSUInteger)rowIndex];
			}
		});
		
		return str;
	}
	
	return nil;
}

/*
- (void)tableView:(NSTableView *)aTableView willDisplayCell:(id)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
}
*/

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)rowIndex
{
	if (tableView == _logsView)
	{
		__block BOOL result = NO;
		
		dispatch_sync(_localQueue, ^{
			
			NSInteger	kindex = [_entriesView selectedRow];
			NSString	*key;
			
			if (kindex < 0 || kindex >= [_klogs count])
				return;
			
			key = [_klogs objectAtIndex:(NSUInteger)kindex];
						
			if ([key isEqualToString:TCLogsAllKey] == NO)
				return;
			
			NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
			
			result = [[item objectForKey:TCLogsTitleKey] boolValue];
		});
		
		return result;
	}
	
	return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)rowIndex
{
	if (tableView == _entriesView)
	{
		__block CGFloat result = [tableView rowHeight];
		
		dispatch_sync(_localQueue, ^{
			
			NSString *key;
			
			if (rowIndex < 0 || rowIndex >= [_klogs count])
				return;
			
			key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
			
			if ([key isEqualToString:TCLogsSeparatorKey])
				result = 2;
		});
		
		return result;
	}
	
	return [tableView rowHeight];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == _entriesView)
	{
		__block NSCell *result = _textCell;
		
		dispatch_sync(_localQueue, ^{

			NSString *key;
			
			if (rowIndex < 0 || rowIndex >= [_klogs count])
				return;
			
			key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
		
			if ([key isEqualToString:TCLogsSeparatorKey])
				result = _separatorCell;
			else
				result = _textCell;
		});
		
		return result;
	}
	
	return [tableColumn dataCell];
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	return NO;
}

- (BOOL)tableView:(NSTableView *)aTableView shouldSelectRow:(NSInteger)rowIndex
{
	if (aTableView == _entriesView)
	{
		__block BOOL result = YES;
		
		dispatch_sync(_localQueue, ^{
			
			NSString *key;
			
			if (rowIndex < 0 || rowIndex >= [_klogs count])
				return;
			
			key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
		
			if ([key isEqualToString:TCLogsSeparatorKey])
				result = NO;
		});
		
		return result;
	}
	else if (aTableView == _logsView)
	{
		__block BOOL result = YES;
		
		dispatch_sync(_localQueue, ^{
			
			NSInteger	kindex = [_entriesView selectedRow];
			NSString	*key;
			
			if (kindex < 0 || kindex > [_klogs count])
				return;
			
			key = [_klogs objectAtIndex:(NSUInteger)kindex];
			
			if ([key isEqualToString:TCLogsAllKey])
			{
				if (rowIndex < 0 || rowIndex >= [_allLogs count])
					return;
				
				NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
				
				result = ![[item objectForKey:TCLogsTitleKey] boolValue];
			}
		});
		
		return result;
	}
	
	return YES;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{	
	id object = [aNotification object];
	
	if ([object isKindOfClass:[NSTableView class]])
	{
		NSTableView *view = object;
		
		if (view == _entriesView)
			[_logsView reloadData];
	}
}



/*
** TCLogsController - Tools
*/
#pragma mark - TCLogsController - Tools

- (void)addLogEntry:(NSString *)key withContent:(NSString *)text
{
	// Hold it
	dispatch_async(_localQueue, ^{
		
		NSMutableArray *array = [_logs objectForKey:key];
		
		// Build logs array for this key
		if (!array)
		{
			array = [[NSMutableArray alloc] init];
			
			[_logs setObject:array forKey:key];
			
			// Add the if not global (already added)
			if ([key isEqualToString:TCLogsGlobalKey] == NO)
			{
				// Add separator
				if ([_klogs count] == 2)
					[_klogs addObject:TCLogsSeparatorKey];
				
				// Add the object
				[_klogs addObject:key];
			}
		}
		
		
		// -- Add the log in the array --
		// > Remove first item if more than 500
		if ([array count] > 500)
			[array removeObjectAtIndex:0];
		
		// > Add
		[array addObject:text];
		
		
		
		// -- Add the item in the full log --
		// > Remove the first item (and item until we reach a title) if more than 2000
		if ([_allLogs count] > 2000)
		{
			[_allLogs removeObjectAtIndex:0];
			
			while ([_allLogs count] > 0)
			{
				NSNumber *title = [[_allLogs objectAtIndex:0] objectForKey:TCLogsTitleKey];
				
				if ([title boolValue])
					break;
				else
					[_allLogs removeObjectAtIndex:0];
			}
		}
		
		// > Add the key as title if different than the previous one
		if (!_allLastKey || [_allLastKey isEqualToString:key] == NO)
		{
			_allLastKey = key;
			
			[_allLogs addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, TCLogsContentKey, [NSNumber numberWithBool:YES], TCLogsTitleKey, nil]];
		}
		
		// > Add
		[_allLogs addObject:[NSDictionary dictionaryWithObject:text forKey:TCLogsContentKey]];
		
		// Give the item to the observer
		NSDictionary	*observer = [_observers objectForKey:key];
		id				oobject = [observer objectForKey:@"object"];
		SEL				oselector = [[observer objectForKey:@"selector"] pointerValue];
		
		[oobject performSelector:oselector withObject:text];
				
		// Refresh
		dispatch_async(dispatch_get_main_queue(), ^{
			[_entriesView reloadData];
			[_logsView reloadData];
		});
	});
}

- (void)addBuddyLogEntryFromAddress:(NSString *)address alias:(NSString *)alias andText:(NSString *)log, ...
{
	va_list		ap;
	NSString	*msg;
	
	// Render string
	va_start(ap, log);
	
	msg = [[NSString alloc] initWithFormat:NSLocalizedString(log, @"") arguments:ap];
	
	va_end(ap);
	
	// Add the alias
	dispatch_async(_localQueue, ^{
		[_kalias setObject:alias forKey:address];
	});
	
	// Add the rendered log
	[self addLogEntry:address withContent:msg];
}

- (void)addGlobalLogEntry:(NSString *)log, ...
{
	va_list		ap;
	NSString	*msg;
	
	// Render the full string
	va_start(ap, log);
	
	msg = [[NSString alloc] initWithFormat:NSLocalizedString(log, @"") arguments:ap];
	
	va_end(ap);
	
	// Add the log
	[self addLogEntry:TCLogsGlobalKey withContent:msg];
}

- (void)addGlobalAlertLog:(NSString *)log, ...
{
	va_list		ap;
	NSString	*msg;
	
	// Render the full string
	va_start(ap, log);
	
	msg = [[NSString alloc] initWithFormat:NSLocalizedString(log, @"") arguments:ap];
	
	va_end(ap);
	
	// Add the log
	[self addLogEntry:TCLogsGlobalKey withContent:msg];
	
	// Show alert
	NSAlert *alert = [[NSAlert alloc] init];
	
	[alert setMessageText:NSLocalizedString(@"logs_error_title", @"")];
	[alert setInformativeText:msg];
	
	[alert runModal];
}



/*
** TCLogsController - Observer
*/
#pragma mark - TCLogsController - Observer

- (void)setObserver:(id)object withSelector:(SEL)selector forKey:(NSString *)key
{
	if (!key || !object || !selector)
		return;
		
	// Build obserever item
	NSDictionary *observer = [[NSDictionary alloc] initWithObjectsAndKeys:object, @"object", [NSValue valueWithPointer:selector], @"selector", nil];
	
	dispatch_async(_localQueue, ^{
		
		// Add it for this address
		[_observers setObject:observer forKey:key];
		
		// Give the current content
		NSArray *items = [_logs objectForKey:key];
		
		if (items)
			[object performSelector:selector withObject:items];
	});
}

- (void)removeObserverForKey:(NSString *)key
{	
	dispatch_async(_localQueue, ^{
		[_observers removeObjectForKey:key];
	});
}

@end
