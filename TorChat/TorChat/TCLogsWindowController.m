/*
 *  TCLogsWindowController.m
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

#import "TCLogsWindowController.h"

#import "TCLogsManager.h"

#define TCLogsAllKey		@"_all_"
#define TCLogsSeparatorKey	@"_separator_"

#define TCLogsEntryKey		@"entry"
#define TCLogsTextKey		@"text"

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
** TCLogsWindowController - Private
*/
#pragma mark - TCLogsWindowController - Private

@interface TCLogsWindowController () <TCLogsObserver>
{
	NSMutableDictionary		*_logs;
	NSMutableArray			*_klogs;
	
	NSMutableArray			*_allLogs;
	NSString				*_allLastKey;
	
	NSCell					*_separatorCell;
	NSCell					*_textCell;
	
	NSDateFormatter			*_dateFormatter;
}

// -- Properties --
@property (strong, atomic) IBOutlet NSTableView	*entriesView;
@property (strong, atomic) IBOutlet NSTableView	*logsView;

- (void)addLogEntries:(NSArray *)entries forKey:(NSString *)key;

@end



/*
** TCLogsWindowController
*/
#pragma mark - TCLogsWindowController

@implementation TCLogsWindowController


/*
** TCLogsWindowController - Instance
*/
#pragma mark - TCLogsWindowController - Instance

+ (TCLogsWindowController *)sharedController
{
	static dispatch_once_t	pred;
	static TCLogsWindowController	*shr;
	
	dispatch_once(&pred, ^{
		shr = [[TCLogsWindowController alloc] init];
	});
	
	return shr;
}

- (id)init
{
	self = [super initWithWindowNibName:@"LogsWindow"];
	
    if (self)
	{
		// Build logs containers.
		_logs = [[NSMutableDictionary alloc] init];
		_klogs = [[NSMutableArray alloc] init];
		_allLogs = [[NSMutableArray alloc] init];
		
		[_klogs addObject:TCLogsAllKey];
		[_klogs addObject:TCLogsGlobalKey];
		
		// Build cell.
		_separatorCell = [[TCCellSeparator alloc] initTextCell:@""];
		_textCell = [[NSTextFieldCell alloc] initTextCell:@""];
		
		// Date formatter.
		_dateFormatter = [[NSDateFormatter alloc] init];
		
		[_dateFormatter setDateStyle:NSDateFormatterShortStyle];
		[_dateFormatter setTimeStyle:NSDateFormatterMediumStyle];
		
		// Add logs observer.
		[[TCLogsManager sharedManager] addObserver:self forKey:nil];
    }
    
    return self;
}

- (void)windowDidLoad
{
	// Place Window.
	[self.window center];
	[self.window setFrameAutosaveName:@"LogsWindow"];
}



