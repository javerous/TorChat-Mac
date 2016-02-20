/*
 *  TCPanel_Basic.m
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

@import SMFoundation;
@import SMTor;

#import "TCPanel_Basic.h"

#import "TCLogsManager.h"
#import "TCConfigPlist.h"

#import "TCLocationViewController.h"

#import "TCDebugLog.h"
#import "SMTorConfiguration+TCConfig.h"


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** TCPanel_Basic - Private
*/
#pragma mark - TCPanel_Basic - Private

@interface TCPanel_Basic ()
{
	__weak id <SMAssistantProxy> _proxy;

	TCConfigPlist	*_config;
	SMTorManager	*_tor;
	
	TCLocationViewController *_torDownloadsLocation;
}

@property (strong, nonatomic)	IBOutlet NSTextField			*imAddressField;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator	*loadingIndicator;
@property (strong, nonatomic)	IBOutlet NSView					*downloadLocationView;

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
	
	TCDebugLog(@"TCPanel_Basic dealloc");
}



/*
** TCPanel_Basic - SMAssistantPanel
*/
#pragma mark - TCPanel_Basic - SMAssistantPanel

+ (id <SMAssistantPanel>)panelWithProxy:(id <SMAssistantProxy>)proxy
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
	return _config;
}

- (void)showPanel
{
	id <SMAssistantProxy> proxy = _proxy;

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
	
	[_config setMode:TCConfigModeBasic];
	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_config component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
	
	// Set default configuration.
	_config.torAddress = @"localhost";
	_config.torPort = 60600;
	_config.clientPort = 60601;
	
	// Create tor configuration.
	SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:_config];
	
	// Create tor manager & start it.
	__weak NSTextField *weakIMAddressField = _imAddressField;
	
	_tor = [[SMTorManager alloc] initWithConfiguration:torConfig];
	
	[_loadingIndicator startAnimation:self];

	[_tor startWithHandler:^(SMInfo *info) {
		
		NSTextField *imAddressField = weakIMAddressField;
		
		dispatch_async(dispatch_get_main_queue(), ^{

			if (info.kind == SMInfoError)
			{
				[_loadingIndicator stopAnimation:self];
				[proxy setDisableContinue:YES];
			}
			else if (info.kind == SMInfoInfo)
			{
				if (info.code == SMTorManagerEventStartHostname)
				{
					[imAddressField setStringValue:info.context];
					[_config setSelfAddress:info.context];
					[_tor stopWithCompletionHandler:nil];
				}
				else if (info.code == SMTorManagerEventStartDone)
				{
					[_tor stopWithCompletionHandler:^{
						dispatch_async(dispatch_get_main_queue(), ^{
							[_loadingIndicator stopAnimation:self];
							[proxy setDisableContinue:NO];
						});
					}];
				}
			}
			else if (info.kind == SMInfoWarning)
			{
				if (info.code == SMTorManagerWarningStartCanceled)
				{
					[_loadingIndicator stopAnimation:self];

					if (imAddressField.stringValue.length > 0)
						[proxy setDisableContinue:NO];
				}
			}
		});
	}];
}

@end
