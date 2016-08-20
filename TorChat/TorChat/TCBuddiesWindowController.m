/*
 *  TCBuddiesWindowController.m
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

#import <SMFoundation/SMFoundation.h>
#import <SMTor/SMTor.h>

#import "TCBuddiesWindowController.h"

// -- Core --
#import "TCCoreManager.h"
#import "TCConfigCore.h"
#import "TCBuddy.h"
#import "TCImage.h"

// > Tools
#import "TCDebugLog.h"

// -- Interface --
// > Controllers
#import "TCBuddyInfoWindowsController.h"
#import "TCChatWindowController.h"

// > Cells
#import "TCBuddyCellView.h"

// > Views
#import "TCButton.h"
#import "TCDropButton.h"
#import "TCThreePartImageView.h"
#import "TCValidatedTextField.h"

// > Managers
#import "TCLogsManager.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCBuddiesController - Private
*/
#pragma mark - TCBuddiesController - Private

@interface TCBuddiesWindowController () <TCCoreManagerObserver, TCBuddyObserver, TCDropButtonDelegate>
{
	id <TCConfigAppEncryptable>	_configuration;
	TCCoreManager		*_core;
	
	dispatch_queue_t	_localQueue;

	NSMutableArray		*_buddies;
	id					_lastSelected;
	
	BOOL				_running;
	
	NSDictionary		*_infos;
	
	TCBuddyInfoWindowsController *_infoWindowsController;
}

// -- Properties --
@property (strong, nonatomic) IBOutlet NSProgressIndicator	*indicator;
@property (strong, nonatomic) IBOutlet NSTableView			*tableView;
@property (strong, nonatomic) IBOutlet NSPopUpButton		*imTitle;
@property (strong, nonatomic) IBOutlet NSButton				*imRemove;
@property (strong, nonatomic) IBOutlet NSPopUpButton		*imStatus;
@property (strong, nonatomic) IBOutlet NSImageView			*imStatusImage;
@property (strong, nonatomic) IBOutlet TCDropButton			*imAvatar;
@property (strong, nonatomic) IBOutlet TCThreePartImageView *barView;

@property (strong, nonatomic) IBOutlet NSWindow				*addWindow;
@property (strong, nonatomic) IBOutlet NSTextField			*addNameField;
@property (strong, nonatomic) IBOutlet TCValidatedTextField	*addIdentifierField;
@property (strong, nonatomic) IBOutlet NSTextView			*addNotesField;
@property (strong, nonatomic) IBOutlet NSButton				*addOkButton;

@property (strong, nonatomic) IBOutlet NSWindow				*profileWindow;
@property (strong, nonatomic) IBOutlet NSTextField			*profileName;
@property (strong, nonatomic) IBOutlet NSTextView			*profileText;

// -- IBAction --
- (IBAction)doStatus:(id)sender;
- (IBAction)doAvatar:(id)sender;
- (IBAction)doTitle:(id)sender;


- (IBAction)doAddOk:(id)sender;
- (IBAction)doAddCancel:(id)sender;

- (IBAction)doProfileOk:(id)sender;
- (IBAction)doProfileCancel:(id)sender;

// -- Helpers --
- (void)updateStatusUI:(TCStatus)status;
- (void)updateTitleUI;

@end



/*
** TCBuddiesController
*/
#pragma mark - TCBuddiesController

@implementation TCBuddiesWindowController


/*
** TCBuddiesController - Instance
*/
#pragma mark - TCBuddiesController - Instance

+ (TCBuddiesWindowController *)sharedController
{
	static dispatch_once_t		pred;
	static TCBuddiesWindowController	*instance = nil;
		
	dispatch_once(&pred, ^{
		instance = [[TCBuddiesWindowController alloc] init];
	});
	
	return instance;
}

