/*
 *  TCLogsController.m
 *
 *  Copyright 2012 Avérous Julien-Pierre
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
	NSMutableDictionary		*logs;
	NSMutableArray			*klogs;
	NSMutableDictionary		*kalias;
	
	NSMutableArray			*allLogs;			
	NSString				*allLastKey;
	
	NSMutableDictionary		*observers;
	
	NSCell					*separatorCell;
	NSCell					*textCell;
	
	dispatch_queue_t		mainQueue;
}

- (void)addLogEntry:(NSString *)key withContent:(NSString *)text;

@end



/*
** TCLogsController
*/
#pragma mark - TCLogsController

@implementation TCLogsController

@synthesize mainWindow;
@synthesize entriesView;
@synthesize logsView;


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
		mainQueue = dispatch_queue_create("com.torchat.cocoa.logs.main", DISPATCH_QUEUE_SERIAL);
		
		// Build logs containers
		logs = [[NSMutableDictionary alloc] init];
		klogs = [[NSMutableArray alloc] init];
		kalias = [[NSMutableDictionary alloc] init];
		allLogs = [[NSMutableArray alloc] init];
		
		[klogs addObject:TCLogsAllKey];
		[klogs addObject:TCLogsGlobalKey];
		
		// Build observers container
		observers = [[NSMutableDictionary alloc] init];
		
		// Build cell
		separatorCell = [[TCCellSeparator alloc] initTextCell:@""];
		textCell = [[NSTextFieldCell alloc] initTextCell:@""];
		
		// Load the nib
		[NSBundle loadNibNamed:@"LogsWindow" owner:self];
    }
    
    return self;
}

- (void)dealloc
{
	dispatch_release(mainQueue);
	
	[logs release];
	[klogs release];
	[kalias release];
	[allLogs release];
	
	[allLastKey release];
	
	[observers release];
    
    [super dealloc];
}



/*
** TCLogsController - Interface
*/
#pragma mark - TCLogsController - Interface

- (IBAction)showWindow:(id)sender
{
	[mainWindow makeKeyAndOrderFront:sender];
}



