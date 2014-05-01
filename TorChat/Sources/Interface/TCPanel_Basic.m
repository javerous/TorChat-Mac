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



/*
** TCPanel_Basic - Private
*/
#pragma mark - TCPanel_Basic - Private

@interface TCPanel_Basic ()
{
	TCConfigPlist					*_config;
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
	return _config;
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
	
	// Obserse tor status changes.
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(torChanged:) name:TCTorManagerStatusChanged object:nil];
	
	// Get the default tor config path.
	NSString *bpath = [[NSBundle mainBundle] bundlePath];
	NSString *pth = [[bpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	if (!pth)
	{
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_build_path"];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_err_build_path", @"")] runModal];
		return;
	}

	// Try to build a new config file.
	_config = [[TCConfigPlist alloc] initWithFile:pth];
	
	if (!_config)
	{
		[_imAddressField setStringValue:NSLocalizedString(@"ac_err_config", @"")];
		
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_write_file", pth];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:TCLocalizedString(@"ac_err_write_file", @""), pth] runModal];

		return;
	}
	
	// Set download path.
	NSString *path = [_config realPath:[_config downloadFolder]];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	
	[_imDownloadPath setURL:[NSURL fileURLWithPath:path]];
	
	// Start manager.
	[[TCTorManager sharedManager] startWithConfiguration:_config];
}



/*
** TCPanel_Basic - NSNotification
*/
#pragma mark - TCPanel_Basic - NSNotification

- (void)torChanged:(NSNotification *)notice
{
	id <TCAssistantProxy> proxy = _proxy;
	
	NSDictionary	*info = notice.userInfo;
	NSNumber		*running = [info objectForKey:TCTorManagerInfoRunningKey];
	NSString		*host = [info objectForKey:TCTorManagerInfoHostNameKey];
	
	if ([running boolValue])
	{
		[proxy setDisableContinue:NO];
		[_imAddressField setStringValue:host];
	}
	else
	{
		[proxy setDisableContinue:YES];
		
		// Log the error
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"tor_err_launch"];
	}
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
		[_config setDownloadFolder:path];
	else
		NSBeep();
}

@end
