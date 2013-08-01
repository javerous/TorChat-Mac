//
//  TCPanel_Advanced.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 31/07/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCPanel_Advanced.h"

#import "TCLogsManager.h"
#import "TCCocoaConfig.h"


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
@property (strong, nonatomic)	IBOutlet NSTextField	*imDownloadField;

@property (strong, nonatomic)	IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*torPortField;

- (IBAction)selectFolder:(id)sender;

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
	TCCocoaConfig	*aconfig = nil;
	
	// Configuration
	path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	aconfig = [[TCCocoaConfig alloc] initWithFile:path];
	
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
	[aconfig setDownloadFolder:[_imDownloadField stringValue]];
	
	[aconfig setTorPort:(uint16_t)[_torPortField intValue]];
	[aconfig setClientPort:(uint16_t)[_imInPortField intValue]];
	[aconfig setMode:tc_config_advanced];
	
	// Return the config
	return aconfig;
}

- (void)showPanel
{
	id <TCAssistantProxy> proxy = _proxy;
	
	[proxy setIsLastPanel:YES];
}



/*
** TCPanel_Advanced - IBAction
*/
#pragma mark - TCPanel_Advanced - IBAction

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
		
		[_imDownloadField setStringValue:[url path]];
	}
}

@end
