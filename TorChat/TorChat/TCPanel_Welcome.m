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

#import "TCLogsManager.h"

#import "TCDebugLog.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPanel_Welcome - Private
*/
#pragma mark - TCPanel_Welcome - Private

@interface TCPanel_Welcome ()
{	
	NSString *_configPath;
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

@synthesize panelProxy;
@synthesize panelPreviousContent;

- (void)awakeFromNib
{
	[_buttonMatrix setAutorecalculatesCellSize:YES];
}

- (void)dealloc
{
    TCDebugLog(@"TCPanel_Welcome dealloc");
}



/*
** TCPanel_Welcome - SMAssistantPanel
*/
#pragma mark - TCPanel_Welcome - SMAssistantPanel

+ (id <SMAssistantPanel>)panelInstance
{
	return (id <SMAssistantPanel>)[[TCPanel_Welcome alloc] initWithNibName:@"AssistantPanel_Welcome" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_welcome";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_welcome", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (nullable id)panelContent
{
	return _configPath;
}

- (void)panelDidAppear
{
	[self.panelProxy setNextPanelID:@"ac_security"];
}



/*
** TCPanel_Welcome - IBAction
*/
#pragma mark - TCPanel_Welcome - IBAction

- (IBAction)selectChange:(id)sender
{
	NSMatrix	*mtr = sender;
	NSCell		*obj = mtr.selectedCell;
	NSInteger	tag = obj.tag;
	
	if (tag == 1)
	{
		[self.panelProxy setNextPanelID:@"ac_mode"];
		[self.panelProxy setDisableContinue:NO];
	}
	else if (tag == 2)
	{
		[self.panelProxy setNextPanelID:nil];
		[self.panelProxy setDisableContinue:!_configPath];
	}
}

- (IBAction)selectFile:(id)sender
{
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file.
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:NO];
	
	if ([openDlg runModal] == NSFileHandlingPanelOKButton)
	{
		NSArray			*urls = openDlg.URLs;
		NSURL			*url = urls[0];
		
		_configPath = url.path;
		_confPathField.stringValue = _configPath;
		
		[self.panelProxy setDisableContinue:NO];
	}
}

@end


NS_ASSUME_NONNULL_END