/*
** TCLogsController - NSTableView
*/
#pragma mark - TCLogsController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (aTableView == entriesView)
	{
		__block NSUInteger cnt = 0;
		
		dispatch_sync(mainQueue, ^{
			cnt = [klogs count];
		});
		
		return (NSInteger)cnt;
	}
	else if (aTableView == logsView)
	{
		NSInteger			kindex = [entriesView selectedRow];
		__block NSUInteger	cnt = 0;
		
		dispatch_sync(mainQueue, ^{
			
			if (kindex < 0 || kindex >= [klogs count])
				return;
			
			NSString *key = [klogs objectAtIndex:(NSUInteger)kindex];
			
			if ([key isEqualToString:TCLogsAllKey])
			{
				cnt = [allLogs count];
			}
			else if ([key isEqualToString:TCLogsGlobalKey])
			{
				cnt = [[logs objectForKey:TCLogsGlobalKey] count];
			}
			else if ([key isEqualToString:TCLogsSeparatorKey])
			{
				cnt = 0;
			}
			else
			{
				cnt = [[logs objectForKey:key] count];
			}
		});
		
		return (NSInteger)cnt;
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == entriesView)
	{
		__block NSString *str =  nil;
		
		dispatch_sync(mainQueue, ^{
			
			if (rowIndex < 0 || rowIndex > [klogs count])
				return ;
			
			NSString *key = [klogs objectAtIndex:(NSUInteger)rowIndex];
			
			if ([key isEqualToString:TCLogsAllKey])
				str = NSLocalizedString(@"logs_all_logs", @"");
			else if ([key isEqualToString:TCLogsGlobalKey])
				str = NSLocalizedString(@"logs_global_logs", @"");
			else
				str = [kalias objectForKey:key];
				
			[str retain];	
		});
		
		return [str autorelease];
	}
	else if (aTableView == logsView)
	{
		NSInteger			kindex = [entriesView selectedRow];
		__block NSString	*str =  nil;
		
		dispatch_sync(mainQueue, ^{
			
			if (kindex < 0 || kindex >= [klogs count])
				return;
			
			NSString *key = [klogs objectAtIndex:(NSUInteger)kindex];
			
			if ([key isEqualToString:TCLogsAllKey])
			{
				if (rowIndex < 0 || rowIndex >= [allLogs count])
					return;
				
				NSDictionary *item = [allLogs objectAtIndex:(NSUInteger)rowIndex];
				
				str = [item objectForKey:TCLogsContentKey];
				
				if ([[item objectForKey:TCLogsTitleKey] boolValue])
				{
					if ([str isEqualToString:TCLogsGlobalKey])
						str = NSLocalizedString(@"logs_global_logs", @"");
					else
						str = [NSString stringWithFormat:@"%@ (%@)", [kalias objectForKey:str], str];
				}
				
				[str retain];
			}
			else if ([key isEqualToString:TCLogsGlobalKey])
			{
				NSArray *array = [logs objectForKey:TCLogsGlobalKey];
				
				if (rowIndex < 0 || rowIndex >= [array count])
					return;
				
				str = [[array objectAtIndex:(NSUInteger)rowIndex] retain];
			}
			else if ([key isEqualToString:TCLogsSeparatorKey])
			{
			}
			else
			{
				NSArray *array = [logs objectForKey:key];
				
				if (rowIndex < 0 || rowIndex >= [array count])
					return;
				
				str = [[array objectAtIndex:(NSUInteger)rowIndex] retain];
			}
		});
		
		return [str autorelease];
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
	if (tableView == logsView)
	{
		__block BOOL result = NO;
		
		dispatch_sync(mainQueue, ^{
			
			NSInteger	kindex = [entriesView selectedRow];
			NSString	*key;
			
			if (kindex < 0 || kindex >= [klogs count])
				return;
			
			key = [klogs objectAtIndex:(NSUInteger)kindex];
						
			if ([key isEqualToString:TCLogsAllKey] == NO)
				return;
			
			NSDictionary *item = [allLogs objectAtIndex:(NSUInteger)rowIndex];
			
			result = [[item objectForKey:TCLogsTitleKey] boolValue];
		});
		
		return result;
	}
	
	return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)rowIndex
{
	if (tableView == entriesView)
	{
		__block CGFloat result = [tableView rowHeight];
		
		dispatch_sync(mainQueue, ^{
			
			NSString *key;
			
			if (rowIndex < 0 || rowIndex >= [klogs count])
				return;
			
			key = [klogs objectAtIndex:(NSUInteger)rowIndex];
			
			if ([key isEqualToString:TCLogsSeparatorKey])
				result = 2;
		});
		
		return result;
	}
	
	return [tableView rowHeight];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == entriesView)
	{
		__block NSCell *result = textCell;
		
		dispatch_sync(mainQueue, ^{

			NSString *key;
			
			if (rowIndex < 0 || rowIndex >= [klogs count])
				return;
			
			key = [klogs objectAtIndex:(NSUInteger)rowIndex];
		
			if ([key isEqualToString:TCLogsSeparatorKey])
				result = separatorCell;
			else
				result = textCell;
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
	if (aTableView == entriesView)
	{
		__block BOOL result = YES;
		
		dispatch_sync(mainQueue, ^{
			
			NSString *key;
			
			if (rowIndex < 0 || rowIndex >= [klogs count])
				return;
			
			key = [klogs objectAtIndex:(NSUInteger)rowIndex];
		
			if ([key isEqualToString:TCLogsSeparatorKey])
				result = NO;
		});
		
		return result;
	}
	else if (aTableView == logsView)
	{
		__block BOOL result = YES;
		
		dispatch_sync(mainQueue, ^{
			
			NSInteger	kindex = [entriesView selectedRow];
			NSString	*key;
			
			if (kindex < 0 || kindex > [klogs count])
				return;
			
			key = [klogs objectAtIndex:(NSUInteger)kindex];
			
			if ([key isEqualToString:TCLogsAllKey])
			{
				if (rowIndex < 0 || rowIndex >= [allLogs count])
					return;
				
				NSDictionary *item = [allLogs objectAtIndex:(NSUInteger)rowIndex];
				
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
		
		if (view == entriesView)
			[logsView reloadData];
	}
}



/*
** TCLogsController - Tools
*/
#pragma mark - TCLogsController - Tools

- (void)addLogEntry:(NSString *)key withContent:(NSString *)text
{
	// Hold it
	dispatch_async(mainQueue, ^{
		
		NSMutableArray *array = [logs objectForKey:key];
		
		// Build logs array for this key
		if (!array)
		{
			array = [[NSMutableArray alloc] init];
			
			[logs setObject:array forKey:key];
			
			// Add the if not global (already added)
			if ([key isEqualToString:TCLogsGlobalKey] == NO)
			{
				// Add separator
				if ([klogs count] == 2)
					[klogs addObject:TCLogsSeparatorKey];
				
				// Add the object
				[klogs addObject:key];
			}
			
			[array release];
		}
		
		
		// -- Add the log in the array --

		// > Remove first item if more than 500
		if ([array count] > 500)
			[array removeObjectAtIndex:0];
		
		// > Add
		[array addObject:text];
		
		
		
		// -- Add the item in the full log --

		// > Remove the first item (and item until we reach a title) if more than 2000
		if ([allLogs count] > 2000)
		{
			[allLogs removeObjectAtIndex:0];
			
			while ([allLogs count] > 0)
			{
				NSNumber *title = [[allLogs objectAtIndex:0] objectForKey:TCLogsTitleKey];
				
				if ([title boolValue])
					break;
				else
					[allLogs removeObjectAtIndex:0];
			}
		}
		
		// > Add the key as title if different than the previous one
		if (!allLastKey || [allLastKey isEqualToString:key] == NO)
		{
			[key retain];
			[allLastKey release];
			
			allLastKey = key;
			
			[allLogs addObject:[NSDictionary dictionaryWithObjectsAndKeys:key, TCLogsContentKey, [NSNumber numberWithBool:YES], TCLogsTitleKey, nil]];
		}
		
		// > Add
		[allLogs addObject:[NSDictionary dictionaryWithObject:text forKey:TCLogsContentKey]];
		
		
		// Give the item to the observer
		NSDictionary	*observer = [observers objectForKey:key];
		id				oobject = [observer objectForKey:@"object"];
		SEL				oselector = [[observer objectForKey:@"selector"] pointerValue];
		
		[oobject performSelector:oselector withObject:text];
				
		// Refresh
		dispatch_async(dispatch_get_main_queue(), ^{
			[entriesView reloadData]; 
			[logsView reloadData];
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
	dispatch_async(mainQueue, ^{
		[kalias setObject:alias forKey:address];
	});
	
	// Add the rendered log
	[self addLogEntry:address withContent:msg];
	
	// Release
	[msg release];
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
	
	// Release
	[msg release];
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
		
	// Release
	[msg release];
	[alert release];
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
	
	dispatch_async(mainQueue, ^{
		
		// Add it for this address
		[observers setObject:observer forKey:key];
		
		// Give the current content
		NSArray *items = [logs objectForKey:key];
		
		if (items)
			[object performSelector:selector withObject:items];
		
		[observer release];
	});
}

- (void)removeObserverForKey:(NSString *)key
{	
	dispatch_async(mainQueue, ^{
		[observers removeObjectForKey:key];
	});
}

@end
