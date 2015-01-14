/*
 *  TCPanel_Mode.m
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



#import "TCPanel_Mode.h"

#import "TCDebugLog.h"



/*
** TCPanel_Mode - Private
*/
#pragma mark - TCPanel_Mode - Private

@interface TCPanel_Mode ()
{
    __weak id <TCAssistantProxy> _proxy;
}

@property (strong, nonatomic) IBOutlet NSMatrix *buttonMatrix;

- (IBAction)selectChange:(id)sender;

@end



/*
** TCPanel_Mode
*/
#pragma mark - TCPanel_Mode

@implementation TCPanel_Mode

- (void)awakeFromNib
{
	[_buttonMatrix setAutorecalculatesCellSize:YES];
}

- (void)dealloc
{
    TCDebugLog("TCPanel_Mode dealloc");
}



/*
** TCPanel_Mode - TCAssistantPanel
*/
#pragma mark - TCPanel_Mode - TCAssistantPanel

+ (id <TCAssistantPanel>)panelWithProxy:(id <TCAssistantProxy>)proxy
{
	TCPanel_Mode *panel = [[TCPanel_Mode alloc] initWithNibName:@"AssistantPanel_Mode" bundle:nil];
	
	panel->_proxy = proxy;
	
	return panel;
}

+ (NSString *)identifiant
{
	return @"ac_mode";
}

+ (NSString *)title
{
	return NSLocalizedString(@"ac_title_mode", @"");
}

- (id)content
{
	return nil;
}

- (void)showPanel;
{
	id <TCAssistantProxy> proxy = _proxy;

	[proxy setIsLastPanel:NO];
	[proxy setNextPanelID:@"ac_basic"];
}


/*
** TCPanel_Mode - IBAction
*/
#pragma mark - TCPanel_Mode - IBAction

- (IBAction)selectChange:(id)sender
{
	id <TCAssistantProxy> proxy = _proxy;

	NSMatrix	*mtr = sender;
	NSButton	*obj = [mtr selectedCell];
	NSInteger	tag = [obj tag];
	
	if (tag == 1)
		[proxy setNextPanelID:@"ac_basic"];
	else if (tag == 2)
		[proxy setNextPanelID:@"ac_advanced"];
	else
		[proxy setNextPanelID:nil];
}

@end
