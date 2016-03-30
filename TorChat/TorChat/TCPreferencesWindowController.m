/*
 *  TCPreferencesWindowController.m
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

#import "TCPreferencesWindowController.h"

#import "TCMainController.h"
#import "TCBuddiesWindowController.h"

#import "TCPrefView.h"
#import "TCPrefView_General.h"
#import "TCPrefView_Network.h"
#import "TCPrefView_Buddies.h"
#import "TCPrefView_Locations.h"
#import "TCPrefView_Security.h"


/*
** TCPrefView - Private
*/
#pragma mark - TCPrefView - Private

@interface TCPrefView ()

@property (strong, nonatomic) id <TCConfigAppEncryptable>	config;
@property (strong, nonatomic) TCCoreManager				*core;

@property (strong, nonatomic) void (^reloadConfig)(dispatch_block_t doneHandler);

@end



/*
** TCPreferencesWindowController - Private
*/
#pragma mark - TCPreferencesWindowController - Private

@interface TCPreferencesWindowController ()
{
	IBOutlet NSView *_loadingView;
	
	TCPrefView	*_currentCtrl;
}


// -- IBAction --
- (IBAction)doToolbarItem:(id)sender;

// -- Helpers --
- (void)loadViewIdentifier:(NSString *)identifier animated:(BOOL)animated;

@end



/*
** TCPreferencesWindowController
*/
#pragma mark - TCPreferencesWindowController

@implementation TCPreferencesWindowController


/*
** TCPreferencesWindowController - Instance
*/
#pragma mark - TCPreferencesWindowController - Instance

+ (TCPreferencesWindowController *)sharedController
{
	static dispatch_once_t					onceToken;
	static TCPreferencesWindowController	*instance = nil;
	
	dispatch_once(&onceToken, ^{
		instance = [[TCPreferencesWindowController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super initWithWindowNibName:@"PreferencesWindow"];
	
    if (self)
	{
    }
    
    return self;
}

- (void)windowDidLoad
{
	// Select the view.
	NSString *identifier = [[NSUserDefaults standardUserDefaults] valueForKey:@"preference_id"];
	
	if (!identifier)
		identifier = @"general";
	
	[self loadViewIdentifier:identifier animated:NO];

	// Place Window.
	[self.window center];
	[self.window setFrameAutosaveName:@"PreferencesWindow"];
}



/*
** TCPreferencesWindowController - Tools
*/
#pragma mark - TCPreferencesWindowController - Tools

- (void)loadViewIdentifier:(NSString *)identifier animated:(BOOL)animated
{
	TCPrefView *viewCtrl = nil;
	id <TCConfigAppEncryptable> config = [[TCMainController sharedController] configuration];
	TCCoreManager *core = [[TCMainController sharedController] core];

	if ([identifier isEqualToString:@"general"])
		viewCtrl = [[TCPrefView_General alloc] init];
	else if ([identifier isEqualToString:@"network"])
		viewCtrl = [[TCPrefView_Network alloc] init];
	else if ([identifier isEqualToString:@"buddies"])
		viewCtrl = [[TCPrefView_Buddies alloc] init];
	else if ([identifier isEqualToString:@"locations"])
		viewCtrl = [[TCPrefView_Locations alloc] init];
	else if ([identifier isEqualToString:@"security"])
		viewCtrl = [[TCPrefView_Security alloc] init];
	
	if (!viewCtrl)
		return;
	
	// Save current identifier.
	[[NSUserDefaults standardUserDefaults] setValue:identifier forKey:@"preference_id"];
	
	// Check if the toolbar item is well selected
	if ([[[self.window toolbar] selectedItemIdentifier] isEqualToString:identifier] == NO)
		[[self.window toolbar] setSelectedItemIdentifier:identifier];
	
	// Save current view config.
	_currentCtrl.config = config;
	_currentCtrl.core = core;
	
	[_currentCtrl panelDidDisappear];
	
	
	// Load new view config.
	__weak TCPrefView *weakViewCtrl = viewCtrl;
	
	viewCtrl.config = config;
	viewCtrl.core = core;
	viewCtrl.reloadConfig = ^(dispatch_block_t doneHandler) {
		
		// Lock UI.
		__block BOOL isVisible;
		
		dispatch_async(dispatch_get_main_queue(), ^{
			isVisible = self.window.isVisible;
			
			if (isVisible)
				[self _lockForLoading];
		});
		
		// Restart main controller.
		[[TCMainController sharedController] startWithConfiguration:config completionHandler:^(TCCoreManager *aCore) {

			if (!aCore)
			{
				[[NSApplication sharedApplication] terminate:nil];
				return;
			}
			
			dispatch_async(dispatch_get_main_queue(), ^{
				
				weakViewCtrl.core = aCore;
				
				if (doneHandler)
					doneHandler();
				
				if (isVisible)
					[self _unloadForLoading];
			});
		}];
	};
	
	[viewCtrl panelDidAppear];
		
	NSView *view = viewCtrl.view;
	
	// Compute target rect.
	NSRect	rect = [self.window frame];
	NSSize	csize = [[self.window contentView] frame].size;
	NSSize	size = [view frame].size;
	CGFloat	previous = rect.size.height;
	
	rect.size.width = (rect.size.width - csize.width) + size.width;
	rect.size.height = (rect.size.height - csize.height) + size.height;
	
	rect.origin.y += (previous - rect.size.height);
	
	// Load view.
	if (animated)
	{
		[NSAnimationContext beginGrouping];
		{
			[[NSAnimationContext currentContext] setDuration:0.125];
			
			[[[self.window contentView] animator] replaceSubview:_currentCtrl.view with:view];
			[[self.window animator] setFrame:rect display:YES];
		}
		[NSAnimationContext endGrouping];
	}
	else
	{
		[_currentCtrl.view removeFromSuperview];
		[[self.window contentView] addSubview:view];
		[self.window setFrame:rect display:YES];
	}
	
	// Hold the current controller.
	_currentCtrl = viewCtrl;
}

- (void)_lockForLoading
{
	// > main queue <

	// Add load view.
	if (_loadingView.superview == nil)
	{
		NSDictionary	*viewsDictionary;
		NSView			*view = _loadingView;
		
		[self.window.contentView addSubview:view];
		
		viewsDictionary = NSDictionaryOfVariableBindings(view);
		
		[self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:viewsDictionary]];
		[self.window.contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:viewsDictionary]];
	}
}

- (void)_unloadForLoading
{
	// > main queue <
	
	// Remove subview.
	if (_loadingView.superview != nil)
	{
		[_loadingView removeFromSuperview];
	}
}



/*
** TCPreferencesWindowController - IBAction
*/
#pragma mark - TCPreferencesWindowController - IBAction

- (IBAction)doToolbarItem:(id)sender
{
	NSToolbarItem	*item = sender;
	NSString		*identifier = [item itemIdentifier];
	
	[self loadViewIdentifier:identifier animated:YES];
}



/*
** TCPreferencesWindowController - NSWindow
*/
#pragma mark - TCPreferencesWindowController - NSWindow

- (void)windowWillClose:(NSNotification *)notification
{
	id <TCConfigAppEncryptable> config = [[TCMainController sharedController] configuration];
	TCCoreManager				*core = [[TCMainController sharedController] core];
	
	_currentCtrl.config = config;
	_currentCtrl.core = core;
	
	[_currentCtrl panelDidDisappear];
}

@end