- (instancetype)init
{
	self = [super initWithWindowNibName:@"BuddiesWindow"];
	
	if (self)
	{
		// Build an event dispatch queue
		_localQueue = dispatch_queue_create("com.torchat.app.buddies.local", DISPATCH_QUEUE_SERIAL);

		// Build array of cocoa buddy
		_buddies = [[NSMutableArray alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCBuddieController dealloc");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)windowDidLoad
{
	// Place Window.
	[self.window center];
	[self.window setFrameAutosaveName:@"BuddiesWindow"];
	
	// Configure table view.
	[_tableView setTarget:self];
	[_tableView setDoubleAction:@selector(tableViewDoubleClick:)];
	
	// Configura bar.
	_barView.startCap = (NSImage *)[NSImage imageNamed:@"bar"];
	_barView.centerFill = (NSImage *)[NSImage imageNamed:@"bar"];
	_barView.endCap = (NSImage *)[NSImage imageNamed:@"bar"];
	
	// Configure identifier field.
	NSButton *okButton = _addOkButton;
	
	_addIdentifierField.validCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789"];
	_addIdentifierField.validateContent = ^ BOOL (NSString *newContent) {
		return (newContent.length <= 16);
	};
	_addIdentifierField.textDidChange = ^(NSString *content) {
		okButton.enabled = (content.length == 16);
	};
}



/*
** TCBuddiesController - Running
*/
#pragma mark - TCBuddiesController - Running

- (void)startWithConfiguration:(id <TCConfigAppEncryptable>)configuration coreManager:(TCCoreManager *)coreMananager completionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();

	if (!handler)
		handler = ^{ };
	
	dispatch_group_async(group, dispatch_get_main_queue(), ^{
		
		if (_running)
			return;
		
		_running = YES;
		
		// Load window.
		[self window];
		
		// Hold the config & core.
		_configuration = configuration;
		_core = coreMananager;
		
		// -- Init window content --
		// > Show load indicator.
		[_indicator startAnimation:self];
		
		// > Init title.
		[self updateTitleUI];
		
		// > Init status
		[self updateStatusUI:[_core status]];
		
		// > Init avatar.
		NSImage *avatar = [[_core profileAvatar] imageRepresentation];
				
		if ([[avatar representations] count] > 0)
			[_imAvatar setImage:avatar];
		else
		{
			NSImage *img = [NSImage imageNamed:NSImageNameUser];
			
			[img setSize:NSMakeSize(64, 64)];
		 
			[_imAvatar setImage:img];
		}
		
		// > Init table file drag.
		[_tableView registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
		[_tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
		
		// > Redirect avatar drop.
		[_imAvatar setDelegate:self];
		
		// Create windows info controller.
		_infoWindowsController = [[TCBuddyInfoWindowsController alloc] initWithCoreManager:coreMananager];
		
		// Add ourself as observer.
		[_core addObserver:self];
		
		// Add current buddies.
		NSArray *buddies = [_core buddies];
		
		for (TCBuddy *buddy in buddies)
		{
			[buddy addObserver:self];
			[_buddies addObject:buddy];
		}
		
		[_tableView reloadData];
		
		// Show the window.
		[self showWindow:nil];
	});
	
	// Wait end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	dispatch_group_async(group, dispatch_get_main_queue(), ^{
		
		if (!_running)
			return;
		
		// Close the window.
		[self close];
		
		// Clean buddies.
		for (TCBuddy *buddy in _buddies)
		{
			[buddy removeObserver:self];
			[_infoWindowsController closeInfoForBuddy:buddy];
		}
		
		[_buddies removeAllObjects];
		[_tableView reloadData];
		
		// Clean controller.
		if (_core)
		{
			[_core removeObserver:self];
			_core = nil;
		}
		
		// Set status to offline.
		[_imStatus selectItemWithTag:0];
		[self updateTitleUI];
		
		// Update status.
		_running = NO;
	});
	
	// Wait for end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
}



/*
** TCBuddiesController - TableView
*/
#pragma mark - TCBuddiesController - TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)[_buddies count];
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	TCBuddyCellView	*cellView = nil;
	TCBuddy			*buddy = [_buddies objectAtIndex:(NSUInteger)rowIndex];
	NSString		*name = [buddy finalName];
	
	if ([name length] > 0)
		cellView = [tableView makeViewWithIdentifier:@"buddy_name" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"buddy_identifier" owner:self];
	
	[cellView setBuddy:buddy];
	
	return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger row = [_tableView selectedRow];
	
	[_imRemove setEnabled:(row >= 0)];

	// Hold current selection (not perfect).
	if (row >= 0 && row < [_buddies count])
		_lastSelected = [_buddies objectAtIndex:(NSUInteger)row];
	else
		_lastSelected = nil;
}

- (void)tableViewDoubleClick:(id)sender
{
	NSInteger	row = [_tableView clickedRow];
	TCBuddy		*buddy;

	// Get the double-clicked button
	if (row < 0 || row >= [_buddies count])
		return;
	
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	
	// Open a chat window.
	[self startChatForBuddy:buddy];
}


- (NSDragOperation)tableView:(NSTableView *)aTableView validateDrop:(id < NSDraggingInfo >)info proposedRow:(NSInteger)row proposedDropOperation:(NSTableViewDropOperation)operation
{	
	if (operation == NSTableViewDropOn)
		return NSDragOperationMove;
	else
		return NSDragOperationNone;
}

- (BOOL)tableView:(NSTableView *)aTableView acceptDrop:(id < NSDraggingInfo >)info row:(NSInteger)row dropOperation:(NSTableViewDropOperation)operation
{
	if (row < 0 || row >= [_buddies count])
		return NO;
	
	TCBuddy			*buddy = [_buddies objectAtIndex:(NSUInteger)row];
	NSPasteboard	*pboard = [info draggingPasteboard];
	NSArray			*types = [pboard types];
	
	if ([types containsObject:NSFilenamesPboardType])
	{
		NSFileManager	*mng = [NSFileManager defaultManager];
		NSArray			*fileList = [pboard propertyListForType:NSFilenamesPboardType];

		for (NSString *fileName in fileList)
		{
			BOOL isDirectory = NO;
			
			if ([mng fileExistsAtPath:fileName isDirectory:&isDirectory])
			{
				if (isDirectory)
					continue;
				
				[buddy sendFile:fileName];
			}
		}
		
		return YES;
	}
	
	return NO;
}



/*
** TCBuddiesController - TCCoreManagerDelegate
*/
#pragma mark - TCBuddiesController - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(SMInfo *)info
{
	// Action information
	switch (info.kind)
	{
		case SMInfoInfo:
		{
			switch (info.code)
			{
				case TCCoreEventStarted:
				{
					dispatch_async(dispatch_get_main_queue(), ^{
						[_indicator stopAnimation:self];
					});
					
					break;
				}
					
				case TCCoreEventStatus:
				{
					TCStatus status = (TCStatus)[(NSNumber *)info.context intValue];
					
					dispatch_async(dispatch_get_main_queue(), ^{
						[self updateStatusUI:status];
					});
					
					break;
				}
					
				case TCCoreEventProfileAvatar:
				{
					TCImage	*tcFinal = (TCImage *)info.context;
					NSImage	*final = [tcFinal imageRepresentation];
					
					if (!final)
						final = [NSImage imageNamed:NSImageNameUser];
					
					// Change image.
					dispatch_async(dispatch_get_main_queue(), ^{
						[_imAvatar setImage:final];
					});
					
					break;
				}
					
				case TCCoreEventProfileName:
				{
					// Update Title.
					dispatch_async(dispatch_get_main_queue(), ^{
						[self updateTitleUI];
					});
					
					break;
				}
					
				case TCCoreEventBuddyNew:
				{
					TCBuddy *buddy = (TCBuddy *)info.context;
					
					[buddy addObserver:self];
					
					dispatch_async(dispatch_get_main_queue(), ^{
						[_buddies addObject:buddy];
						[self _reloadBuddy:nil];
					});
					
					break;
				}
					
				case TCCoreEventBuddyRemove:
				{
					TCBuddy *buddy = info.context;
					
					[buddy removeObserver:self];
					
					dispatch_async(dispatch_get_main_queue(), ^{
						[_buddies removeObjectIdenticalTo:buddy];
						[_tableView reloadData];
					});
					
					break;
				}
					
				case TCCoreEventBuddyBlocked:
				case TCCoreEventBuddyUnblocked:
				{
					[self reloadBuddies];
					break;
				}
			}
			
			break;
		}
			
		case SMInfoWarning:
		{
			break;
		}

		case SMInfoError:
		{
			dispatch_async(dispatch_get_main_queue(), ^{
				[_indicator stopAnimation:self];
			});
			
			break;
		}
	}
}



/*
** TCBuddiesController - TCBuddyObserver
*/
#pragma mark - TCBuddiesController - TCBuddyObserver

- (void)buddy:(TCBuddy *)aBuddy information:(SMInfo *)info
{
	// Handle info.
	dispatch_async(_localQueue, ^{
		
		if (info.kind == SMInfoInfo)
		{
			// Actions
			switch (info.code)
			{
				case TCBuddyEventDisconnected:
				{
					[self reloadBuddies];
					break;
				}
					
				case TCBuddyEventStatus:
				{
					[self reloadBuddies];
					break;
				}
					
				case TCBuddyEventProfileAvatar:
				{
					// Reload table.
					dispatch_async(dispatch_get_main_queue(), ^{
						[self _reloadBuddy:aBuddy];
					});

					break;
				}
					
				case TCBuddyEventProfileName:
				{
					[self reloadBuddies];
					break;
				}

				case TCBuddyEventAlias:
				{
					[self reloadBuddies];
					break;
				}
			}
		}
	});
}



/*
** TCBuddiesController - TCDropButtonDelegate
*/
#pragma mark - TCBuddiesController - TCDropButtonDelegate

- (void)dropButton:(TCDropButton *)button doppedImage:(NSImage *)avatar
{
	TCImage *image = [[TCImage alloc] initWithImage:avatar];
	
	[_core setProfileAvatar:image];
}



/*
** TCBuddiesController - IBAction
*/
#pragma mark - TCBuddiesController - IBAction

- (IBAction)doStatus:(id)sender
{
	// Change status
	switch ([_imStatus selectedTag])
	{
		case 0:
			[_core setStatus:TCStatusOffline];
			break;
			
		case 1:
			[_core setStatus:TCStatusAvailable];
			break;
			
		case 2:
			[_core setStatus:TCStatusAway];
			break;
			
		case 3:
			[_core setStatus:TCStatusXA];
			break;
	}
}

- (IBAction)doAvatar:(id)sender
{
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:NO];
	[openDlg setAllowedFileTypes:[NSImage imageTypes]];
	
	if ([openDlg runModal] == NSModalResponseOK)
	{
		NSArray	*urls = [openDlg URLs];
		NSImage *avatar = [[NSImage alloc] initWithContentsOfURL:[urls objectAtIndex:0]];

		[self dropButton:_imAvatar doppedImage:avatar];
	}
}

- (IBAction)doTitle:(id)sender
{
	NSMenuItem	*selected = [_imTitle selectedItem];
	NSInteger	tag = [selected tag];
	
	if (!selected)
	{
		NSBeep();
		return;
	}
	
	switch (tag)
	{
		case 0:
			[_configuration setModeTitle:TCConfigTitleName];
			break;
			
		case 1:
			[_configuration setModeTitle:TCConfigTitleIdentifier];
			break;
			
		case 3:
			[self doEditProfile:sender];			
			break;
	}
	
	[self updateTitleUI];
}

- (IBAction)doShowInfo:(id)sender
{
	// Get selected buddy.
	TCBuddy *buddy = [self selectedBuddy];
	
	if (!buddy)
	{
		NSBeep();
		return;
	}
	
	// Show.
	[_infoWindowsController showInfoForBuddy:buddy];
}

- (IBAction)doRemove:(id)sender
{
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	NSString	*identifier;
	
	if (row < 0 || row >= [_buddies count])
		return;
	
	// Get the buddy identifier.
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	identifier = [buddy identifier];

	// Remove the buddy from the controller.
	[_core removeBuddyWithIdentifier:identifier];
}

- (IBAction)doAdd:(id)sender
{
	_addIdentifierField.stringValue = @"";
	_addNameField.stringValue = @"";
	[[[_addNotesField textStorage] mutableString] setString:@""];
	
	_addOkButton.enabled = NO;
	
	[_addWindow center];
	[_addWindow makeKeyAndOrderFront:sender];
	
	[_addWindow makeFirstResponder:_addIdentifierField];
}

- (IBAction)doChat:(id)sender
{
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	
	if (row < 0 || row >= [_buddies count])
		return;

	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	
	[self startChatForBuddy:buddy];
}

- (IBAction)doSendFile:(id)sender
{
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	
	if (row < 0 || row >= [_buddies count])
		return;
	
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
	
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:YES];
	
	if ([openDlg runModal] == NSModalResponseOK)
	{
		NSArray *urls = [openDlg URLs];

		for (NSURL *url in urls)
		{
			NSString *path = url.path;
			
			if (path)
				[buddy sendFile:path];
		}
	}
}

