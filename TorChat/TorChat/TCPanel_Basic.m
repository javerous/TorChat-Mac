/*
 *  TCPanel_Basic.m
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

@import SMFoundation;
@import SMTor;

#import "TCPanel_Basic.h"

#import "TCLogsManager.h"
#import "TCConfigAppEncryptable.h"

#import "TCLocationViewController.h"

#import "TCDebugLog.h"
#import "SMTorConfiguration+TCConfig.h"


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** TCPanel_Basic - Private
*/
#pragma mark - TCPanel_Basic - Private

@interface TCPanel_Basic ()
{
	id <TCConfigAppEncryptable> _currentConfig;
	SMTorManager *_tor;
	
	TCLocationViewController *_torDownloadsLocation;
}

@property (strong, nonatomic)	IBOutlet NSTextField			*imIdentifierField;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator	*loadingIndicator;
@property (strong, nonatomic)	IBOutlet NSView					*downloadLocationView;

@end



/*
** TCPanel_Basic
*/
#pragma mark - TCPanel_Basic

@implementation TCPanel_Basic

@synthesize panelProxy;
@synthesize panelPreviousContent;


/*
** TCPanel_Basic - Instance
*/
#pragma mark - TCPanel_Basic - Instance

- (void)dealloc
{
	TCDebugLog(@"TCPanel_Basic dealloc");
}



/*
** TCPanel_Basic - SMAssistantPanel
*/
#pragma mark - TCPanel_Basic - SMAssistantPanel

+ (id <SMAssistantPanel>)panelInstance
{
	return [[TCPanel_Basic alloc] initWithNibName:@"AssistantPanel_Basic" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_basic";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_basic", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (id)panelContent
{
	return _currentConfig;
}

- (void)panelDidAppear
{
	_currentConfig = self.panelPreviousContent;

	[self.panelProxy setIsLastPanel:YES];
	[self.panelProxy setDisableContinue:YES]; // Wait for tor
	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_currentConfig component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
	
	// Set default configuration.
	_currentConfig.torAddress = @"localhost";
	_currentConfig.torPort = 60600;
	_currentConfig.clientPort = 60601;
	
	// Create tor configuration.
	SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:_currentConfig];
	
	// Create tor manager & start it.
	__weak NSTextField *weakIMIdentifierField = _imIdentifierField;
	
	_tor = [[SMTorManager alloc] initWithConfiguration:torConfig];
	
	[_loadingIndicator startAnimation:self];

	[_tor startWithInfoHandler:^(SMInfo *info) {
		
		NSTextField *imIdentifierField = weakIMIdentifierField;
		
		dispatch_async(dispatch_get_main_queue(), ^{

			if (info.kind == SMInfoError)
			{
				[_loadingIndicator stopAnimation:self];
				[self.panelProxy setDisableContinue:YES];
			}
			else if (info.kind == SMInfoInfo)
			{
				if (info.code == SMTorManagerEventStartHostname)
				{
					[imIdentifierField setStringValue:info.context];
					[_currentConfig setSelfIdentifier:info.context];
					[_tor stopWithCompletionHandler:nil];
				}
				else if (info.code == SMTorManagerEventStartDone)
				{
					[_tor stopWithCompletionHandler:^{
						dispatch_async(dispatch_get_main_queue(), ^{
							[_loadingIndicator stopAnimation:self];
							[self.panelProxy setDisableContinue:NO];
						});
					}];
				}
			}
			else if (info.kind == SMInfoWarning)
			{
				if (info.code == SMTorManagerWarningStartCanceled)
				{
					[_loadingIndicator stopAnimation:self];

					if (imIdentifierField.stringValue.length > 0)
						[self.panelProxy setDisableContinue:NO];
				}
			}
		});
	}];
}

@end
