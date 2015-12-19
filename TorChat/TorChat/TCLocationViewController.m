//
//  TCLocationViewController.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 15/01/2015.
//  Copyright (c) 2016 SourceMac. All rights reserved.
//

#import "TCLocationViewController.h"



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
	TConfigPathComponent	_component;
}


/*
** TCLocationViewController - Instance
*/
#pragma mark - TCLocationViewController - Instance

- (instancetype)initWithConfiguration:(id <TCConfig>)configuration component:(TConfigPathComponent)component
{
	self = [super initWithNibName:@"LocationView" bundle:nil];
	
	if (self)
	{
		if (!configuration || component == TConfigPathComponentReferal)
			return nil;
		
		_configuration = configuration;
		_component = component;
	}
	
	return self;
}


- (void)viewDidLoad
{
	[super viewDidLoad];

	[self loadConfiguration];
}



/*
** TCLocationViewController - IBAction
*/
#pragma mark - TCLocationViewController - IBAction

- (IBAction)doChangePlace:(id)sender
{
	NSInteger			index = [placePopupButton indexOfSelectedItem];
	TConfigPathType		pathType;

	// Compute domain & new path.
	NSString *path = nil;
	
	if (index == 0)
	{
		NSString	*refPath = [_configuration pathForComponent:TConfigPathComponentReferal fullPath:YES];
		NSString	*fullPath = [_configuration pathForComponent:_component fullPath:YES];

		pathType = TConfigPathTypeReferal;
		path = [[self stringWithPath:fullPath relativeTo:refPath] stringByAppendingString:@"/"];
	}
	else if (index == 1)
	{
		pathType = TConfigPathTypeStandard;
	}
	else if (index == 2)
	{
		pathType = TConfigPathTypeAbsolute;
		path = [_configuration pathForComponent:_component fullPath:YES];
	}
	else
	{
		NSBeep();
		return;
	}
	
	[_configuration setPathForComponent:_component pathType:pathType path:path];
#warning FIXME: notify path changed for domain _domain, with old ful path = fullPath

	// Reload configuration.
	[self loadConfiguration];
}

- (IBAction)doSelectPlace:(id)sender
{
	// Get & check current path type.
	TConfigPathType pathType = [_configuration pathTypeForComponent:_component];
	
	if (pathType == TConfigPathTypeStandard)
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
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				// > Remove current value.
				[_configuration setPathForComponent:_component pathType:pathType path:nil];
				
#warning FIXME: notify path changed for domain _domain, with old ful path = fullPath

				// > Reload configuration.
				[self loadConfiguration];
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
					case TConfigPathTypeReferal:
					{
						NSString *refPath = [_configuration pathForComponent:TConfigPathComponentReferal fullPath:YES];
						NSString *subPath = [[self stringWithPath:selectedPath relativeTo:refPath] stringByAppendingString:@"/"];
						
						[_configuration setPathForComponent:_component pathType:TConfigPathTypeReferal path:subPath];
						
						break;
					}
						
					case TConfigPathTypeStandard:
						break;
						
					case TConfigPathTypeAbsolute:
					{
						[_configuration setPathForComponent:_component pathType:TConfigPathTypeAbsolute path:selectedPath];
						break;
					}
				}
				
#warning FIXME: notify path changed for domain _domain, with old ful path = fullPath

				// > Reload configuration.
				[self loadConfiguration];
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

- (void)reloadConfiguration
{
	[self loadConfiguration];
}



/*
** TCLocationViewController - Helpers
*/
#pragma mark - TCLocationViewController - Helpers

- (void)loadConfiguration
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
	TConfigPathType pathType = [_configuration pathTypeForComponent:_component];
	
	switch (pathType)
	{
		case TConfigPathTypeReferal:
			[placePopupButton selectItemAtIndex:0];
			[subPathField setEnabled:YES];
			[folderButton setEnabled:YES];
			break;
			
		case TConfigPathTypeStandard:
			[placePopupButton selectItemAtIndex:1];
			[subPathField setEnabled:NO];
			[folderButton setEnabled:NO];
			break;
			
		case TConfigPathTypeAbsolute:
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