- (IBAction)doToggleBlock:(id)sender
{
	NSInteger	row = [_tableView selectedRow];
	TCBuddy		*buddy;
	
	if (row < 0 || row >= [_buddies count])
		return;
	
	buddy = [_buddies objectAtIndex:(NSUInteger)row];
		
	if ([buddy blocked])
		[_core removeBlockedBuddyWithIdentifier:[buddy identifier]];
	else
		[_core addBlockedBuddyWithIdentifier:[buddy identifier]];
}

- (IBAction)doEditProfile:(id)sender
{
	NSString *tname = [_core profileName];
	NSString *ttext = [_core profileText];
	
	[_profileName setStringValue:(tname ?: @"")];
	[[[_profileText textStorage] mutableString] setString:(ttext ?: @"")];
	
	[self.window beginSheet:_profileWindow completionHandler:nil];
}

- (IBAction)doAddOk:(id)sender
{
	NSString *identifierString = _addIdentifierField.stringValue;
	NSString *nameString = _addNameField.stringValue;
	NSString *notesString = [[_addNotesField textStorage] mutableString];

	if (nameString.length == 0)
		nameString = nil;
	
	if (notesString.length == 0)
		notesString = nil;
	
	[_core addBuddyWithIdentifier:identifierString name:nameString comment:notesString];
	
	[_addWindow orderOut:self];
}

