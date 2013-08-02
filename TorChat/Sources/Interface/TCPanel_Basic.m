//
//  TCPanel_Basic.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 31/07/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCPanel_Basic.h"

#import "TCLogsManager.h"
#import "TCConfigPlist.h"
#import "TCTorManager.h"


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
@property (strong, nonatomic)	IBOutlet NSTextField			*imDownloadField;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator	*loadingIndicator;

- (IBAction)selectFolder:(id)sender;

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

- (void)showPanel
{
	id <TCAssistantProxy> proxy = _proxy;

	[proxy setIsLastPanel:YES];
	[proxy setDisableContinue:YES]; // Wait for tor
	
	// If we already a config, stop here
	if (_config)
		return;
	
	// Obserse tor status changes
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(torChanged:) name:TCTorManagerStatusChanged object:nil];
	
	// Get the default tor config path
	NSString *bpath = [[NSBundle mainBundle] bundlePath];
	NSString *pth = [[bpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	if (!pth)
	{
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_build_path"];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_err_build_path", @"")] runModal];
		return;
	}
	
	// Try to build a new config file
	_config = [[TCConfigPlist alloc] initWithFile:pth];
	
	if (!_config)
	{
		[_imAddressField setStringValue:NSLocalizedString(@"ac_err_config", @"")];
		
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_write_file", pth];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_err_write_file", @""), pth] runModal];

		return;
	}
	
	// Start manager
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

- (IBAction)selectFolder:(id)sender
{
	if (!_config)
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
		
		[_imDownloadField setStringValue:[url path]];
		[_config setDownloadFolder:[url path]];
	}
}

@end
