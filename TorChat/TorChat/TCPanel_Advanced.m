/*
 *  TCPanel_Advanced.m
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

#import "TCPanel_Advanced.h"

#import "TCLogsManager.h"
#import "TCConfigAppEncryptable.h"

#import "TCLocationViewController.h"

#import "TCDebugLog.h"


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** TCPanel_Advanced - Private
*/
#pragma mark - TCPanel_Advanced - Private

@interface TCPanel_Advanced ()
{
	id <TCConfigAppEncryptable> _currentConfig;

	TCLocationViewController *_torDownloadsLocation;
}

@property (strong, nonatomic)	IBOutlet NSTextField	*imIdentifierField;
@property (strong, nonatomic)	IBOutlet NSTextField	*imInPortField;
@property (strong, nonatomic)	IBOutlet NSView			*downloadLocationView;

@property (strong, nonatomic)	IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*torPortField;

@end



/*
** TCPanel_Advanced
*/
#pragma mark - TCPanel_Advanced

@implementation TCPanel_Advanced

@synthesize panelProxy;
@synthesize panelPreviousContent;

- (void)dealloc
{
    TCDebugLog(@"TCPanel_Advanced dealloc");
}


/*
** TCPanel_Advanced - SMAssistantPanel
*/
#pragma mark - TCPanel_Advanced - SMAssistantPanel

+ (id <SMAssistantPanel>)panelInstance
{
	return [[TCPanel_Advanced alloc] initWithNibName:@"AssistantPanel_Advanced" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_advanced";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_advanced", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (id)panelContent
{
	// Set up the config with the fields.
	[_currentConfig setTorAddress:[_torAddressField stringValue]];
	[_currentConfig setSelfIdentifier:[_imIdentifierField stringValue]];
	
	[_currentConfig setTorPort:(uint16_t)[_torPortField intValue]];
	[_currentConfig setClientPort:(uint16_t)[_imInPortField intValue]];
	
	// Return the config.
	return _currentConfig;
}

- (void)panelDidAppear
{
	_currentConfig = self.panelPreviousContent;
	
	// Configure assistant.
	[self.panelProxy setIsLastPanel:YES];
	
	[_currentConfig setMode:TCConfigModeAdvanced];
	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_currentConfig component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
}

@end
