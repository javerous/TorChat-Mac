/*
 *  TCLocationViewController.m
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

#import "TCLocationViewController.h"

#import "TCDebugLog.h"


/*
** TCLocationViewController
*/
#pragma mark - TCLocationViewController

@implementation TCLocationViewController
{
	IBOutlet NSPopUpButton	*placePopupButton;
	IBOutlet NSButton		*folderButton;
	IBOutlet NSTextField	*subPathField;
	IBOutlet NSPathControl	*pathView;
	
	id <TCConfig>			_configuration;
	TCConfigPathComponent	_component;
	
	id _pathObserver;
}



/*
** TCLocationViewController - Instance
*/
#pragma mark - TCLocationViewController - Instance

- (instancetype)initWithConfiguration:(id <TCConfig>)configuration component:(TCConfigPathComponent)component
{
	self = [super initWithNibName:@"LocationView" bundle:nil];
	
	if (self)
	{
		if (!configuration || component == TCConfigPathComponentReferal)
			return nil;
		
		_configuration = configuration;
		_component = component;
		
		// Observe change.
		__weak TCLocationViewController *weakSelf = self;
		
		_pathObserver = [configuration addPathObserverForComponent:component queue:dispatch_get_main_queue() usingBlock:^{
			[weakSelf reloadConfiguration];
		}];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCLocationViewController Dealloc");
	[_configuration removePathObserver:_pathObserver];
}


- (void)viewDidLoad
{
	[super viewDidLoad];

	[self reloadConfiguration];
}



/*
** TCLocationViewController - IBAction
*/
#pragma mark - TCLocationViewController - IBAction

- (IBAction)doChangePlace:(id)sender
{
	NSInteger			index = [placePopupButton indexOfSelectedItem];
	TCConfigPathType		pathType;

	// Compute domain & new path.
	NSString *path = nil;
	
	if (index == 0)
	{
		NSString	*refPath = [_configuration pathForComponent:TCConfigPathComponentReferal fullPath:YES];
		NSString	*fullPath = [_configuration pathForComponent:_component fullPath:YES];

		pathType = TCConfigPathTypeReferal;
		path = [[self stringWithPath:fullPath relativeTo:refPath] stringByAppendingString:@"/"];
	}
	else if (index == 1)
	{
		pathType = TCConfigPathTypeStandard;
	}
	else if (index == 2)
	{
		pathType = TCConfigPathTypeAbsolute;
		path = [_configuration pathForComponent:_component fullPath:YES];
	}
	else
	{
		NSBeep();
		return;
	}
	
	[_configuration setPathForComponent:_component pathType:pathType path:path];
}

- (IBAction)doSelectPlace:(id)sender
{
	// Get & check current path type.
	TCConfigPathType pathType = [_configuration pathTypeForComponent:_component];
	
	if (pathType == TCConfigPathTypeStandard)
	{
		NSBeep();
		return;
	}
	
	NSUInteger flags = [[[NSApplication sharedApplication] currentEvent] modifierFlags];
	
	if (flags & NSAlternateKeyMask)
	{
		// Configure alert panel.
		NSAlert *alert = [[NSAlert alloc] init];
		
		alert.messageText = NSLocalizedString(@"location_reset_title", @"") ;
		alert.informativeText = NSLocalizedString(@"location_reset_message", @"");
		
		[alert addButtonWithTitle:NSLocalizedString(@"location_reset", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"location_cancel", @"")];

		// Ask user for confirmation.
		[alert beginSheetModalForWindow:self.view.window completionHandler:^(NSModalResponse returnCode) {
			
			if (returnCode != NSAlertFirstButtonReturn)
				return;
			
			// > Remove current value.
			dispatch_async(dispatch_get_main_queue(), ^{
				[_configuration setPathForComponent:_component pathType:pathType path:nil];
			});
		}];
	}
	else
	{
		// Configure open panel.
		NSString	*fullPath = [_configuration pathForComponent:_component fullPath:YES];
		NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
		
		openPanel.canChooseDirectories = YES;
		openPanel.canChooseFiles = NO;
		openPanel.resolvesAliases = NO;
		openPanel.canCreateDirectories = YES;

		if (fullPath)
			openPanel.directoryURL = [NSURL fileURLWithPath:fullPath];
		
		// Ask user to select a directory.
		[openPanel beginWithCompletionHandler:^(NSInteger result) {
			
			if (result != NSFileHandlingPanelOKButton)
				return;
			
			// > Set selected directory.
			NSString *selectedPath = openPanel.URL.path;
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				switch (pathType)
				{
					case TCConfigPathTypeReferal:
					{
						NSString *refPath = [_configuration pathForComponent:TCConfigPathComponentReferal fullPath:YES];
						NSString *subPath = [[self stringWithPath:selectedPath relativeTo:refPath] stringByAppendingString:@"/"];
						
						[_configuration setPathForComponent:_component pathType:TCConfigPathTypeReferal path:subPath];
						
						break;
					}
						
					case TCConfigPathTypeStandard:
						break;
						
					case TCConfigPathTypeAbsolute:
					{
						[_configuration setPathForComponent:_component pathType:TCConfigPathTypeAbsolute path:selectedPath];
						break;
					}
				}
			});
		}];
	}
}

