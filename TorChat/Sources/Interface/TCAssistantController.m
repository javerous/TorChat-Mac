/*
 *  TCAssistantController.mm
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import "TCAssistantController.h"

#import "TCCocoaConfig.h"
#import "TCTorManager.h"
#import "TCLogsController.h"



/*
** TCAssistantController - Private
*/
#pragma mark - TCAssistantController - Private

@interface TCAssistantController () <TCAssistantProxy>
{
	NSMutableDictionary			*_pannels;
	
	id <TCAssistantPanel>		_currentPanel;
	
	NSString					*_nextID;
	BOOL						_isLast;
	BOOL						_fDisable;
	
	id							_respObj;
	SEL							_respSel;
}

- (void)_switchToPanel:(NSString *)panel;
- (void)_checkNextButton;

@end



/*
** TCAssistantController
*/
#pragma mark - TCAssistantController

@implementation TCAssistantController


/*
** TCAssistantController - Instance
*/
#pragma mark - TCAssistantController - Instance

+ (TCAssistantController *)sharedController
{
	static dispatch_once_t			pred;
	static TCAssistantController	*instance = nil;
		
	dispatch_once(&pred, ^{
		instance = [[TCAssistantController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super init];
	
	if (self)
	{
		// Load Bundle
		[[NSBundle mainBundle] loadNibNamed:@"AssistantWindow" owner:self topLevelObjects:nil];
	}
	
	return self;
}

- (void)awakeFromNib
{
	// Catalog pannels
	_pannels = [[NSMutableDictionary alloc] init];
	
	[_pannels setObject:_welcomePanel forKey:[_welcomePanel panelID]];
	[_pannels setObject:_modePanel forKey:[_modePanel panelID]];
	[_pannels setObject:_basicPanel forKey:[_basicPanel panelID]];
	[_pannels setObject:_advancedPanel forKey:[_advancedPanel panelID]];
}


/*
** TCAssistantController - Run
*/
#pragma mark - TCAssistantController - Run

- (void)startWithCallback:(SEL)selector onObject:(id)obj
{
	_respSel = selector;
	_respObj = obj;
		
	[self _switchToPanel:@"ac_welcome"];
	
	[_mainWindow center];
	[_mainWindow makeKeyAndOrderFront:self];
}



/*
** TCAssistantController - IBAction
*/
#pragma mark - TCAssistantController - IBAction

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
		[_respObj performSelector:_respSel withObject:[_currentPanel content]];

		[_mainWindow orderOut:sender];
	}
	else
	{
		// Switch
		[self _switchToPanel:_nextID];
	}
}



/*
** TCAssistantController - Tools
*/
#pragma mark - TCAssistantController - Tools

- (void)_switchToPanel:(NSString *)panel
{
	if ([[_currentPanel panelID] isEqualToString:panel])
		return;
	
	[[_currentPanel panelView] removeFromSuperview];
	
	id <TCAssistantPanel> nPanel = [_pannels objectForKey:panel];
	

	// Set the view
	if (nPanel)
		[_mainView addSubview:[nPanel panelView]];

	// Set the title
	_mainTitle.stringValue = [nPanel panelTitle];
	
	// Set the proxy
	_nextID = nil;
	_isLast = YES;
	[_nextButton setEnabled:NO];
	[_nextButton setTitle:NSLocalizedString(@"ac_next_finish", @"")];
	[nPanel showWithProxy:self];
	 
	// Hold the panel
	_currentPanel = nPanel;
}

- (void)_checkNextButton
{
	if (_fDisable)
	{
		[_nextButton setEnabled:NO];
		return;
	}
			
	if (_isLast)
		[_nextButton setEnabled:YES];
	else
	{
		id obj = [_pannels objectForKey:_nextID];
		
		[_nextButton setEnabled:(obj != nil)];
	}
	

}



/*
** TCAssistantController - Proxy
*/
#pragma mark - TCAssistantController - Proxy

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



/*
** Pannel - Welcome
*/
#pragma mark - Pannel - Welcome

@interface TCPanel_Welcome ()
{
	id <TCAssistantProxy>	proxy;
	BOOL					pathSet;
	TCCocoaConfig			*config;
}

@end

@implementation TCPanel_Welcome

- (void)showWithProxy:(id <TCAssistantProxy>)_proxy
{
	proxy = _proxy;
	
	[proxy setIsLastPanel:NO];
	[proxy setNextPanelID:@"ac_mode"];
}

- (NSString *)panelID
{
	return @"ac_welcome";
}

- (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_welcome", @"");
}

- (NSView *)panelView
{
	return self;
}

- (id)content
{
	return config;
}

- (IBAction)selectChange:(id)sender
{
	NSMatrix	*mtr = sender;
	NSButton	*obj = [mtr selectedCell];
	NSInteger	tag = [obj tag];
	
	if (tag == 1)
	{
		[proxy setIsLastPanel:NO];
		[proxy setNextPanelID:@"ac_mode"];
		
		[proxy setDisableContinue:NO];
	}
	else if (tag == 2)
	{
		[proxy setIsLastPanel:YES];
		[proxy setNextPanelID:nil];
		
		[proxy setDisableContinue:!pathSet];
	}
}

- (IBAction)selectFile:(id)sender
{
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:NO];
	
	if ([openDlg runModal] == NSFileHandlingPanelOKButton)
	{
		NSArray			*urls = [openDlg URLs];
		NSURL			*url = [urls objectAtIndex:0];
		TCCocoaConfig	*aconfig = [[TCCocoaConfig alloc] initWithFile:[url path]];
		
		if (!aconfig)
		{
			// Log error
			[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_read_file", [url path]];
			return;
		}
		
		// Update status
		config = aconfig;
		pathSet = YES;
		
		[_confPathField setStringValue:[url path]];
		
		[proxy setDisableContinue:NO];
	}
}

@end



/*
** Pannel - Mode
*/
#pragma mark - Pannel - Mode

@interface TCPanel_Mode ()
{
    id <TCAssistantProxy> proxy;
}

@end

@implementation TCPanel_Mode

- (void)showWithProxy:(id <TCAssistantProxy>)_proxy
{
	proxy = _proxy;
	
	[proxy setIsLastPanel:NO];
	[proxy setNextPanelID:@"ac_basic"];
}

- (NSString *)panelID
{
	return @"ac_mode";
}

- (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_mode", @"");
}

- (NSView *)panelView
{
	return self;
}

- (id)content
{
	return nil;
}

- (IBAction)selectChange:(id)sender
{
	NSMatrix	*mtr = sender;
	NSButton	*obj = [mtr selectedCell];
	NSInteger	tag = [obj tag];
	
	if (tag == 1)
		[proxy setNextPanelID:@"ac_basic"];
	else if (tag == 2)
		[proxy setNextPanelID:@"ac_advanced"];
	else
		[proxy setNextPanelID:nil];
}

@end



/*
** Pannel - Advanced
*/
#pragma mark - Pannel - Advanced

@implementation TCPanel_Advanced

@synthesize imAddressField;
@synthesize imInPortField;
@synthesize imDownloadField;

@synthesize torAddressField;
@synthesize torPortField;

- (void)showWithProxy:(id <TCAssistantProxy>)proxy
{
	[proxy setIsLastPanel:YES];
}

- (NSString *)panelID
{
	return @"ac_advanced";
}

- (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_advanced", @"");
}

- (NSView *)panelView
{
	return self;
}

- (id)content
{
	NSBundle		*bundle = [NSBundle mainBundle];
	NSString		*path = nil;
	TCCocoaConfig	*aconfig = nil;
	
	// Configuration
	path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
		
	aconfig = [[TCCocoaConfig alloc] initWithFile:path];
	
	if (!aconfig)
	{
		// Log error
		[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_write_file", path];
		return nil;
	}
	
	// Set up the config with the fields
	[aconfig setTorAddress:[torAddressField stringValue]];
	[aconfig setSelfAddress:[imAddressField stringValue]];
	[aconfig setDownloadFolder:[imDownloadField stringValue]];

	[aconfig setTorPort:(uint16_t)[torPortField intValue]];
	[aconfig setClientPort:(uint16_t)[imInPortField intValue]];
	[aconfig setMode:tc_config_advanced];
	
	// Return the config
	return aconfig;
}

- (IBAction)selectFolder:(id)sender
{
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:NO];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setCanCreateDirectories:YES];
	[openDlg setAllowsMultipleSelection:NO];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray		*urls = [openDlg URLs];
		NSURL		*url = [urls objectAtIndex:0];
		
		[imDownloadField setStringValue:[url path]];
	}
}

