//
//  TCPanel_Welcome.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 31/07/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCPanel_Welcome.h"

#import "TCConfigPlist.h"
#import "TCLogsManager.h"



/*
** TCPanel_Welcome - Private
*/
#pragma mark - TCPanel_Welcome - Private

@interface TCPanel_Welcome ()
{
	__weak id <TCAssistantProxy>	_proxy;
	BOOL							_pathSet;
	TCConfigPlist					*_config;
}

@property (strong, nonatomic) IBOutlet NSMatrix		*buttonMatrix;
@property (strong, nonatomic) IBOutlet NSTextField	*confPathField;

- (IBAction)selectChange:(id)sender;
- (IBAction)selectFile:(id)sender;

@end



/*
** TCPanel_Welcome
*/
#pragma mark - TCPanel_Welcome

@implementation TCPanel_Welcome

- (void)awakeFromNib
{
	[_buttonMatrix setAutorecalculatesCellSize:YES];
}

- (void)dealloc
{
    TCDebugLog("TCPanel_Welcome dealloc");
}



/*
** TCPanel_Welcome - TCAssistantPanel
*/
#pragma mark - TCPanel_Welcome - TCAssistantPanel

+ (id <TCAssistantPanel>)panelWithProxy:(id <TCAssistantProxy>)proxy
{
	TCPanel_Welcome *panel = [[TCPanel_Welcome alloc] initWithNibName:@"AssistantPanel_Welcome" bundle:nil];
	
	panel->_proxy = proxy;
	
	return panel;
}

+ (NSString *)identifiant
{
	return @"ac_welcome";
}

+ (NSString *)title
{
	return NSLocalizedString(@"ac_title_welcome", @"");
}

- (id)content
{
	return _config;
}

- (void)showPanel
{
	id <TCAssistantProxy> proxy = _proxy;
	
	[proxy setIsLastPanel:NO];
	[proxy setNextPanelID:@"ac_mode"];
}



/*
** TCPanel_Welcome - IBAction
*/
#pragma mark - TCPanel_Welcome - IBAction

- (IBAction)selectChange:(id)sender
{
	id <TCAssistantProxy> proxy = _proxy;
	
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
		
		[proxy setDisableContinue:!_pathSet];
	}
}

- (IBAction)selectFile:(id)sender
{
	id <TCAssistantProxy> proxy = _proxy;

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
		TCConfigPlist	*aconfig = [[TCConfigPlist alloc] initWithFile:[url path]];
		
		if (!aconfig)
		{
			// Log error
			[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_read_file", [url path]];
			[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_err_read_file", @""), [url path]] runModal];

			return;
		}
		
		// Update status
		_config = aconfig;
		_pathSet = YES;
		
		[_confPathField setStringValue:[url path]];
		
		[proxy setDisableContinue:NO];
	}
}

@end
