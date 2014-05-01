/*
 *  TCMainController.m
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



#import "TCMainController.h"

#import "TCConfigPlist.h"
#import "TCLogsManager.h"
#import "TCBuddiesWindowController.h"

#import "TCAssistantWindowController.h"
#import "TCPanel_Welcome.h"
#import "TCPanel_Mode.h"
#import "TCPanel_Advanced.h"
#import "TCPanel_Basic.h"

#if defined(PROXY_ENABLED) && PROXY_ENABLED
# import "TCConfigProxy.h"
#endif



/*
** TCMainController - Private
*/
#pragma mark - TCMainController - Private

@interface TCMainController ()
{
	id <TCConfig> _configuration;
	
	TCAssistantWindowController	*_assistant;
}

@end



/*
** TCMainController
*/
#pragma mark - TCMainController

@implementation TCMainController


/*
** TCMainController - Constructor & Destructor
*/
#pragma mark - TCMainController - Constructor & Destructor

+ (TCMainController *)sharedController
{
	static dispatch_once_t	pred;
	static TCMainController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCMainController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super init];
	
    if (self)
	{
    }
    
    return self;
}



/*
** TCMainController - Running
*/
#pragma mark - TCMainController - Running

- (void)start
{
	static BOOL		running = NO;

	TCConfigPlist	*conf = nil;

	// Can't have more than one instance of this controller
	if (running)
		return;
	
	running = YES;
	
	// -- Try loading config from proxy --
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	
	if (!conf)
	{
		NSDistantObject *proxy = [NSConnection rootProxyForConnectionWithRegisteredName:TCProxyName host:nil];
				
		if (proxy)
		{
			// Set protocol methods
			[proxy setProtocolForProxy:@protocol(TCConfigProxy)];
			
			// Load
			conf = [[TCConfigPlist alloc] initWithFileProxy:(id <TCConfigProxy>)proxy];

			if (!conf)
			{
				[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_read_proxy"];
				[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_err_read_proxy", @"")] runModal];
			}
		}
	}

#endif
	
	// -- Try loading config from file --
	if (!conf)
	{
		NSFileManager	*mng;
		NSBundle		*bundle;
		NSString		*path = nil;

		mng = [NSFileManager defaultManager];
		bundle = [NSBundle mainBundle];
		
		// > Try to find config on the same folder as the application
		if (!path)
		{
			path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
		
			if ([mng fileExistsAtPath:path] == NO)
				path = nil;
		}
		
		// > Try to find on config home folder
		if (!path)
		{
			path = [@"~/torchat.conf" stringByExpandingTildeInPath];
			
			if ([mng fileExistsAtPath:path] == NO)
				path = nil;
		}
		
		// > Try to open the file
		if (path)
		{
			conf = [[TCConfigPlist alloc] initWithFile:path];
			
			if (!conf)
			{
				NSString *key = NSLocalizedString(@"ac_err_read_file", @"");
				
				[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_err_read_file", path];
				[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:key, path] runModal];
			}
		}
	}

	// > Check if we should launch assistant
	if (!conf)
	{
		NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Mode class], [TCPanel_Advanced class], [TCPanel_Basic class] ];
		
		_assistant = [TCAssistantWindowController startAssistantWithPanels:panels andCallback:^(id context) {
			
			TCConfigPlist *config = (TCConfigPlist *)context;
			
			// Hold the config
			_configuration = config;
			
			// Start buddy controller
			[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration];
			
			// Remove instance.
			_assistant = nil;
		}];
	}
	else
	{
		// > Hold the config
		_configuration = conf;
		
		// > Start buddy controller
		[[TCBuddiesWindowController sharedController] startWithConfiguration:conf];
	}
}



/*
** TCMainController - Accessor
*/
#pragma mark - TCMainController - Accessor

- (id <TCConfig>)config
{
	return _configuration;
}

@end
