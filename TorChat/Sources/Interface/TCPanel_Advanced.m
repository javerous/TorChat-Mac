//
//  TCPanel_Advanced.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 31/07/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCPanel_Advanced.h"

#import "TCLogsManager.h"
#import "TCConfigPlist.h"


/*
** TCPanel_Advanced - Private
*/
#pragma mark - TCPanel_Advanced - Private

@interface TCPanel_Advanced ()
{
	__weak id <TCAssistantProxy> _proxy;
}

@property (strong, nonatomic)	IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*imInPortField;
@property (strong, nonatomic)	IBOutlet NSPathControl	*imDownloadPath;


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
    TCDebugLog("TCPanel_Advanced dealloc");
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
	NSBundle		*bundle = [NSBundle mainBundle];
	NSString		*path = nil;
	TCConfigPlist	*aconfig = nil;
	
	// Configuration
	path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	aconfig = [[TCConfigPlist alloc] initWithFile:path];
	
	if (!aconfig)
	{
		// Log error
		[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_write_file", path];
		[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_err_write_file", @""), path] runModal];
		return nil;
	}
	
	// Set up the config with the fields
	[aconfig setTorAddress:[_torAddressField stringValue]];
	[aconfig setSelfAddress:[_imAddressField stringValue]];
	[aconfig setDownloadFolder:[[_imDownloadPath URL] path]];
	
	[aconfig setTorPort:(uint16_t)[_torPortField intValue]];
	[aconfig setClientPort:(uint16_t)[_imInPortField intValue]];
	[aconfig setMode:tc_config_advanced];
	
	// Return the config
	return aconfig;
}

- (void)showPanel
{
	// Configure assistant.
	id <TCAssistantProxy> proxy = _proxy;
	
	[proxy setIsLastPanel:YES];
	
	// Download path.
	NSString *path = [[[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:NSLocalizedString(@"conf_download", @"")];
	
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
		[[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	
	[_imDownloadPath setURL:[NSURL fileURLWithPath:path]];
}

@end
