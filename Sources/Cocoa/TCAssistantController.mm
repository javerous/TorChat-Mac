/*
 *  TCAssistantController.mm
 *
 *  Copyright 2011 Avérous Julien-Pierre
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
#pragma mark -
#pragma mark TCAssistantController - Private

@interface TCAssistantController () <TCAssistantProxy>

- (void)_switchToPanel:(NSString *)panel;
- (void)_checkNextButton;

@end



/*
** TCAssistantController
*/
#pragma mark -
#pragma mark TCAssistantController

@implementation TCAssistantController



/*
** TCAssistantController - Instance
*/
#pragma mark -
#pragma mark TCAssistantController - Instance

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
	if ((self = [super init]))
	{
		// Load Bundle
		[NSBundle loadNibNamed:@"Assistant" owner:self];
	}
	
	return self;
}

- (void)awakeFromNib
{
	// Catalog pannels
	pannels = [[NSMutableDictionary alloc] init];
	
	[pannels setObject:welcomePanel forKey:[welcomePanel panelID]];
	[pannels setObject:modePanel forKey:[modePanel panelID]];
	[pannels setObject:basicPanel forKey:[basicPanel panelID]];
	[pannels setObject:advancedPanel forKey:[advancedPanel panelID]];
}

- (void)dealloc
{
    [pannels release];
	[respObj release];
	[currentPanel release];
	[nextID release];
    
    [super dealloc];
}



/*
** TCAssistantController - Run
*/
#pragma mark -
#pragma mark TCAssistantController - Run

- (void)startWithCallback:(SEL)selector onObject:(id)obj
{
	respSel = selector;
	
	[obj retain];
	[respObj release];
	respObj = obj;
		
	[self _switchToPanel:@"ac_welcome"];
	
	[mainWindow center];
	[mainWindow makeKeyAndOrderFront:self];
}



/*
** TCAssistantController - IBAction
*/
#pragma mark -
#pragma mark TCAssistantController - IBAction

- (IBAction)doCancel:(id)sender
{
	[NSApp terminate:sender];
}

- (IBAction)doNext:(id)sender
{
	if (!currentPanel)
	{
		NSBeep();
		return;
	}
	
	if (isLast)
	{
		[respObj performSelector:respSel withObject:[NSValue valueWithPointer:[currentPanel content]]];

		[mainWindow orderOut:sender];
	}
	else
	{
		// Switch
		[self _switchToPanel:nextID];
	}
}



/*
** TCAssistantController - Tools
*/
#pragma mark -
#pragma mark TCAssistantController - Tools

- (void)_switchToPanel:(NSString *)panel
{
	if ([[currentPanel panelID] isEqualToString:panel])
		return;
	
	[[currentPanel panelView] removeFromSuperview];
	
	id <TCAssistantPanel> nPanel = [pannels objectForKey:panel];
	

	// Set the view
	if (nPanel)
		[mainView addSubview:[nPanel panelView]];

	// Set the title
	mainTitle.stringValue = [nPanel panelTitle];
	
	// Set the proxy
	nextID = nil;
	isLast = YES;
	[nextButton setEnabled:NO];
	[nextButton setTitle:NSLocalizedString(@"ac_next_finish", @"")];
	[nPanel showWithProxy:self];
	 
	// Hold the panel
	[nPanel retain];
	[currentPanel release];
	currentPanel = nPanel;
}

- (void)_checkNextButton
{
	if (fDisable)
	{
		[nextButton setEnabled:NO];
		return;
	}
			
	if (isLast)
		[nextButton setEnabled:YES];
	else
	{
		id obj = [pannels objectForKey:nextID];
		
		[nextButton setEnabled:(obj != nil)];
	}
	

}



/*
** TCAssistantController - Proxy
*/
#pragma mark -
#pragma mark TCAssistantController - Proxy

- (void)setNextPanelID:(NSString *)panelID
{
	[panelID retain];
	[nextID release];
	
	nextID = panelID;
	
	[self _checkNextButton];
}

- (void)setIsLastPanel:(BOOL)last
{
	isLast = last;
	
	if (isLast)
		[nextButton setTitle:NSLocalizedString(@"ac_next_finish", @"")];
	else
		[nextButton setTitle:NSLocalizedString(@"ac_next_continue", @"")];
	
	[self _checkNextButton];
}

- (void)setDisableContinue:(BOOL)disabled
{
	fDisable = disabled;
	
	[self _checkNextButton];
}

@end



/*
** Pannel - Welcome
*/
#pragma mark -
#pragma mark Pannel - Welcome

