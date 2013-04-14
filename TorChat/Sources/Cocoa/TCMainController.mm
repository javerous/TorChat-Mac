/*
 *  TCMainController.mm
 *
 *  Copyright 2012 Avérous Julien-Pierre
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

#import "TCCocoaConfig.h"
#import "TCAssistantController.h"
#import "TCLogsController.h"
#import "TCBuddiesController.h"

#if defined(PROXY_ENABLED) && PROXY_ENABLED
# import "TCConfigProxy.h"
#endif



/*
** TCMainController - Private
*/
#pragma mark - TCMainController - Private

@interface TCMainController ()
{
	TCConfig	*_config;

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

- (void)dealloc
{
	if (_config)
		_config->release();
	
    [super dealloc];
}



/*
** TCMainController - Running
*/
#pragma mark - TCMainController - Running

- (void)start
{
	static BOOL		running = NO;

	TCCocoaConfig	*conf = NULL;

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
			try
			{
				conf = new TCCocoaConfig((id <TCConfigProxy>)proxy);
			}
			catch (const char *err)
			{
				NSString *oerr = [NSString stringWithUTF8String:err];
				
				[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_read_proxy", NSLocalizedString(oerr, @"")];
				
				if (conf)
					delete conf;
				
				conf = NULL;
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
			try
			{
				conf = new TCCocoaConfig(path);
			}
			catch (const char *err)
			{
				NSString *oerr = [NSString stringWithUTF8String:err];
				
				[[TCLogsController sharedController] addGlobalAlertLog:@"ac_err_read_file", NSLocalizedString(oerr, @"")];
				
				if (conf)
					delete conf;
				
				conf = NULL;
			}
		}
	}

	// > Check if we should launch assistant
	if (!conf)
		[[TCAssistantController sharedController] startWithCallback:@selector(assistantCallback:) onObject:self];
	else
	{
		// > Hold the config
		_config = conf;
		
		// > Start buddy controller
		[[TCBuddiesController sharedController] startWithConfig:conf];
	}
}

- (void)assistantCallback:(NSValue *)content
{
	TCCocoaConfig *conf = static_cast<TCCocoaConfig *>([content pointerValue]);
	
	// Hold the config
	_config = conf;
	
	// Start buddy controller
	[[TCBuddiesController sharedController] startWithConfig:conf];
}



/*
** TCMainController - Accessor
*/
#pragma mark - TCMainController - Accessor

- (TCConfig *)config
{
	return _config;
}

@end