@end



/*
** Pannel - Basic
*/
#pragma mark - Pannel - Basic

@interface TCPanel_Basic ()
{
	TCCocoaConfig			*cconfig;
	id <TCAssistantProxy>	aproxy;
}

@end

@implementation TCPanel_Basic

@synthesize imAddressField;
@synthesize imDownloadField;
@synthesize loadingIndicator;

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)showWithProxy:(id <TCAssistantProxy>)proxy
{	
	[proxy setIsLastPanel:YES];
	[proxy setDisableContinue:YES]; // Wait for tor
	
	// Retain proxy
	aproxy = proxy;
	
	// If we already a config, stop here
	if (cconfig)
		return;
	
	// Obserse tor status changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(torChanged:) name:TCTorManagerStatusChanged object:nil];

	// Get the default tor config path
	NSString *bpath = [[NSBundle mainBundle] bundlePath];
	NSString *pth = [[bpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	if (!pth)
	{
		[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_build_path"];
		return;
	}
	
	// Try to build a new config file
	cconfig = [[TCCocoaConfig alloc] initWithFile:pth];
	
	if (!cconfig)
	{
		[imAddressField setStringValue:NSLocalizedString(@"ac_err_config", @"")];
		[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_write_file", pth];
		return;
	}
	
	// Start manager
	[[TCTorManager sharedManager] startWithConfiguration:cconfig];
}

- (void)torChanged:(NSNotification *)notice
{
	NSDictionary	*info = notice.userInfo;
	NSNumber		*running = [info objectForKey:TCTorManagerInfoRunningKey];
	NSString		*host = [info objectForKey:TCTorManagerInfoHostNameKey];
		
	if ([running boolValue])
	{
		[aproxy setDisableContinue:NO];
		[imAddressField setStringValue:host];
	}
	else
	{
		[aproxy setDisableContinue:YES];
		
		// Log the error
		[[TCLogsController sharedController] addGlobalAlertLog:@"tor_err_launch"];
	}
}

- (NSString *)panelID
{
	return @"ac_basic";
}

- (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_basic", @"");
}

- (NSView *)panelView
{
	return self;
}

- (id)content
{
	return cconfig;
}

- (IBAction)selectFolder:(id)sender
{
	if (!cconfig)
		return;
	
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:NO];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setCanCreateDirectories:YES];
	[openDlg setAllowsMultipleSelection:NO];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray	*urls = [openDlg URLs];
		NSURL	*url = [urls objectAtIndex:0];
		
		[imDownloadField setStringValue:[url path]];
		[cconfig setDownloadFolder:[url path]];
	}
}

@end