/*
** TCLogsWindowController - NSTableView
*/
#pragma mark - TCLogsWindowController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	if (aTableView == _entriesView)
	{
		return (NSInteger)[_klogs count];
	}
	else if (aTableView == _logsView)
	{
		NSInteger kindex = [_entriesView selectedRow];
		
		if (kindex < 0 || kindex >= [_klogs count])
			return 0;
			
		NSString *key = [_klogs objectAtIndex:(NSUInteger)kindex];
		
		if ([key isEqualToString:TCLogsAllKey])
		{
			return (NSInteger)[_allLogs count];
		}
		else if ([key isEqualToString:TCLogsGlobalKey])
		{
			return (NSInteger)[[_logs objectForKey:TCLogsGlobalKey] count];
		}
		else if ([key isEqualToString:TCLogsSeparatorKey])
		{
			return 0;
		}
		else
		{
			return (NSInteger)[[_logs objectForKey:key] count];
		}
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{
	if (aTableView == _entriesView)
	{
		if (rowIndex < 0 || rowIndex > [_klogs count])
			return nil;
		
		NSString *key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
		
		if ([key isEqualToString:TCLogsAllKey])
			return NSLocalizedString(@"logs_all_logs", @"");
		else if ([key isEqualToString:TCLogsGlobalKey])
			return NSLocalizedString(@"logs_global_logs", @"");
		else
			return [[TCLogsManager sharedManager] nameForKey:key];
	}
	else if (aTableView == _logsView)
	{
		NSInteger kindex = [_entriesView selectedRow];
		NSString *identifier = aTableColumn.identifier;

		if (kindex < 0 || kindex >= [_klogs count])
			return nil;
		
		NSString	*key = [_klogs objectAtIndex:(NSUInteger)kindex];
		TCLogEntry *entry;
		
		// Select the content to show.
		if ([key isEqualToString:TCLogsAllKey])
		{
			if (rowIndex < 0 || rowIndex >= [_allLogs count])
				return nil;
			
			NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
			
			if ([[item objectForKey:TCLogsTitleKey] boolValue])
			{
				// Handle title case.
				NSString *str = [item objectForKey:TCLogsTextKey];

				if ([str isEqualToString:TCLogsGlobalKey])
					return NSLocalizedString(@"logs_global_logs", @"");
				else
					return [NSString stringWithFormat:@"%@ (%@)", [[TCLogsManager sharedManager] nameForKey:str], str];
			}
			else
			{
				// Use entry.
				entry = [item objectForKey:TCLogsEntryKey];
			}
		}
		else if ([key isEqualToString:TCLogsGlobalKey])
		{
			NSArray *array = [_logs objectForKey:TCLogsGlobalKey];
			
			if (rowIndex < 0 || rowIndex >= [array count])
				return nil;

			entry = [array objectAtIndex:(NSUInteger)rowIndex];
		}
		else if ([key isEqualToString:TCLogsSeparatorKey])
		{
		}
		else
		{
			NSArray *array = [_logs objectForKey:key];
			
			if (rowIndex < 0 || rowIndex >= [array count])
				return nil;
			
			entry = [array objectAtIndex:(NSUInteger)rowIndex];
		}
		
		// Show content.
		if (entry)
		{
			if ([identifier isEqualToString:@"kind"])
			{
				switch (entry.kind)
				{
					case TCLogError:
						return [NSImage imageNamed:NSImageNameStatusUnavailable];
					case TCLogWarning:
						return [NSImage imageNamed:NSImageNameStatusPartiallyAvailable];
					case TCLogInfo:
						return [NSImage imageNamed:NSImageNameStatusNone];
				}
			}
			else if ([identifier isEqualToString:@"date"])
				return [_dateFormatter stringFromDate:entry.timestamp];
			else if ([identifier isEqualToString:@"message"])
				return entry.message;
		}
	}
	
	return nil;
}

- (BOOL)tableView:(NSTableView *)tableView isGroupRow:(NSInteger)rowIndex
{
	if (tableView == _logsView)
	{
		NSInteger	kindex = [_entriesView selectedRow];
		NSString	*key;
		
		if (kindex < 0 || kindex >= [_klogs count])
			return NO;
		
		key = [_klogs objectAtIndex:(NSUInteger)kindex];
		
		if ([key isEqualToString:TCLogsAllKey] == NO)
			return NO;
		
		NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
		
		return [[item objectForKey:TCLogsTitleKey] boolValue];
	}
	
	return NO;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)rowIndex
{
	if (tableView == _entriesView)
	{
		NSString *key;
		
		if (rowIndex < 0 || rowIndex >= [_klogs count])
			return [tableView rowHeight];
		
		key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
		
		if ([key isEqualToString:TCLogsSeparatorKey])
			return 2;
	}
	
	return [tableView rowHeight];
}

- (NSCell *)tableView:(NSTableView *)tableView dataCellForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	if (tableView == _entriesView)
	{
		// Handle row styles.
		NSString *key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
		
		if ([key isEqualToString:TCLogsSeparatorKey])
			return _separatorCell;
		else
			return _textCell;
	}
	else if (tableView == _logsView)
	{
		NSInteger	kindex = [_entriesView selectedRow];
		NSString	*key = [_klogs objectAtIndex:(NSUInteger)kindex];
		
		// Handle title case.
		if ([key isEqualToString:TCLogsAllKey])
		{
			NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
			
			if ([[item objectForKey:TCLogsTitleKey] boolValue])
				return _textCell;
		}
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
		NSString *key;
		
		if (rowIndex < 0 || rowIndex >= [_klogs count])
			return YES;
		
		key = [_klogs objectAtIndex:(NSUInteger)rowIndex];
		
		if ([key isEqualToString:TCLogsSeparatorKey])
			return NO;
	}
	else if (aTableView == _logsView)
	{
		NSInteger	kindex = [_entriesView selectedRow];
		NSString	*key;
		
		if (kindex < 0 || kindex > [_klogs count])
			return YES;
		
		key = [_klogs objectAtIndex:(NSUInteger)kindex];
		
		if ([key isEqualToString:TCLogsAllKey])
		{
			if (rowIndex < 0 || rowIndex >= [_allLogs count])
				return YES;
			
			NSDictionary *item = [_allLogs objectAtIndex:(NSUInteger)rowIndex];
			
			return ![[item objectForKey:TCLogsTitleKey] boolValue];
		}
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
** TCLogsWindowController - TCLogsObserver
*/
#pragma mark - TCLogsWindowController - TCLogsObserver

- (void)logManager:(TCLogsManager *)manager updateForKey:(NSString *)key withEntries:(NSArray *)entries
{
	[self addLogEntries:entries forKey:key];
}



/*
** TCLogsWindowController - Helpers
*/
#pragma mark - TCLogsWindowController - Helpers

- (void)addLogEntries:(NSArray *)items forKey:(NSString *)key
{
	// Hold it
	dispatch_async(dispatch_get_main_queue(), ^{
		
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
		for (TCLogEntry *entry in items)
			[array addObject:entry];
		
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
			
			[_allLogs addObject:@{ TCLogsTextKey : key, TCLogsTitleKey : @YES }];
		}
		
		// > Add
		for (TCLogEntry *entry in items)
			[_allLogs addObject:@{ TCLogsEntryKey : entry }];
		
		// Refresh
		[_entriesView reloadData];
		[_logsView reloadData];
	});
}

@end
