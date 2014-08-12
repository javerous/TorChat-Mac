/*
 *  TCPanel_Basic.m
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



#import "TCPanel_Basic.h"

#import "TCLogsManager.h"
#import "TCConfigPlist.h"
#import "TCTorManager.h"

#import "TCDebugLog.h"

#import "TCInfo.h"
#import "TCInfo+Render.h"



/*
** TCPanel_Basic - Private
*/
#pragma mark - TCPanel_Basic - Private

@interface TCPanel_Basic ()
{
	TCConfigPlist					*_config;
	TCTorManager					*_tor;
	__weak id <TCAssistantProxy>	_proxy;
}

@property (strong, nonatomic)	IBOutlet NSTextField			*imAddressField;
@property (strong, nonatomic)	IBOutlet NSPathControl			*imDownloadPath;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator	*loadingIndicator;

- (IBAction)pathChanged:(id)sender;

@end



/*
** TCPanel_Basic
*/
#pragma mark - TCPanel_Basic

@implementation TCPanel_Basic


/*
** TCPanel_Basic - Instance
*/
#pragma mark - TCPanel_Basic - Instance

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	TCDebugLog("TCPanel_Basic dealloc");
}



/*
** TCPanel_Basic - TCAssistantPanel
*/
#pragma mark - TCPanel_Basic - TCAssistantPanel

+ (id <TCAssistantPanel>)panelWithProxy:(id <TCAssistantProxy>)proxy
{
	TCPanel_Basic *panel = [[TCPanel_Basic alloc] initWithNibName:@"AssistantPanel_Basic" bundle:nil];
	
	panel->_proxy = proxy;
	
	return panel;
}

+ (NSString *)identifiant
{
	return @"ac_basic";
}

+ (NSString *)title
{
	return NSLocalizedString(@"ac_title_basic", @"");
}

- (id)content
{
	NSMutableDictionary *content = [[NSMutableDictionary alloc] init];
	
	if (_config)
		content[@"configuration"] = _config;
	
	if (_tor)
		content[@"tor_manager"] = _tor;
	
	return content;
}

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]

- (void)showPanel
{
	id <TCAssistantProxy> proxy = _proxy;

	[proxy setIsLastPanel:YES];
	[proxy setDisableContinue:YES]; // Wait for tor
	
	// If we already a config, stop here
	if (_config)
		return;
	
	// Get the default tor config path.
	NSString *bundlePath = [[NSBundle mainBundle] bundlePath];
	NSString *configPath = [[bundlePath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	if (!configPath)
	{
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_error_build_path"];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_error_build_path", @"")] runModal];
		return;
	}

	// Try to build a new config file.
	_config = [[TCConfigPlist alloc] initWithFile:configPath];
	
	if (!_config)
	{
		[_imAddressField setStringValue:NSLocalizedString(@"ac_error_config", @"")];
		
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_error_write_file", configPath];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:TCLocalizedString(@"ac_error_write_file", @""), configPath] runModal];

		return;
	}
	
	// Set download path.
	NSString *path = [_config pathForDomain:TConfigPathDomainDownloads];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
	{
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
		
		if ([[path lastPathComponent] isEqualToString:@"Downloads"])
			[[NSData data] writeToFile:[path stringByAppendingPathComponent:@".localized"]];
	}
	
	[_imDownloadPath setURL:[NSURL fileURLWithPath:path]];
	
	// Set default configuration.
	[_config setTorAddress:@"localhost"];
	[_config setTorPort:60600];
	[_config setClientPort:60601];
	[_config setMode:TCConfigModeBasic];
	
	// Create tor manager & start it.
	__weak NSTextField *weakIMAddressField = _imAddressField;
	
	// > Create.
	_tor = [[TCTorManager alloc] initWithConfiguration:_config];

	_tor.logHandler = ^(TCTorManagerLogKind kind, NSString *log) {
		switch (kind)
		{
			case TCTorManagerLogStandard:
				[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_out_log", log];
				break;
				
			case TCTorManagerLogError:
				[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_error_log", log];
				break;
		}
	};
	
	// > Start.
	[_tor startWithHandler:^(TCInfo *info) {
		
		NSTextField *imAddressField = weakIMAddressField;

		[[TCLogsManager sharedManager] addGlobalLogEntry:[info render]];
		
		dispatch_async(dispatch_get_main_queue(), ^{

			if (info.kind == TCInfoError)
			{
				[proxy setDisableContinue:YES];
			}
			else if (info.kind == TCInfoInfo)
			{
				if ([info.domain isEqualToString:TCTorManagerInfoStartDomain])
				{
					if (info.code == TCTorManagerEventStartHostname)
						[imAddressField setStringValue:info.context];
					else if (info.code == TCTorManagerEventStartDone)
						[proxy setDisableContinue:NO];
				}
			}
		});
	}];
}



/*
** TCPanel_Basic - IBAction
*/
#pragma mark - TCPanel_Basic - IBAction

- (IBAction)pathChanged:(id)sender
{
	if (!_config)
		return;
	
	NSString *path = [[_imDownloadPath URL] path];
	
	if (path)
	{
		[_config setDomain:TConfigPathDomainDownloads place:TConfigPathPlaceAbsolute subpath:path];
		
		if ([[path lastPathComponent] isEqualToString:@"Downloads"])
			[[NSData data] writeToFile:[path stringByAppendingPathComponent:@".localized"]];
	}
	else
		NSBeep();
}

@end