- (IBAction)doAddCancel:(id)sender
{
	[_addWindow orderOut:self];
}

- (IBAction)doProfileOk:(id)sender
{
	[self.window endSheet:_profileWindow];
	[_profileWindow orderOut:self];
	
	// -- Hold name --
	NSString *name = [_profileName stringValue];
	
	[_core setProfileName:name];
	
	// -- Hold text --
	NSString *text = [[_profileText textStorage] mutableString];
	
	[_core setProfileText:text];
}

- (IBAction)doProfileCancel:(id)sender
{
	[self.window endSheet:_profileWindow];
	[_profileWindow orderOut:self];
}



/*
** TCBuddiesController - Tools
*/
#pragma mark - TCBuddiesController - Tools

- (void)reloadBuddies
{
	dispatch_async(dispatch_get_main_queue(), ^{

		// Sort buddies by status.
		NSUInteger		i, cnt = [_buddies count];
		NSMutableArray	*temp_block = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_off = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_av = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_aw = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_xa = [[NSMutableArray alloc] initWithCapacity:cnt];
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy *buddy = [_buddies objectAtIndex:i];
			
			if ([buddy blocked])
				[temp_block addObject:buddy];
			else
			{
				switch ([buddy status])
				{
					case TCStatusOffline:
						[temp_off addObject:buddy];
						break;
						
					case TCStatusAvailable:
						[temp_av addObject:buddy];
						break;
						
					case TCStatusAway:
						[temp_aw addObject:buddy];
						break;
						
					case TCStatusXA:
						[temp_xa addObject:buddy];
						break;
				}
			}
		}
		
		// Subsort by names.
		NSComparisonResult (^sortBuddy)(id _Nonnull, id  _Nonnull) = ^NSComparisonResult(TCBuddy * _Nonnull buddy1, TCBuddy *  _Nonnull buddy2) {
			return [[buddy1 finalName] compare:[buddy2 finalName]];
		};
		
		[temp_av sortUsingComparator:sortBuddy];
		[temp_aw sortUsingComparator:sortBuddy];
		[temp_xa sortUsingComparator:sortBuddy];
		[temp_off sortUsingComparator:sortBuddy];
		[temp_block sortUsingComparator:sortBuddy];

		// Recompose array.
		[_buddies removeAllObjects];
		
		[_buddies addObjectsFromArray:temp_av];
		[_buddies addObjectsFromArray:temp_aw];
		[_buddies addObjectsFromArray:temp_xa];
		[_buddies addObjectsFromArray:temp_off];
		[_buddies addObjectsFromArray:temp_block];

		// Reload table
		[self _reloadBuddy:nil];
	});
}