- (IBAction)doRevealPlace:(id)sender
{
	NSString *fullPath = pathView.URL.path;

	if (!fullPath)
	{
		NSBeep();
		return;
	}
	
	[[NSWorkspace sharedWorkspace] selectFile:fullPath inFileViewerRootedAtPath:@""];
}



/*
** TCLocationViewController - Tools
*/
#pragma mark - TCLocationViewController - Tools

- (void)addToView:(NSView *)view
{
	if (!view)
		return;
	
	NSRect viewFrame = view.frame;
	
	[self.view setFrame:NSMakeRect(0, 0, viewFrame.size.width, viewFrame.size.height)];
	
	[view addSubview:self.view];
}



/*
** TCLocationViewController - Helpers
*/
#pragma mark - TCLocationViewController - Helpers

- (void)reloadConfiguration
{
	// Show fullpath.
	NSString *fullPath = [_configuration pathForComponent:_component fullPath:YES];
	
	if (!fullPath)
		fullPath = @"";
	
	[pathView setURL:[NSURL fileURLWithPath:fullPath]];
	
	// Show subpath.
	NSString *subPath = [_configuration pathForComponent:_component fullPath:NO];
	
	if (!subPath)
		subPath = @"";
	
	[subPathField setStringValue:subPath];
	
	// Show place.
	TCConfigPathType pathType = [_configuration pathTypeForComponent:_component];
	
	switch (pathType)
	{
		case TCConfigPathTypeReferal:
			[placePopupButton selectItemAtIndex:0];
			[subPathField setEnabled:YES];
			[folderButton setEnabled:YES];
			break;
			
		case TCConfigPathTypeStandard:
			[placePopupButton selectItemAtIndex:1];
			[subPathField setEnabled:NO];
			[folderButton setEnabled:NO];
			break;
			
		case TCConfigPathTypeAbsolute:
			[placePopupButton selectItemAtIndex:2];
			[subPathField setEnabled:YES];
			[folderButton setEnabled:YES];
			break;
	}
}


- (NSString *)stringWithPath:(NSString *)path relativeTo:(NSString*)anchorPath
{
	// Code from "Hilton Campbell" ( http://stackoverflow.com/questions/6539273/objective-c-code-to-generate-a-relative-path-given-a-file-and-a-directory )
	
	NSArray *pathComponents = [path pathComponents];
	NSArray *anchorComponents = [anchorPath pathComponents];
	
	NSUInteger componentsInCommon = MIN([pathComponents count], [anchorComponents count]);
	
	for (NSUInteger i = 0, n = componentsInCommon; i < n; i++)
	{
		if (![[pathComponents objectAtIndex:i] isEqualToString:[anchorComponents objectAtIndex:i]]) {
			componentsInCommon = i;
			break;
		}
	}
	
	NSUInteger numberOfParentComponents = [anchorComponents count] - componentsInCommon;
	NSUInteger numberOfPathComponents = [pathComponents count] - componentsInCommon;
	
	NSMutableArray *relativeComponents = [NSMutableArray arrayWithCapacity:
										  numberOfParentComponents + numberOfPathComponents];
	
	[relativeComponents addObject:@"/"];
	
	for (NSUInteger i = 0; i < numberOfParentComponents; i++)
		[relativeComponents addObject:@".."];
	
	[relativeComponents addObjectsFromArray:[pathComponents subarrayWithRange:NSMakeRange(componentsInCommon, numberOfPathComponents)]];
	
	return [NSString pathWithComponents:relativeComponents];
}

@end
