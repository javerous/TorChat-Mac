/*
 *  TCAssistantWindowController.m
 *
 *  Copyright 2014 Avérous Julien-Pierre
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


#import "TCAssistantWindowController.h"

#import "TCConfigPlist.h"
#import "TCTorManager.h"
#import "TCLogsWindowController.h"

#import "TCPanel.h"

#import "TCDebugLog.h"



/*
** TCAssistantWindowController - Private
*/
#pragma mark - TCAssistantWindowController - Private

@interface TCAssistantWindowController () <TCAssistantProxy>
{
	NSArray					*_panels;
	NSMutableDictionary		*_panelsClass;
	NSMutableDictionary		*_panelsInstances;

	id <TCAssistantPanel>	_currentPanel;
	
	NSString				*_nextID;
	BOOL					_isLast;
	BOOL					_fDisable;
	
	TCAssistantCallback		_callback;
}

// -- Properties --
@property (strong, nonatomic)	IBOutlet NSTextField	*mainTitle;
@property (strong, nonatomic)	IBOutlet NSView			*mainView;
@property (strong, nonatomic)	IBOutlet NSButton		*cancelButton;
@property (strong, nonatomic)	IBOutlet NSButton		*nextButton;

// -- IBAction --
- (IBAction)doCancel:(id)sender;
- (IBAction)doNext:(id)sender;

// -- Tools --
- (void)_switchToPanel:(NSString *)panelID;
- (void)_checkNextButton;

@end



/*
** TCAssistantWindowController
*/
#pragma mark - TCAssistantWindowController

@implementation TCAssistantWindowController


/*
** TCAssistantWindowController - Instance
*/
#pragma mark - TCAssistantWindowController - Instance

+ (TCAssistantWindowController *)startAssistantWithPanels:(NSArray *)panels andCallback:(TCAssistantCallback)callback
{
	TCAssistantWindowController *assistant = [[TCAssistantWindowController alloc] initWithPanels:panels andCallback:callback];
	
	dispatch_async(dispatch_get_main_queue(), ^{
		[assistant showWindow:nil];
	});
	
	return assistant;
}

- (id)initWithPanels:(NSArray *)panels andCallback:(TCAssistantCallback)callback
{
	self = [super initWithWindowNibName:@"AssistantWindow"];
	
	if (self)
	{
		if ([panels count] == 0)
			return nil;
		
		// Handle callback.
		_callback = callback;
		
		// Create containers.
		_panelsClass = [[NSMutableDictionary alloc] init];
		_panelsInstances = [[NSMutableDictionary alloc] init];
		
		// Handle pannels class.
		for (Class <TCAssistantPanel> class in panels)
			[_panelsClass setObject:class forKey:[class identifiant]];
		
		// Handle panels.
		_panels = panels;
	}
	
	return self;
}

- (void)dealloc
{
    TCDebugLog("TCAssistantWindowController dealloc");
}



/*
** TCAssistantWindowController - NSWindowController
*/
#pragma mark - TCAssistantWindowController - NSWindowController

- (void)windowDidLoad
{
	// Show first pannel.
	Class <TCAssistantPanel> class = _panels[0];
	
	[self _switchToPanel:[class identifiant]];
	
	// Show window.
	[self.window center];
}



/*
** TCAssistantWindowController - IBAction
*/
#pragma mark - TCAssistantWindowController - IBAction

- (IBAction)doCancel:(id)sender
{
	[NSApp terminate:sender];
}

- (IBAction)doNext:(id)sender
{
	if (!_currentPanel)
	{
		NSBeep();
		return;
	}
	
	if (_isLast)
	{
		id content = [_currentPanel content];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (_callback)
				_callback(content);
			
			_callback = nil;
		});

		[self.window orderOut:sender];
	}
	else
	{
		// Switch
		[self _switchToPanel:_nextID];
	}
}



/*
** TCAssistantWindowController - Tools
*/
#pragma mark - TCAssistantWindowController - Tools

- (void)_switchToPanel:(NSString *)panelID
{
	// > main queue <
	
	// Check that the panel is not already loaded.
	if ([[[_currentPanel class] identifiant] isEqualToString:panelID])
		return;
	
	// Remove it from current view.
	[[_currentPanel view] removeFromSuperview];
	
	// Get the panel instance.
	id <TCAssistantPanel> panel = _panelsInstances[panelID];
	
	if (!panel)
	{
		Class <TCAssistantPanel> class = _panelsClass[panelID];
		
		panel = [class panelWithProxy:self];
		
		if (panel)
			_panelsInstances[panelID] = panel;
	}
	

	// Set the view
	if (panel)
		[_mainView addSubview:[panel view]];
	
	// Set the title
	_mainTitle.stringValue = [[panel class] title];
	
	// Set the proxy
	_nextID = nil;
	_isLast = YES;
	[_nextButton setEnabled:NO];
	[_nextButton setTitle:NSLocalizedString(@"ac_next_finish", @"")];
	[panel showPanel];
	 
	// Hold the panel
	_currentPanel = panel;
}

- (void)_checkNextButton
{
	// > main queue <
	
	if (_fDisable)
	{
		[_nextButton setEnabled:NO];
		return;
	}
			
	if (_isLast)
		[_nextButton setEnabled:YES];
	else
	{
		Class class = _panelsClass[_nextID];
		
		[_nextButton setEnabled:(class != nil)];
	}
}



/*
** TCAssistantWindowController - Proxy
*/
#pragma mark - TCAssistantWindowController - Proxy

- (void)setNextPanelID:(NSString *)panelID
{
	_nextID = panelID;
	
	[self _checkNextButton];
}

- (void)setIsLastPanel:(BOOL)last
{
	_isLast = last;
	
	if (_isLast)
		[_nextButton setTitle:NSLocalizedString(@"ac_next_finish", @"")];
	else
		[_nextButton setTitle:NSLocalizedString(@"ac_next_continue", @"")];
	
	[self _checkNextButton];
}

- (void)setDisableContinue:(BOOL)disabled
{
	_fDisable = disabled;
	
	[self _checkNextButton];
}

@end
