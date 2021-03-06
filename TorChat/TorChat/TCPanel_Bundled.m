/*
 *  TCPanel_Bundled.m
 *
 *  Copyright 2019 Avérous Julien-Pierre
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

#import <SMFoundation/SMFoundation.h>
#import <SMTor/SMTor.h>

#import "TCPanel_Bundled.h"

#import "TCLogsManager.h"
#import "TCConfigApp.h"

#import "TCLocationViewController.h"

#import "SMTorConfiguration+TCConfig.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** TCPanel_Bundled - Private
*/
#pragma mark - TCPanel_Bundled - Private

@interface TCPanel_Bundled ()
{
	id <TCConfigApp> _currentConfig;
	SMTorManager *_tor;
	
	TCLocationViewController *_torDownloadsLocation;
}

@property (strong, nonatomic)	IBOutlet NSTextField			*imIdentifierField;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator	*loadingIndicator;
@property (strong, nonatomic)	IBOutlet NSView					*downloadLocationView;

@end



/*
** TCPanel_Bundled
*/
#pragma mark - TCPanel_Bundled

@implementation TCPanel_Bundled

@synthesize panelProxy;
@synthesize panelPreviousContent;


/*
** TCPanel_Bundled - Instance
*/
#pragma mark - TCPanel_Bundled - Instance

- (void)dealloc
{
	TCDebugLog(@"TCPanel_Bundled dealloc");
}



/*
** TCPanel_Bundled - SMAssistantPanel
*/
#pragma mark - TCPanel_Bundled - SMAssistantPanel

+ (id <SMAssistantPanel>)panelInstance
{
	return (id <SMAssistantPanel>)[[TCPanel_Bundled alloc] initWithNibName:@"AssistantPanel_Bundled" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_bundled";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_bundled", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (nullable id)panelContent
{
	return _currentConfig;
}

- (void)panelDidAppear
{
	// Handle config.
	_currentConfig = self.panelPreviousContent;

	if (!_currentConfig)
	{
		[self.panelProxy setDisableContinue:YES];
		return;
	}
	
	// Configure assitant.
	[self.panelProxy setDisableContinue:YES]; // Wait for tor
	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_currentConfig component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
	
	// Set default configuration.
	_currentConfig.torAddress = @"localhost";
	_currentConfig.torPort = 60600;
	_currentConfig.selfPort = 60601;
	
	// Create tor configuration.
	SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:_currentConfig];
	
	if (!torConfig)
	{
		NSBeep();
		exit(0);
	}
	
	// Create tor manager & start it.
	__weak NSTextField *weakIMIdentifierField = _imIdentifierField;
	__block BOOL serviceIDDone = NO;
	__block BOOL servicePrivateKeyDone = NO;
	
	_tor = [[SMTorManager alloc] initWithConfiguration:torConfig];
	
	[_loadingIndicator startAnimation:self];

	[_tor startWithInfoHandler:^(SMInfo *info) {
		
		NSTextField *imIdentifierField = weakIMIdentifierField;

		dispatch_async(dispatch_get_main_queue(), ^{

			if (info.kind == SMInfoError)
			{
				imIdentifierField.stringValue = [info renderMessage];
				imIdentifierField.textColor = [NSColor redColor];
				
				[_loadingIndicator stopAnimation:self];
				
				[self.panelProxy setDisableContinue:YES];
			}
			else if (info.kind == SMInfoInfo)
			{
				if (info.code == SMTorEventStartServiceID)
				{
					imIdentifierField.stringValue = info.context;
					_currentConfig.selfIdentifier = info.context;
					
					serviceIDDone = YES;
					
					// Don't need to go further.
					if (serviceIDDone && servicePrivateKeyDone)
						[_tor stopWithCompletionHandler:nil];
				}
				else if (info.code == SMTorEventStartServicePrivateKey)
				{
					_currentConfig.selfPrivateKey = info.context;

					servicePrivateKeyDone = YES;
					
					// Don't need to go further.
					if (serviceIDDone && servicePrivateKeyDone)
						[_tor stopWithCompletionHandler:nil];
				}
				else if (info.code == SMTorEventStartDone)
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
				if (info.code == SMTorWarningStartCanceled)
				{
					[_loadingIndicator stopAnimation:self];

					if (_currentConfig.selfIdentifier != nil && _currentConfig.selfPrivateKey != nil)
						[self.panelProxy setDisableContinue:NO];
				}
			}
		});
	}];
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
