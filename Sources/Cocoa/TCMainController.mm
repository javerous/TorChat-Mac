/*
 *  TCMainController.mm
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



/*
** TCMainController
*/
#pragma mark -
#pragma mark TCMainController

@implementation TCMainController


/*
** TCMainController - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCMainController - Constructor & Destructor

+ (TCMainController *)sharedController
{
	static dispatch_once_t		pred;
	static TCMainController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCMainController alloc] init];
	});
	
	return instance;
}

- (id)init
{
    if ((self = [super init]))
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
#pragma mark -
#pragma mark TCMainController - Running

- (void)start
{
	static BOOL running = NO;
	
	if (running)
		return;
	running = YES;
	
	// -- Load config file --
	NSFileManager	*mng = [NSFileManager defaultManager];
	NSBundle		*bundle = [NSBundle mainBundle];
	NSString		*path = nil;
	BOOL			assist = NO;
	
	// > Try to find config on the same folder as the application
	path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
	
	// > Try to find on home
	if ([mng fileExistsAtPath:path] == NO)
	{
		path = [@"~/torchat.conf" stringByExpandingTildeInPath];
		
		if ([mng fileExistsAtPath:path] == NO)
			assist = YES;
	}
	
	// > Check if we should assist
	if (assist)
		[[TCAssistantController sharedController] startWithCallback:@selector(assistantCallback:) onObject:self];
	else
	{
		TCCocoaConfig *conf = NULL;
		
		// > Try to open the file
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
#pragma mark -
#pragma mark TCMainController - Accessor

- (TCConfig *)config
{
	return _config;
}

@end
