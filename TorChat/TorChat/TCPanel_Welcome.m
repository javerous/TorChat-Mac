/*
 *  TCPanel_Welcome.m
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

#import "TCPanel_Welcome.h"

#import "TCConfigPlist.h"
#import "TCLogsManager.h"

#import "TCDebugLog.h"


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
    TCDebugLog(@"TCPanel_Welcome dealloc");
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
	NSCell		*obj = [mtr selectedCell];
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
	
	// Ask for a file.
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
			NSString *key = NSLocalizedString(@"ac_error_read_file", @"");

			[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"ac_error_read_file", [url path]];
			[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:key, [url path]] runModal];

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
