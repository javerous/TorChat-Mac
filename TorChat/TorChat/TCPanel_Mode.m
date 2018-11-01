/*
 *  TCPanel_Mode.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCConfigApp.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPanel_Mode - Private
*/
#pragma mark - TCPanel_Mode - Private

@interface TCPanel_Mode ()
{
	IBOutlet NSMatrix *modeMatrix;

	id <TCConfigApp> _currentConfig;
}

@property (strong, nonatomic) IBOutlet NSMatrix *buttonMatrix;

- (IBAction)selectChange:(id)sender;

@end



/*
** TCPanel_Mode
*/
#pragma mark - TCPanel_Mode

@implementation TCPanel_Mode

@synthesize panelProxy;
@synthesize panelPreviousContent;

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

+ (id <SMAssistantPanel>)panelInstance
{
	return (id <SMAssistantPanel>)[[TCPanel_Mode alloc] initWithNibName:@"AssistantPanel_Mode" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_mode";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_mode", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (nullable id)panelContent
{
	if ([modeMatrix selectedTag] == 1)
		_currentConfig.mode = TCConfigModeBundled;
	else
		_currentConfig.mode = TCConfigModeCustom;
	
	return _currentConfig;
}

- (void)panelDidAppear
{
	// Configure assitant.
	[self.panelProxy setNextPanelID:@"ac_bundled"];
	
	// Handle config.
	_currentConfig = self.panelPreviousContent;
		
	if (!_currentConfig)
		[self.panelProxy setDisableContinue:YES];
}

- (void)canceled
{
	NSString *referralPath = [_currentConfig pathForComponent:TCConfigPathComponentReferral fullPath:YES];
	
	[_currentConfig close];

	if (referralPath)
	{
		NSString *confPath = [referralPath stringByAppendingPathComponent:@"torchat.conf"];
		
		[[NSFileManager defaultManager] removeItemAtPath:confPath error:nil];
	}
}



/*
** TCPanel_Mode - IBAction
*/
#pragma mark - TCPanel_Mode - IBAction

- (IBAction)selectChange:(id)sender
{
	NSInteger tag = [modeMatrix selectedTag];
	
	if (tag == 1)
		[self.panelProxy setNextPanelID:@"ac_bundled"];
	else if (tag == 2)
		[self.panelProxy setNextPanelID:@"ac_custom"];
	else
		[self.panelProxy setNextPanelID:nil];
}

@end


NS_ASSUME_NONNULL_END
