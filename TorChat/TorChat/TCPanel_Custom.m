/*
 *  TCPanel_Custom.m
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

#import "TCPanel_Custom.h"

#import "TCLogsManager.h"
#import "TCConfigAppEncryptable.h"

#import "TCLocationViewController.h"

#import "TCDebugLog.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** TCPanel_Custom - Private
*/
#pragma mark - TCPanel_Custom - Private

@interface TCPanel_Custom ()
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
** TCPanel_Custom
*/
#pragma mark - TCPanel_Custom

@implementation TCPanel_Custom

@synthesize panelProxy;
@synthesize panelPreviousContent;

- (void)dealloc
{
    TCDebugLog(@"TCPanel_Custom dealloc");
}


/*
** TCPanel_Custom - SMAssistantPanel
*/
#pragma mark - TCPanel_Custom - SMAssistantPanel

+ (id <SMAssistantPanel>)panelInstance
{
	return (id <SMAssistantPanel>)[[TCPanel_Custom alloc] initWithNibName:@"AssistantPanel_Custom" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_custom";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_custom", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (nullable id)panelContent
{
	// Set up the config with the fields.
	_currentConfig.torAddress = _torAddressField.stringValue;
	_currentConfig.selfIdentifier = _imIdentifierField.stringValue;
	
	_currentConfig.torPort = (uint16_t)_torPortField.intValue;
	_currentConfig.selfPort = (uint16_t)_imInPortField.intValue;
	
	// Return the config.
	return _currentConfig;
}

- (void)panelDidAppear
{
	_currentConfig = self.panelPreviousContent;
	
	// Configure assistant.
	[self.panelProxy setIsLastPanel:YES];
	
	[_currentConfig setMode:TCConfigModeCustom];
	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_currentConfig component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
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

@end


NS_ASSUME_NONNULL_END