@implementation TCPanel_Welcome

- (void)dealloc
{
    [proxy release];
	
    [super dealloc];
}

- (void)showWithProxy:(id <TCAssistantProxy>)_proxy
{
	[_proxy retain];
	[proxy release];
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

- (void *)content
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
		TCCocoaConfig	*aconfig = NULL;
		
		// Try to build a config with the file
		try
		{
			aconfig = new TCCocoaConfig([url path]);
		}
		catch (const char *err)
		{
			NSString *oerr = [NSString stringWithUTF8String:err];
			
			// Log error
			[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_read_file", NSLocalizedString(oerr, @"")];
			
			if (aconfig)
				delete aconfig;
			
			return;
		}
		
		// Remove current config
		if (config)
			delete config;
		
		// Update status
		config = aconfig;
		pathSet = YES;
		
		[confPathField setStringValue:[url path]];
		
		[proxy setDisableContinue:NO];
	}
}

@end



/*
** Pannel - Mode
*/
#pragma mark -
#pragma mark Pannel - Mode

@implementation TCPanel_Mode

- (void)showWithProxy:(id <TCAssistantProxy>)_proxy
{
	[_proxy retain];
	[proxy release];
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

- (void *)content
{
	return NULL;
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
#pragma mark -
#pragma mark Pannel - Advanced

@implementation TCPanel_Advanced

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

- (void *)content
{
	NSBundle		*bundle = [NSBundle mainBundle];
	NSString		*path = nil;
	TCCocoaConfig	*aconfig = NULL;
	
	// Configuration
	path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
		
	// Try to build a config with the file
	try
	{
		aconfig = new TCCocoaConfig(path);
	}
	catch (const char *err)
	{
		// Log error
		NSString *oerr = [NSString stringWithUTF8String:err];
		
		[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_write_file", NSLocalizedString(oerr, "")];
		
		if (aconfig)
			delete aconfig;
		
		return NULL;
	}
	
	
	// Set up the config with the fields
	const char	*c_tor_address = [[torAddressField stringValue] UTF8String];
	if (c_tor_address)
	{
		std::string	tor_address(c_tor_address);
		
		aconfig->set_tor_address(tor_address);
	}
	
	const char	*c_im_address = [[imAddressField stringValue] UTF8String];
	if (c_im_address)
	{
		std::string	im_address(c_im_address);
		
		aconfig->set_self_address(im_address);
	}
	
	const char	*c_down_folder = [[imDownloadField stringValue] UTF8String];
	if (c_down_folder)
	{
		std::string	down_folder(c_down_folder);

		aconfig->set_download_folder(down_folder);
	}

	aconfig->set_tor_port((uint16_t)[torPortField intValue]);
	aconfig->set_client_port((uint16_t)[imInPortField intValue]);
	aconfig->set_mode(tc_config_advanced);
	
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
#pragma mark -
#pragma mark Pannel - Basic

@implementation TCPanel_Basic

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
	[aproxy release];
	
    [super dealloc];
}

- (void)showWithProxy:(id <TCAssistantProxy>)proxy
{	
	[proxy setIsLastPanel:YES];
	[proxy setDisableContinue:YES]; // Wait for tor
	
	// Retain proxy
	[proxy retain];
	[aproxy release];
	
	aproxy = proxy;
	
	// If we already a config, stop here
	if (cconfig)
		return;
	
	// Obserse tor status changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(torChanged:) name:TCTorManagerStatusChanged object:nil];

	// Get the default tor config path
	NSString		*bpath = [[NSBundle mainBundle] bundlePath];
	NSString		*pth = [[bpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	if (!pth)
	{
		[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_build_path"];
		return;
	}
	
	// Try to build a new config file
	try
	{
		cconfig = new TCCocoaConfig(pth);
	}
	catch (const char *err)
	{
		NSString *oerr = [NSString stringWithUTF8String:err];
		
		[imAddressField setStringValue:NSLocalizedString(@"ac_err_config", @"")];
		[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_write_file", NSLocalizedString(oerr, @"")];
		
		if (cconfig)
			delete cconfig;
		cconfig = NULL;
		
		return;
	}
	
	// Start manager
	[[TCTorManager sharedManager] startWithConfig:cconfig];
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

- (void *)content
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
		NSArray		*urls = [openDlg URLs];
		NSURL		*url = [urls objectAtIndex:0];
		
		[imDownloadField setStringValue:[url path]];
		cconfig->set_download_folder([[url path] UTF8String]);
	}
}

@end
