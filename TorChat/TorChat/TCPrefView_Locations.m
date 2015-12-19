//
//  TCPrefView_Locations.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2016 SourceMac. All rights reserved.
//

#import "TCPrefView_Locations.h"

#import "TCLocationViewController.h"


/*
** TCPrefView_Locations
*/
#pragma mark - TCPrefView_Locations

@implementation TCPrefView_Locations
{
	IBOutlet NSTextField	*referalTextField;
	IBOutlet NSPathControl	*configPath;
	
	IBOutlet NSView	*torBinaryView;
	IBOutlet NSView *torDataView;
	IBOutlet NSView *torIdentityView;
	IBOutlet NSView *downloadsView;
	
	TCLocationViewController *_torBinaryLocation;
	TCLocationViewController *_torDataLocation;
	TCLocationViewController *_torIdentityLocation;
	TCLocationViewController *_torDownloadsLocation;
}


/*
** TCPrefView_Locations - Instance
*/
#pragma mark - TCPrefView_Locations - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_Locations" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// Load tor binary view.
	_torBinaryLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TConfigPathComponentTorBinary];
	
	[_torBinaryLocation addToView:torBinaryView];
	
	// Load tor data view.
	_torDataLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TConfigPathComponentTorData];
	
	[_torDataLocation addToView:torDataView];
	
	// Load tor identity view.
	_torIdentityLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TConfigPathComponentTorIdentity];
	
	[_torIdentityLocation addToView:torIdentityView];
	
	// Load downloads view.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:self.config component:TConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:downloadsView];
}



/*
** TCPrefView_Locations - TCPrefView
*/
#pragma mark - TCPrefView_Locations - TCPrefView

- (void)loadConfig
{
	// Load view.
	[self view];

	// Load configuration.
	[self loadConfiguration];
}

- (void)saveConfig
{
	
}



/*
** TCPrefView_Locations - IBAction
*/
#pragma mark - TCPrefView_Locations - IBAction


- (IBAction)doSelectReferal:(id)sender
{
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
				
				// > Compose a default path.
				NSBundle *bundle = [NSBundle mainBundle];
				NSString *path = [[bundle bundlePath] stringByDeletingLastPathComponent];

				// > Replace current value.
				[self.config setPathForComponent:TConfigPathComponentReferal pathType:TConfigPathTypeAbsolute path:path];
				
				// > Reload configuration.
				[self loadConfiguration];
			});
		}];

		
	}
	else
	{
		// Configure open panel.
		NSString	*fullPath = [self.config pathForComponent:TConfigPathComponentReferal fullPath:YES];
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
				// > Replace current value.
				[self.config setPathForComponent:TConfigPathComponentReferal pathType:TConfigPathTypeAbsolute path:selectedPath];
				
				// > Reload configuration.
				[self loadConfiguration];
			});
		}];
	}

#warning FIXME Changing referal domain can change other path. Notify other domains of that (probably that each full path should be computed before).
}

- (IBAction)doRevealReferal:(id)sender
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

- (void)loadConfiguration
{
	NSString *refPath = [self.config pathForComponent:TConfigPathComponentReferal fullPath:YES];
	
	[referalTextField setStringValue:refPath];
	[configPath setURL:[[NSURL fileURLWithPath:refPath] URLByAppendingPathComponent:@"torchat.conf"]];
	
	[_torBinaryLocation reloadConfiguration];
	[_torDataLocation reloadConfiguration];
	[_torIdentityLocation reloadConfiguration];
	[_torDownloadsLocation reloadConfiguration];
}

@end