- (void)startChatForBuddy:(TCBuddy *)buddy
{
	NSAssert(buddy, @"buddy is nil");

	[[TCChatWindowController sharedController] openChatWithBuddy:buddy select:YES];
}

- (nullable TCBuddy *)selectedBuddy
{
	NSInteger row = [_tableView selectedRow];
	
	if (row < 0 || row >= [_buddies count])
		return nil;
	
	return [_buddies objectAtIndex:(NSUInteger)row];
}

- (void)updateStatusUI:(TCStatus)status
{
	// Unselect old item
	for (NSMenuItem *item in [_imStatus itemArray])
		[item setState:NSOffState];
	
	// Select the new item
	NSInteger index = [_imStatus indexOfItemWithTag:status];
	
	if (index > -1)
	{
		NSMenuItem *select = [_imStatus itemAtIndex:index];
		NSMenuItem *title = [_imStatus itemAtIndex:0];
		
		[title setTitle:[select title]];
		[select setState:NSOnState];
		
		[_imStatusImage setImage:[select image]];
	}
}

- (void)updateTitleUI
{	
	NSString *content = nil;
	
	if (_configuration)
	{
		// Check the title to show
		switch ([_configuration modeTitle])
		{
			case TCConfigTitleIdentifier:
			{
				content = [_configuration selfIdentifier];
				
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]] setState:NSOffState];
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]] setState:NSOnState];
				
				break;
			}
				
			case TCConfigTitleName:
			{
				content = [_core profileName];
								
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]] setState:NSOnState];
				[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]] setState:NSOffState];
				
				break;
			}
		}
	}
	else
	{
		[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]] setState:NSOffState];
		[[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]] setState:NSOffState];
	}
	
	// Update popup-title
	if (content.length == 0)
		content = @"-";
	
	[[_imTitle itemAtIndex:0] setTitle:content];
}

- (void)_reloadBuddy:(nullable TCBuddy *)buddy
{
	// > main queue <
	
	if (buddy)
	{
		NSUInteger index = [_buddies indexOfObjectIdenticalTo:(TCBuddy *)buddy];
		
		if (index != NSNotFound)
			[_tableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:index] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		else
			[self _reloadBuddy:nil];
	}
	else
	{
		NSInteger index = [_tableView selectedRow];
		
		[_tableView reloadData];
		
		if (index != NSNotFound)
			[_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] byExtendingSelection:NO];
	}
}

@end


NS_ASSUME_NONNULL_END
