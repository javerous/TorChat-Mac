/*
 *  TCBuddiesWindowController.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

// -- Interface --
// > Controllers
#import "TCMainController.h"
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

@interface TCBuddiesWindowController () <NSMenuDelegate, TCCoreManagerObserver, TCBuddyObserver, TCDropButtonDelegate>
{
	__weak TCMainController *_mainController;
	id <TCConfigApp>		_configuration;
	TCCoreManager			*_core;
	
	dispatch_queue_t	_localQueue;

	NSMutableArray	*_buddies;
	id				_lastSelected;
	
	NSDictionary	*_infos;
	
	BOOL _coreStarted;
	
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
** TCBuddiesWindowController
*/
#pragma mark - TCBuddiesWindowController

@implementation TCBuddiesWindowController


/*
** TCBuddiesWindowController - Instance
*/
#pragma mark - TCBuddiesWindowController - Instance

- (instancetype)initWithMainController:(TCMainController *)mainController configuration:(id <TCConfigApp>)configuration coreManager:(TCCoreManager *)coreMananager
{
	self = [super initWithWindow:nil];
	
	if (self)
	{
		// Hold parameters.
		_mainController = mainController;
		_configuration = configuration;
		_core = coreMananager;
		
		// Queue.
		_localQueue = dispatch_queue_create("com.torchat.app.buddies.local", DISPATCH_QUEUE_SERIAL);
		
		// Containers.
		_buddies = [[NSMutableArray alloc] init];
		
		// Register observer.
		[_core addObserver:self];
		
		// Add current buddies.
		NSArray *buddies = _core.buddies;
		
		for (TCBuddy *buddy in buddies)
		{
			[buddy addObserver:self];
			[_buddies addObject:buddy];
		}
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCBuddieController dealloc");
	
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



/*
** TCBuddiesWindowController - NSWindowController + NSWindowDelegate
*/
#pragma mark - TCBuddiesWindowController - NSWindowController + NSWindowDelegate

- (nullable NSString *)windowNibName
{
	return @"BuddiesWindow";
}

- (nullable id)owner
{
	return self;
}

- (void)windowDidLoad
{
	[super windowDidLoad];

	// Place window.
	NSString *windowFrame = [_configuration generalSettingValueForKey:@"window-frame-buddies"];
	
	if (windowFrame)
		[self.window setFrameFromString:windowFrame];
	else
		[self.window center];
	
	// Start load indicator.
	if (_coreStarted == NO)
		[_indicator startAnimation:self];
	
	// Init title.
	[self updateTitleUI];
	
	// Init status
	[self updateStatusUI:_core.status];
	
	// Configure avatar.
	NSImage *avatar = [_core.profileAvatar imageRepresentation];
	
	if (avatar.representations.count > 0)
		_imAvatar.image = avatar;
	else
	{
		NSImage *img = [NSImage imageNamed:NSImageNameUser];
		
		img.size = NSMakeSize(64, 64);
		
		_imAvatar.image = img;
	}
	
	// Configure table view.
	// > Drag & drop.
	[_tableView registerForDraggedTypes:@[NSFilenamesPboardType]];
	[_tableView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
	
	// > Double click.
	_tableView.target = self;
	_tableView.doubleAction = @selector(tableViewDoubleClick:);
	
	// > Contextual menu.
	NSMenu *menu = [[NSMenu alloc] initWithTitle:@"<contextual>"];
	
	menu.delegate = self;
	
	_tableView.menu = menu;
	
	// Configure footbar.
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
	
	// Configure avatar.
	_imAvatar.delegate = self;
	
	// Reload table.
	[_tableView reloadData];
}



/*
** TCBuddiesWindowController - Synchronize
*/
#pragma mark - TCBuddiesWindowController - Synchronize

- (void)synchronizeWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_group_t group = dispatch_group_create();
	
	dispatch_group_async(group, dispatch_get_main_queue(), ^{
		
		// Save window frame.
		if (self.windowLoaded)
			[_configuration setGeneralSettingValue:self.window.stringWithSavedFrame forKey:@"window-frame-buddies"];
		
		// Synchronize info window.
		if (_infoWindowsController)
		{
			dispatch_group_enter(group);

			[_infoWindowsController synchronizeWithCompletionHandler:^{
				dispatch_group_leave(group);
			}];
		}
	});
	
	// Wait for end.
	dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
}



/*
** TCBuddiesWindowController - TableView
*/
#pragma mark - TCBuddiesWindowController - TableView

- (NSInteger)numberOfRowsInTableView:(NSTableView *)aTableView
{
	return (NSInteger)_buddies.count;
}

- (NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)rowIndex
{
	TCBuddyCellView	*cellView = nil;
	TCBuddy			*buddy = _buddies[(NSUInteger)rowIndex];
	NSString		*name = buddy.finalName;
	
	if (name.length > 0)
		cellView = [tableView makeViewWithIdentifier:@"buddy_name" owner:self];
	else
		cellView = [tableView makeViewWithIdentifier:@"buddy_identifier" owner:self];
	
	[cellView setBuddy:buddy];
	
	return cellView;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification
{
	NSInteger row = _tableView.selectedRow;
	
	_imRemove.enabled = (row >= 0);

	// Hold current selection (not perfect).
	if (row >= 0 && row < _buddies.count)
		_lastSelected = _buddies[(NSUInteger)row];
	else
		_lastSelected = nil;
}

- (void)tableViewDoubleClick:(id)sender
{
	NSInteger	row = _tableView.clickedRow;
	TCBuddy		*buddy;

	// Get the double-clicked button
	if (row < 0 || row >= _buddies.count)
		return;
	
	buddy = _buddies[(NSUInteger)row];
	
	// Open a chat window.
	[self startChatForBuddy:buddy];
}

- (NSArray<NSTableViewRowAction *> *)tableView:(NSTableView *)tableView rowActionsForRow:(NSInteger)row edge:(NSTableRowActionEdge)edge
{
	if (edge == NSTableRowActionEdgeTrailing)
	{
		TCCoreManager	*core = _core;
		TCBuddy			*buddy = _buddies[(NSUInteger)row];
		NSString		*blockString = nil;
		
		if (buddy.blocked)
			blockString = NSLocalizedString(@"buddies_ctrl_unblock", @"");
		else
			blockString = NSLocalizedString(@"buddies_ctrl_block", @"");

		NSTableViewRowAction *rowActionBlock = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleRegular title:blockString handler:^(NSTableViewRowAction * _Nonnull action, NSInteger actionIndex) {
		
			if (buddy.blocked)
				[core removeBlockedBuddyWithIdentifier:buddy.identifier];
			else
				[core addBlockedBuddyWithIdentifier:buddy.identifier];
			
		}];
		
		NSTableViewRowAction *rowActionRemove = [NSTableViewRowAction rowActionWithStyle:NSTableViewRowActionStyleDestructive title:NSLocalizedString(@"buddies_ctrl_remove", @"") handler:^(NSTableViewRowAction * _Nonnull action, NSInteger actionIndex) {
			[core removeBuddyWithIdentifier:buddy.identifier];
		}];
		
		return @[ rowActionBlock, rowActionRemove ];
	}
	
	return @[ ];
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
	if (row < 0 || row >= _buddies.count)
		return NO;
	
	TCBuddy			*buddy = _buddies[(NSUInteger)row];
	NSPasteboard	*pboard = [info draggingPasteboard];
	NSArray			*types = pboard.types;
	
	if ([types containsObject:NSFilenamesPboardType])
	{
		NSFileManager	*mng = [NSFileManager defaultManager];
		NSArray			*fileList = [pboard propertyListForType:NSFilenamesPboardType];
		BOOL			fileSent = NO;

		for (NSString *fileName in fileList)
		{
			BOOL isDirectory = NO;
			
			if ([mng fileExistsAtPath:fileName isDirectory:&isDirectory] == NO || isDirectory)
				continue;
			
			if ([mng isReadableFileAtPath:fileName] == NO)
				continue;
			
			[buddy sendFileAtPath:fileName];
			
			fileSent = YES;
		}
		
		return fileSent;
	}
	
	return NO;
}



/*
** TCBuddiesWindowController - NSMenuDelegate
*/
#pragma mark - TCBuddiesWindowController - NSMenuDelegate

- (void)menuNeedsUpdate:(NSMenu *)menu
{
	// Clean all.
	[menu removeAllItems];

	// Check if there is a selection.
	NSInteger clickedRow = _tableView.clickedRow;
	NSInteger clickedCol = _tableView.clickedColumn;
	
	if (clickedRow < 0 || clickedRow >= _buddies.count || clickedCol < 0)
		return;
	
	TCBuddy *buddy = _buddies[(NSUInteger)clickedRow];

	// Add items.
	// > Block.
	NSString	*blockString = nil;
	NSMenuItem	*blockMenu;
	
	if (buddy.blocked)
		blockString = NSLocalizedString(@"buddies_ctrl_unblock", @"");
	else
		blockString = NSLocalizedString(@"buddies_ctrl_block", @"");
	
	blockMenu = [[NSMenuItem alloc] initWithTitle:blockString action:@selector(toggleBlockForClickedBuddy:) keyEquivalent:@""];
	
	blockMenu.target = self;
	
	[menu addItem:blockMenu];
	
	// > Remove.
	NSMenuItem *removeMenu = [[NSMenuItem alloc] initWithTitle:NSLocalizedString(@"buddies_ctrl_remove", @"") action:@selector(removeClickedBuddy:) keyEquivalent:@""];
	
	removeMenu.target = self;

	[menu addItem:removeMenu];
}


/*
** TCBuddiesWindowController - TCCoreManagerDelegate
*/
#pragma mark - TCBuddiesWindowController - TCCoreManagerObserver

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
						_coreStarted = YES;
						[_indicator stopAnimation:self];
					});
					
					break;
				}
					
				case TCCoreEventStatus:
				{
					TCStatus status = (TCStatus)((NSNumber *)info.context).intValue;
					
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
						_imAvatar.image = final;
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
** TCBuddiesWindowController - TCBuddyObserver
*/
#pragma mark - TCBuddiesWindowController - TCBuddyObserver

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
** TCBuddiesWindowController - TCDropButtonDelegate
*/
#pragma mark - TCBuddiesWindowController - TCDropButtonDelegate

- (void)dropButton:(TCDropButton *)button doppedImage:(NSImage *)avatar
{
	TCImage *image = [[TCImage alloc] initWithImage:avatar];
	
	_core.profileAvatar = image;
}



/*
** TCBuddiesWindowController - IBAction
*/
#pragma mark - TCBuddiesWindowController - IBAction

- (IBAction)doStatus:(id)sender
{
	// Change status
	switch (_imStatus.selectedTag)
	{
		case 0:
			_core.status = TCStatusOffline;
			break;
			
		case 1:
			_core.status = TCStatusAvailable;
			break;
			
		case 2:
			_core.status = TCStatusAway;
			break;
			
		case 3:
			_core.status = TCStatusXA;
			break;
	}
}

- (IBAction)doAvatar:(id)sender
{
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	openDlg.canChooseFiles = YES;
	openDlg.canChooseDirectories = NO;
	openDlg.canCreateDirectories = NO;
	openDlg.allowsMultipleSelection = NO;
	openDlg.allowedFileTypes = [NSImage imageTypes];
	
	if ([openDlg runModal] == NSModalResponseOK)
	{
		NSArray	*urls = openDlg.URLs;
		NSImage *avatar = [[NSImage alloc] initWithContentsOfURL:urls[0]];

		[self dropButton:_imAvatar doppedImage:avatar];
	}
}

- (IBAction)doTitle:(id)sender
{
	NSMenuItem	*selected = _imTitle.selectedItem;
	NSInteger	tag = selected.tag;
	
	if (!selected)
	{
		NSBeep();
		return;
	}
	
	switch (tag)
	{
		case 0:
			_configuration.modeTitle = TCConfigTitleName;
			break;
			
		case 1:
			_configuration.modeTitle = TCConfigTitleIdentifier;
			break;
			
		case 3:
			[self editProfile];
			break;
	}
	
	[self updateTitleUI];
}

- (IBAction)doAdd:(id)sender
{
	[self addBuddy];
}

- (IBAction)doRemove:(id)sender
{
	[self removeSelectedBuddy];
}

- (IBAction)doAddOk:(id)sender
{
	NSString *identifierString = _addIdentifierField.stringValue;
	NSString *nameString = _addNameField.stringValue;
	NSString *notesString = _addNotesField.textStorage.mutableString;

	if (nameString.length == 0)
		nameString = nil;
	
	if (notesString.length == 0)
		notesString = nil;
	
	[_core addBuddyWithIdentifier:identifierString name:nameString comment:notesString];
	
	[self.window endSheet:_addWindow];
}

- (IBAction)doAddCancel:(id)sender
{
	[self.window endSheet:_addWindow];
}

- (IBAction)doProfileOk:(id)sender
{
	[self.window endSheet:_profileWindow];
	[_profileWindow orderOut:self];
	
	// -- Hold name --
	NSString *name = _profileName.stringValue;
	
	_core.profileName = name;
	
	// -- Hold text --
	NSString *text = _profileText.textStorage.mutableString;
	
	_core.profileText = text;
}

- (IBAction)doProfileCancel:(id)sender
{
	[self.window endSheet:_profileWindow];
	[_profileWindow orderOut:self];
}



/*
** TCBuddiesWindowController - Actions
*/
#pragma mark - TCBuddiesWindowController - Actions

- (void)showSelectedBuddyInfo
{
	// Get selected buddy.
	TCBuddy *buddy = [self selectedBuddy];
	
	if (!buddy)
	{
		NSBeep();
		return;
	}
	
	// Show info window.
	if (!_infoWindowsController)
		_infoWindowsController = [[TCBuddyInfoWindowsController alloc] initWithConfiguration:_configuration coreManager:_core];
	
	[_infoWindowsController showInfoForBuddy:buddy];
}

- (void)addBuddy
{
	_addIdentifierField.stringValue = @"";
	_addNameField.stringValue = @"";
	[_addNotesField.textStorage.mutableString setString:@""];
	
	_addOkButton.enabled = NO;
	
	[self.window beginSheet:_addWindow completionHandler:nil];
	
	[_addWindow makeFirstResponder:_addIdentifierField];
}

- (void)removeClickedBuddy:(id)sender
{
	NSInteger	row = _tableView.clickedRow;
	TCBuddy		*buddy;
	NSString	*identifier;
	
	if (row < 0 || row >= _buddies.count)
		return;
	
	// Get the buddy identifier.
	buddy = _buddies[(NSUInteger)row];
	identifier = buddy.identifier;
	
	// Remove the buddy from the controller.
	[_core removeBuddyWithIdentifier:identifier];
}

- (void)removeSelectedBuddy
{
	NSInteger	row = _tableView.selectedRow;
	TCBuddy		*buddy;
	NSString	*identifier;
	
	if (row < 0 || row >= _buddies.count)
		return;
	
	// Get the buddy identifier.
	buddy = _buddies[(NSUInteger)row];
	identifier = buddy.identifier;
	
	// Remove the buddy from the controller.
	[_core removeBuddyWithIdentifier:identifier];
}

- (void)startChatWithSelectedBuddy
{
	NSInteger	row = _tableView.selectedRow;
	TCBuddy		*buddy;
	
	if (row < 0 || row >= _buddies.count)
		return;
	
	buddy = _buddies[(NSUInteger)row];
	
	[self startChatForBuddy:buddy];
}

- (void)sendFileToSelectedBuddy
{
	NSInteger	row = _tableView.selectedRow;
	TCBuddy		*buddy;
	
	if (row < 0 || row >= _buddies.count)
		return;
	
	buddy = _buddies[(NSUInteger)row];
	
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	openDlg.canChooseFiles = YES;
	openDlg.canChooseDirectories = NO;
	openDlg.canCreateDirectories = NO;
	openDlg.allowsMultipleSelection = YES;
	
	if ([openDlg runModal] == NSModalResponseOK)
	{
		NSArray *urls = openDlg.URLs;
		
		for (NSURL *url in urls)
		{
			NSString *path = url.path;
			
			if (path)
				[buddy sendFileAtPath:path];
		}
	}
}

- (void)toggleBlockForClickedBuddy:(id)sender
{
	NSInteger	row = _tableView.clickedRow;
	TCBuddy		*buddy;
	
	if (row < 0 || row >= _buddies.count)
		return;
	
	buddy = _buddies[(NSUInteger)row];
	
	if (buddy.blocked)
		[_core removeBlockedBuddyWithIdentifier:buddy.identifier];
	else
		[_core addBlockedBuddyWithIdentifier:buddy.identifier];
}

- (void)toggleBlockForSelectedBuddy
{
	NSInteger	row = _tableView.selectedRow;
	TCBuddy		*buddy;
	
	if (row < 0 || row >= _buddies.count)
		return;
	
	buddy = _buddies[(NSUInteger)row];
	
	if (buddy.blocked)
		[_core removeBlockedBuddyWithIdentifier:buddy.identifier];
	else
		[_core addBlockedBuddyWithIdentifier:buddy.identifier];
}

- (void)editProfile
{
	NSString *tname = _core.profileName;
	NSString *ttext = _core.profileText;
	
	_profileName.stringValue = (tname ?: @"");
	[_profileText.textStorage.mutableString setString:(ttext ?: @"")];
	
	[self.window beginSheet:_profileWindow completionHandler:nil];
}



/*
** TCBuddiesWindowController - Tools
*/
#pragma mark - TCBuddiesWindowController - Tools

- (void)reloadBuddies
{
	dispatch_async(dispatch_get_main_queue(), ^{

		// Sort buddies by status.
		NSUInteger		i, cnt = _buddies.count;
		NSMutableArray	*temp_block = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_off = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_av = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_aw = [[NSMutableArray alloc] initWithCapacity:cnt];
		NSMutableArray	*temp_xa = [[NSMutableArray alloc] initWithCapacity:cnt];
		
		for (i = 0; i < cnt; i++)
		{
			TCBuddy *buddy = _buddies[i];
			
			if (buddy.blocked)
				[temp_block addObject:buddy];
			else
			{
				switch (buddy.status)
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
			return [buddy1.finalName compare:buddy2.finalName];
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

	[_mainController.chatController openChatWithBuddy:buddy select:YES];
}

- (nullable TCBuddy *)selectedBuddy
{
	NSInteger row = _tableView.selectedRow;
	
	if (row < 0 || row >= _buddies.count)
		return nil;
	
	return _buddies[(NSUInteger)row];
}

- (void)updateStatusUI:(TCStatus)status
{
	// Unselect old item
	for (NSMenuItem *item in _imStatus.itemArray)
		item.state = NSOffState;
	
	// Select the new item
	NSInteger index = [_imStatus indexOfItemWithTag:status];
	
	if (index > -1)
	{
		NSMenuItem *select = [_imStatus itemAtIndex:index];
		NSMenuItem *title = [_imStatus itemAtIndex:0];
		
		title.title = select.title;
		select.state = NSOnState;
		
		_imStatusImage.image = select.image;
	}
}

- (void)updateTitleUI
{	
	NSString *content = nil;
	
	if (_configuration)
	{
		// Check the title to show
		switch (_configuration.modeTitle)
		{
			case TCConfigTitleIdentifier:
			{
				content = _configuration.selfIdentifier;
				
				[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]].state = NSOffState;
				[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]].state = NSOnState;
				
				break;
			}
				
			case TCConfigTitleName:
			{
				content = _core.profileName;
								
				[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]].state = NSOnState;
				[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]].state = NSOffState;
				
				break;
			}
		}
	}
	else
	{
		[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:0]].state = NSOffState;
		[_imTitle itemAtIndex:[_imTitle indexOfItemWithTag:1]].state = NSOffState;
	}
	
	// Update popup-title
	if (content.length == 0)
		content = @"-";
	
	[_imTitle itemAtIndex:0].title = content;
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
		NSInteger index = _tableView.selectedRow;
		
		[_tableView reloadData];
		
		if (index != NSNotFound)
			[_tableView selectRowIndexes:[NSIndexSet indexSetWithIndex:(NSUInteger)index] byExtendingSelection:NO];
	}
}

@end


NS_ASSUME_NONNULL_END
