/*
 *  TCBuddyInfoController.mm
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



#import "TCBuddyInfoController.h"

#import "TCBuddiesController.h"
#import "TCLogsController.h"



/*
** Globals
*/
#pragma mark -
#pragma mark Globals

static NSMutableArray *_windows = nil;



/*
** TCBuddyInfoController - Private
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Private

@interface TCBuddyInfoController ()

+ (TCBuddyInfoController *)buildController;

@property (retain, nonatomic) TCCocoaBuddy	*_buddy;
@property (retain, nonatomic) NSString		*_address;

@end



/*
** TCBuddyInfoController
*/
#pragma mark -
#pragma mark TCBuddyInfoController

@implementation TCBuddyInfoController


/*
** TCBuddyInfoController - Properties
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Properties

@synthesize _buddy;
@synthesize _address;



/*
** TCBuddyInfoController - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Constructor & Destructor

- (id)initWithWindow:(NSWindow *)window
{	
    if ((self = [super initWithWindow:window]))
	{
		_logs = [[NSMutableArray alloc] init];
		
		[window center];
		
		[self windowDidResize:nil];
    }
    
    return self;
}

- (void)dealloc
{
	TCDebugLog("(%p) TCBuddyInfoController dealloc", self);
	
	[_buddy release];
	[_logs release];
	[_address release];
	
	[self.window setDelegate:nil];
	[logTable setDelegate:nil];
	[logTable setDataSource:nil];
	[views setDelegate:nil];
	
	[addressField setDelegate:nil];
	[aliasField setDelegate:nil];
	[notesField setDelegate:nil];
	
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];

	[self.window center];
	[self setWindowFrameAutosaveName:@"InfoWindow"];
	[self windowDidResize:nil];
}



/*
** TCBuddyInfoController - IBAction
*/
#pragma mark -
#pragma mark TCBuddyInfoController - IBAction

- (IBAction)doToolBar:(id)sender
{
	NSInteger index = [toolBar selectedSegment];
			
	[views selectTabViewItemAtIndex:index];
}



/*
** TCBuddyInfoController - Private Tools
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Private Tools

+ (TCBuddyInfoController *)buildController
{
	static dispatch_once_t		pred;
	
	// Alloc global controller array
	dispatch_once(&pred, ^{
		_windows = [[NSMutableArray alloc] init];
	});
	
	// Alloc the controller
	TCBuddyInfoController *result = [[[TCBuddyInfoController alloc] initWithWindowNibName:@"BuddyInfo"] autorelease];

	// Configure controller
	[result.window setDelegate:result];

	// Add the controller to the global array
	[_windows addObject:result];
	
	return result;
}



/*
** TCBuddyInfoController - Tools
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Tools

+ (void)showInfo
{
	[self showInfoOnBuddy:[[TCBuddiesController sharedController] selectedBuddy]];
}

+ (void)showInfoOnBuddy:(TCCocoaBuddy *)buddy
{
	NSUInteger	i, cnt = [_windows count];
	NSString	*address = [buddy address];
	
	// Check that we don't have a controller already running for this buddy
	for (i = 0; i < cnt; i++)
	{
		TCBuddyInfoController *ctrl = [_windows objectAtIndex:i];
		
		if ([ctrl._address isEqualToString:address])
		{
			[ctrl.window makeKeyAndOrderFront:nil];
			return;
		}
	}
	
	// Create new controller
	TCBuddyInfoController *ctrl = [self buildController];
	
	// Retain buddy
	ctrl._buddy = buddy;
	
	// Show value
	ctrl._address = address;
	
	[ctrl->avatarView setImage:[buddy profileAvatar]];
	[ctrl->addressField setStringValue:ctrl._address];
	[ctrl->profileNameField setStringValue:[buddy profileName]];
	[ctrl->profileTextField setStringValue:[buddy profileText]];
	[ctrl->aliasField setStringValue:[buddy alias]];
	[[[ctrl->notesField textStorage] mutableString] setString:[buddy notes]];
	
	// Register for logs	
	[[TCLogsController sharedController] setObserver:ctrl withSelector:@selector(logsChanged:) forKey:ctrl._address];
	
	// Register for buddy changes
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyAvatarChanged:) name:TCCocoaBuddyChangedAvatarNotification object:buddy];
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyNameChanged:) name:TCCocoaBuddyChangedNameNotification object:buddy];
	[[NSNotificationCenter defaultCenter] addObserver:ctrl selector:@selector(buddyTextChanged:) name:TCCocoaBuddyChangedTextNotification object:buddy];

	
	// Show the window
	[ctrl showWindow:nil];
}

+ (void)removingBuddy:(TCCocoaBuddy *)buddy
{
	NSUInteger i, cnt = [_windows count];
	
	for (i = 0; i < cnt; i++)
	{
		TCBuddyInfoController *ctrl = [_windows objectAtIndex:i];
		
		if (ctrl._buddy == buddy)
		{			
			[[TCLogsController sharedController] removeObserverForKey:ctrl._address];
			
			[[NSNotificationCenter defaultCenter] removeObserver:ctrl];
			
			[ctrl.window orderOut:nil];
			[_windows removeObjectAtIndex:i];
			
			return;
		}
	}
}



/*
** TCBuddyInfoController - Window Delegate
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Window Delegate

- (void)windowWillClose:(NSNotification *)notification
{	
	[[TCLogsController sharedController] removeObserverForKey:self._address];
	
	[_windows removeObject:self];
}

- (void)windowDidResize:(NSNotification *)notification
{
	NSSize sz = self.window.frame.size;
	NSInteger	i, count = [toolBar segmentCount];
	float		swidth = sz.width / count;
	
	for (i = 0; i < count; i++)
		[toolBar setWidth:swidth forSegment:i];
}



/*
** TCBuddyInfoController - NSTableView
*/
#pragma mark -
#pragma mark TCBuddyInfoController - NSTableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{	
	return [_logs count];
}

- (id)tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex
{	
	return [_logs objectAtIndex:rowIndex];
}



/*
** TCBuddyInfoController - NSTextView/Field
*/
#pragma mark -
#pragma mark TCBuddyInfoController - NSTextView/Field

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	
	if (object == aliasField)
	{
		[_buddy setAlias:[aliasField stringValue]];
	}
}

- (void)textDidChange:(NSNotification *)aNotification
{
	id object = [aNotification object];
	
	if (object == notesField)
	{
		[_buddy setNotes:[[notesField textStorage] mutableString]];
	}
}



/*
** TCBuddyInfoController - Notifications
*/
#pragma mark -
#pragma mark TCBuddyInfoController - Notifications

- (void)logsChanged:(id)content
{	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		if ([content isKindOfClass:[NSString class]])
		{
			if ([_logs count] > 500)
				[_logs removeObjectAtIndex:0];
			
			[_logs addObject:content];
		}
		else if ([content isKindOfClass:[NSArray class]])
		{
			[_logs addObjectsFromArray:content];
		}
		
		[logTable reloadData];
	});
}

- (void)buddyAvatarChanged:(NSNotification *)notice
{
	NSImage *avatar = [[notice userInfo] objectForKey:@"avatar"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[avatarView setImage:avatar];
	});
}

- (void)buddyNameChanged:(NSNotification *)notice
{
	NSString *name = [[notice userInfo] objectForKey:@"name"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[profileNameField setStringValue:name];
	});
}

- (void)buddyTextChanged:(NSNotification *)notice
{
	NSString *text = [[notice userInfo] objectForKey:@"text"];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		[profileTextField setStringValue:text];
	});
}

@end
