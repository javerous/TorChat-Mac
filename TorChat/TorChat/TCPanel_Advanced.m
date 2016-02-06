/*
 *  TCPanel_Advanced.m
 *
<<<<<<< HEAD
 *  Copyright 2014 Avérous Julien-Pierre
=======
 *  Copyright 2016 Avérous Julien-Pierre
>>>>>>> javerous/master
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

<<<<<<< HEAD


=======
>>>>>>> javerous/master
#import "TCPanel_Advanced.h"

#import "TCLogsManager.h"
#import "TCConfigPlist.h"

<<<<<<< HEAD
#import "TCDebugLog.h"


=======
#import "TCLocationViewController.h"

#import "TCDebugLog.h"


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]


>>>>>>> javerous/master

/*
** TCPanel_Advanced - Private
*/
#pragma mark - TCPanel_Advanced - Private

@interface TCPanel_Advanced ()
{
	__weak id <TCAssistantProxy> _proxy;
<<<<<<< HEAD
=======
	
	TCConfigPlist *_config;

	TCLocationViewController *_torDownloadsLocation;
>>>>>>> javerous/master
}

@property (strong, nonatomic)	IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*imInPortField;
<<<<<<< HEAD
@property (strong, nonatomic)	IBOutlet NSPathControl	*imDownloadPath;

=======
@property (strong, nonatomic)	IBOutlet NSView			*downloadLocationView;
>>>>>>> javerous/master

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
<<<<<<< HEAD
    TCDebugLog("TCPanel_Advanced dealloc");
=======
    TCDebugLog(@"TCPanel_Advanced dealloc");
>>>>>>> javerous/master
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
<<<<<<< HEAD
	NSBundle		*bundle = [NSBundle mainBundle];
	NSString		*path = nil;
	TCConfigPlist	*aconfig = nil;
	
	// Configuration
	path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	aconfig = [[TCConfigPlist alloc] initWithFile:path];
	
	if (!aconfig)
	{
		// Log error
		NSString *key = NSLocalizedString(@"ac_error_write_file", @"");
		
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_error_write_file", path];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:key, path] runModal];
		return nil;
	}
	
	// Set up the config with the fields
	[aconfig setTorAddress:[_torAddressField stringValue]];
	[aconfig setSelfAddress:[_imAddressField stringValue]];
	[aconfig setDomain:TConfigPathDomainDownloads place:TConfigPathPlaceAbsolute subpath:[[_imDownloadPath URL] path]];
	
	[aconfig setTorPort:(uint16_t)[_torPortField intValue]];
	[aconfig setClientPort:(uint16_t)[_imInPortField intValue]];
	[aconfig setMode:TCConfigModeAdvanced];
	
	// Return the config
	return @{ @"configuration" : aconfig };
=======
	// Set up the config with the fields.
	[_config setTorAddress:[_torAddressField stringValue]];
	[_config setSelfAddress:[_imAddressField stringValue]];
	
	[_config setTorPort:(uint16_t)[_torPortField intValue]];
	[_config setClientPort:(uint16_t)[_imInPortField intValue]];
	
	// Return the config.
	return _config;
>>>>>>> javerous/master
}

- (void)showPanel
{
	// Configure assistant.
	id <TCAssistantProxy> proxy = _proxy;
	
	[proxy setIsLastPanel:YES];
	
<<<<<<< HEAD
	// Download path.
	NSString *path = [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Downloads"];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
		[[NSData data] writeToFile:[path stringByAppendingPathComponent:@".localized"] atomically:NO];
	}
	
	[_imDownloadPath setURL:[NSURL fileURLWithPath:path]];
=======
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
>>>>>>> javerous/master
}

@end
