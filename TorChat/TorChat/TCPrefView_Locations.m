/*
 *  TCPrefView_Locations.m
 *
 *  Copyright 2019 Avérous Julien-Pierre
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

#import "TCPrefView_Locations.h"

#import "TCLocationViewController.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPrefView_Locations
*/
#pragma mark - TCPrefView_Locations

@implementation TCPrefView_Locations
{
	IBOutlet NSTextField	*referralTextField;
	IBOutlet NSPathControl	*configPath;
	
	IBOutlet NSView	*torBinaryView;
	IBOutlet NSView *torDataView;
	IBOutlet NSView *downloadsView;
	
	TCLocationViewController *_torBinaryLocation;
	TCLocationViewController *_torDataLocation;
	TCLocationViewController *_torDownloadsLocation;
	
	id _pathObserver;
}



/*
** TCPrefView_Locations - Instance
*/
#pragma mark - TCPrefView_Locations - Instance

- (instancetype)init
{
	self = [super initWithNibName:@"PrefView_Locations" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}



/*
** TCPrefView_Locations - NSViewController
*/
#pragma mark - TCPrefView_Locations - NSViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// Load tor binary view.
	_torBinaryLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TCConfigPathComponentTorBinary];
	
	[_torBinaryLocation addToView:torBinaryView];
	
	// Load tor data view.
	_torDataLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TCConfigPathComponentTorData];
	
	[_torDataLocation addToView:torDataView];
	
	// Load downloads view.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:downloadsView];
}

- (void)viewWillAppear
{
	[super viewWillAppear];
	
	// Observe referral change.
	__weak TCPrefView_Locations *weakSelf = self;
	
	_pathObserver = [self.config addPathObserverForComponent:TCConfigPathComponentReferral queue:dispatch_get_main_queue() usingBlock:^{
		[weakSelf reloadConfiguration];
	}];
}

- (void)viewDidDisappear
{
	[super viewDidDisappear];
	
	[self.config removePathObserver:_pathObserver];
}


/*
** TCPrefView_Locations - TCPrefView
*/
#pragma mark - TCPrefView_Locations - TCPrefView

- (void)panelLoadConfiguration
{
	// Load configuration.
	[self reloadConfiguration];
}



/*
** TCPrefView_Locations - IBAction
*/
#pragma mark - TCPrefView_Locations - IBAction


- (IBAction)doSelectReferral:(id)sender
{
	NSUInteger flags = [NSApplication sharedApplication].currentEvent.modifierFlags;
	
	if (flags & NSEventModifierFlagOption)
	{
		// Configure alert panel.
		NSAlert *alert = [[NSAlert alloc] init];
		
		alert.messageText = NSLocalizedString(@"location_reset_title", @"") ;
		alert.informativeText = NSLocalizedString(@"location_reset_message", @"");
		
		[alert addButtonWithTitle:NSLocalizedString(@"location_reset", @"")];
		[alert addButtonWithTitle:NSLocalizedString(@"location_cancel", @"")];
		
		// Ask user for confirmation.
		[alert beginSheetModalForWindow:(NSWindow *)self.view.window completionHandler:^(NSModalResponse returnCode) {
			
			if (returnCode != NSAlertFirstButtonReturn)
				return;
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				// > Compose a default path.
				NSBundle *bundle = [NSBundle mainBundle];
				NSString *path = bundle.bundlePath.stringByDeletingLastPathComponent;

				// > Replace current value.
				[self.config setPathForComponent:TCConfigPathComponentReferral pathType:TCConfigPathTypeAbsolute path:path];
			});
		}];
	}
	else
	{
		// Configure open panel.
		NSString	*fullPath = [self.config pathForComponent:TCConfigPathComponentReferral fullPath:YES];
		NSOpenPanel	*openPanel = [NSOpenPanel openPanel];
		
		openPanel.canChooseDirectories = YES;
		openPanel.canChooseFiles = NO;
		openPanel.resolvesAliases = NO;
		openPanel.canCreateDirectories = YES;
		
		if (fullPath)
			openPanel.directoryURL = [NSURL fileURLWithPath:fullPath];
		
		// Ask user to select a directory.
		[openPanel beginWithCompletionHandler:^(NSInteger result) {
			
			if (result != NSModalResponseOK)
				return;
			
			// > Set selected directory.
			NSString *selectedPath = openPanel.URL.path;
			
			// > Replace current value.
			dispatch_async(dispatch_get_main_queue(), ^{
				[self.config setPathForComponent:TCConfigPathComponentReferral pathType:TCConfigPathTypeAbsolute path:selectedPath];
			});
		}];
	}
}

- (IBAction)doRevealReferral:(id)sender
{
	NSString *fullPath = configPath.URL.path;
	
	if (!fullPath)
	{
		NSBeep();
		return;
	}
	
	[[NSWorkspace sharedWorkspace] selectFile:fullPath inFileViewerRootedAtPath:@""];
}



/*
** TCPrefView_Locations - Helpers
*/
#pragma mark - TCPrefView_Locations - Helpers

- (void)reloadConfiguration
{
	NSString *refPath = [self.config pathForComponent:TCConfigPathComponentReferral fullPath:YES];
	
	referralTextField.stringValue = refPath;
	configPath.URL = [[NSURL fileURLWithPath:refPath] URLByAppendingPathComponent:@"torchat.conf"];
}

@end


NS_ASSUME_NONNULL_END
