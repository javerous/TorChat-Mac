/*
 *  TCPanel_Advanced.m
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

#import "TCPanel_Advanced.h"

#import "TCLogsManager.h"
#import "TCConfigPlist.h"

#import "TCLocationViewController.h"

#import "TCDebugLog.h"


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** TCPanel_Advanced - Private
*/
#pragma mark - TCPanel_Advanced - Private

@interface TCPanel_Advanced ()
{
	__weak id <TCAssistantProxy> _proxy;
	
	TCConfigPlist *_config;

	TCLocationViewController *_torDownloadsLocation;
}

@property (strong, nonatomic)	IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*imInPortField;
@property (strong, nonatomic)	IBOutlet NSView			*downloadLocationView;

@property (strong, nonatomic)	IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*torPortField;

@end



/*
** TCPanel_Advanced
*/
#pragma mark - TCPanel_Advanced

@implementation TCPanel_Advanced

- (void)dealloc
{
    TCDebugLog(@"TCPanel_Advanced dealloc");
}

/*
** TCPanel_Advanced - TCAssistantPanel
*/
#pragma mark - TCPanel_Advanced - TCAssistantPanel

+ (id <TCAssistantPanel>)panelWithProxy:(id <TCAssistantProxy>)proxy
{
	TCPanel_Advanced *panel = [[TCPanel_Advanced alloc] initWithNibName:@"AssistantPanel_Advanced" bundle:nil];
	
	panel->_proxy = proxy;
	
	return panel;
}

+ (NSString *)identifiant
{
	return @"ac_advanced";
}

+ (NSString *)title
{
	return NSLocalizedString(@"ac_title_advanced", @"");
}

- (id)content
{
	// Set up the config with the fields.
	[_config setTorAddress:[_torAddressField stringValue]];
	[_config setSelfAddress:[_imAddressField stringValue]];
	
	[_config setTorPort:(uint16_t)[_torPortField intValue]];
	[_config setClientPort:(uint16_t)[_imInPortField intValue]];
	
	// Return the config.
	return _config;
}

- (void)showPanel
{
	// Configure assistant.
	id <TCAssistantProxy> proxy = _proxy;
	
	[proxy setIsLastPanel:YES];
	
	// If we already have a config, stop here
	if (_config)
		return;
	
	// Get the default tor config path.
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	NSString *configPath = [[bundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	if (!configPath)
	{
		[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"ac_error_build_path"];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_error_build_path", @"")] runModal];
		return;
	}
	
	// Try to build a new config file.
	_config = [[TCConfigPlist alloc] initWithFile:configPath];
	
	if (!_config)
	{
		[_imAddressField setStringValue:NSLocalizedString(@"ac_error_config", @"")];
		
		[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"ac_error_write_file", configPath];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:TCLocalizedString(@"ac_error_write_file", @""), configPath] runModal];
		
		return;
	}
	
	[_config setMode:TCConfigModeAdvanced];

	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_config component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
}

@end
