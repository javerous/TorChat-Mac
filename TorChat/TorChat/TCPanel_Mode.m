/*
 *  TCPanel_Mode.m
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

#import "TCPanel_Mode.h"

#import "TCDebugLog.h"
#import "TCConfigEncryptable.h"


/*
** TCPanel_Mode - Private
*/
#pragma mark - TCPanel_Mode - Private

@interface TCPanel_Mode ()
{
	IBOutlet NSMatrix *modeMatrix;

	id <TCConfigEncryptable> _currentConfig;
}

@property (strong, nonatomic) IBOutlet NSMatrix *buttonMatrix;

- (IBAction)selectChange:(id)sender;

@end



/*
** TCPanel_Mode
*/
#pragma mark - TCPanel_Mode

@implementation TCPanel_Mode

@synthesize proxy;
@synthesize previousContent;

- (void)awakeFromNib
{
	[_buttonMatrix setAutorecalculatesCellSize:YES];
}

- (void)dealloc
{
    TCDebugLog(@"TCPanel_Mode dealloc");
}



/*
** TCPanel_Mode - SMAssistantPanel
*/
#pragma mark - TCPanel_Mode - SMAssistantPanel

+ (id <SMAssistantPanel>)panel
{
	return [[TCPanel_Mode alloc] initWithNibName:@"AssistantPanel_Mode" bundle:nil];
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
	if ([modeMatrix selectedTag] == 1)
		[_currentConfig setMode:TCConfigModeBasic];
	else
		[_currentConfig setMode:TCConfigModeAdvanced];
	
	return _currentConfig;
}

- (void)didAppear
{
	_currentConfig = self.previousContent;
	
	[self.proxy setIsLastPanel:NO];
	[self.proxy setNextPanelID:@"ac_basic"];
}



/*
** TCPanel_Mode - IBAction
*/
#pragma mark - TCPanel_Mode - IBAction

- (IBAction)selectChange:(id)sender
{
	NSInteger tag = [modeMatrix selectedTag];
	
	if (tag == 1)
		[self.proxy setNextPanelID:@"ac_basic"];
	else if (tag == 2)
		[self.proxy setNextPanelID:@"ac_advanced"];
	else
		[self.proxy setNextPanelID:nil];
}

@end
