/*
 *  TCPreferencesWindowController.m
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

#import "TCPreferencesWindowController.h"

#import "TCMainController.h"
#import "TCBuddiesWindowController.h"

#import "NSWindow+Content.h"

#import "TCPrefView.h"
#import "TCPrefView_General.h"
#import "TCPrefView_Network.h"
#import "TCPrefView_Buddies.h"
#import "TCPrefView_Locations.h"
#import "TCPrefView_Security.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPrefView - Private
*/
#pragma mark - TCPrefView - Private

@interface TCPrefView ()

@property (strong, nonatomic) id <TCConfigAppEncryptable>	config;
@property (strong, nonatomic) TCCoreManager					*core;

@property (strong, nonatomic) void (^disablePanelSaving)(BOOL disable);

@end



/*
** TCPreferencesWindowController - Private
*/
#pragma mark - TCPreferencesWindowController - Private

@interface TCPreferencesWindowController () <NSWindowDelegate>
{
	id <TCConfigAppEncryptable> _configuration;
	TCCoreManager				*_core;

	TCPrefView	*_currentCtrl;
	
	BOOL _disabledSaving;
}

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

- (instancetype)initWithConfiguration:(id <TCConfigAppEncryptable>)configuration coreManager:(TCCoreManager *)coreManager
{
	self = [super initWithWindow:nil];
	
    if (self)
	{
		_configuration = configuration;
		_core = coreManager;
    }
    
    return self;
}



/*
** TCPreferencesWindowController - NSWindowController
*/
#pragma mark - TCPreferencesWindowController - NSWindowController

- (nullable NSString *)windowNibName
{
	return @"PreferencesWindow";
}

- (id)owner
{
	return self;
}

- (void)windowDidLoad
{
	// Delegate.
	self.window.delegate = self;

	// Select the view.
	NSString *identifier = [_configuration generalSettingValueForKey:@"preference_id"];
	
	if (!identifier)
		identifier = @"general";
	
	[self loadViewIdentifier:identifier animated:NO];
	
	// Place window.
	NSString *windowFrame = [_configuration generalSettingValueForKey:@"window-frame-preferences"];
	
	if (windowFrame)
		[self.window setFrameFromString:windowFrame];
	else
		[self.window center];
}

- (void)windowWillClose:(NSNotification *)notification
{
	[self saveCurrentPanel];
}



/*
** TCPreferencesWindowController - Synchronize
*/
#pragma mark - TCPreferencesWindowController - Synchronize

- (void)synchronizeWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_async(dispatch_get_main_queue(), ^{
				
		if (self.windowLoaded)
		{
			[_configuration setGeneralSettingValue:self.window.stringWithSavedFrame forKey:@"window-frame-preferences"];
			[self saveCurrentPanel];
		}
		
		handler();
	});
}



/*
** TCPreferencesWindowController - IBAction
*/
#pragma mark - TCPreferencesWindowController - IBAction

- (IBAction)doToolbarItem:(id)sender
{
	NSToolbarItem	*item = sender;
	NSString		*identifier = item.itemIdentifier;
	
	[self loadViewIdentifier:identifier animated:YES];
}



/*
** TCPreferencesWindowController - Tools
*/
#pragma mark - TCPreferencesWindowController - Tools

- (void)loadViewIdentifier:(NSString *)identifier animated:(BOOL)animated
{
	TCPrefView *viewCtrl = nil;

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
	
	NSAssert(viewCtrl, @"viewCtrl is nil - unknown identifier");
	
	// Save current identifier.
	[_configuration setGeneralSettingValue:identifier forKey:@"preference_id"];
	
	// Check if the toolbar item is well selected
	if ([self.window.toolbar.selectedItemIdentifier isEqualToString:identifier] == NO)
		self.window.toolbar.selectedItemIdentifier = identifier;
	
	// Save current view config.
	_currentCtrl.config = _configuration;
	_currentCtrl.core = _core;
	
	[_currentCtrl panelSaveConfiguration];
	
	// Load new view config.	
	viewCtrl.config = _configuration;
	viewCtrl.core = _core;
	viewCtrl.disablePanelSaving = ^(BOOL disable) {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (disable == _disabledSaving)
				return;
			
			// > Disable tool bar.
			NSArray<__kindof NSToolbarItem *> *items = self.window.toolbar.items;
			
			for (NSToolbarItem *item in items)
			{
				item.autovalidates = !disable;
				item.enabled = !disable;
			}
			
			// > Disable close button.
			[self.window standardWindowButton:NSWindowCloseButton].enabled = !disable;
			
			// > Set disable flag.
			_disabledSaving = disable;
		});
	};
	
	// Load view, then load configuration.
	NSView *view = viewCtrl.view;

	[viewCtrl panelLoadConfiguration];
	
	// Compute target rect.
	TCPrefView *oldCtrl = _currentCtrl;
	
	[oldCtrl switchingOut];
	
	[self.window switchContentToView:view animated:animated completionHandler:^{
		[viewCtrl switchingIn];
	}];

	
	// Hold the current controller.
	_currentCtrl = viewCtrl;
}

- (void)saveCurrentPanel
{
	// If disappearance is disabled (invalid panel settings, etc.), then... just ignore close
	if (_disabledSaving)
		return;
	
	_currentCtrl.config = _configuration;
	_currentCtrl.core = _core;
	
	[_currentCtrl panelSaveConfiguration];
}

@end


NS_ASSUME_NONNULL_END
