/*
 *  TCTorManager.mm
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#include <signal.h>

#import "TCTorManager.h"

#import "TCCocoaConfig.h"
#import "TCLogsController.h"

#include "TCBuffer.h"



/*
** Globals
*/
#pragma mark -
#pragma mark Globals

static pid_t torPid = -1;



/*
** Prototypes
*/
#pragma mark -
#pragma mark Prototypes

void catch_signal(int sig);



/*
** TCTorManager - Private
*/
#pragma mark -
#pragma mark TCTorManager - Private

@interface TCTorManager (Private)

- (NSString *)stringWithCPPString:(const std::string &)str;
- (void)postNotification:(NSString *)notice;

@end



/*
** TCTorManager
*/
#pragma mark -
#pragma mark TCTorManager

@implementation TCTorManager


/*
** TCTorManager - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCTorManager - Constructor & Destructor

+ (TCTorManager *)sharedManager
{
	static TCTorManager		*shr = nil;
	static dispatch_once_t	pred;
	
	dispatch_once(&pred, ^{
		shr = [[TCTorManager alloc] init];
		
		signal(SIGINT, catch_signal);
	});
	
	return shr;
}

- (id)init
{
    if ((self = [super init]))
	{
        mainQueue = dispatch_queue_create("com.torchat.cocoa.tormanager.main", NULL);
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appWillQuit:) name:NSApplicationWillTerminateNotification object:nil];
    }
    
    return self;
}

- (void)dealloc
{
	// Stop notification
	[[NSNotificationCenter defaultCenter] removeObserver:self];
		
	// Kill the task
	[_task waitUntilExit];
	[_task release];
	_task = nil;
	torPid = -1;
	
	// Close out source
	if (outSource)
	{
		dispatch_source_cancel(outSource);
		dispatch_release(outSource);
	}
	
	// Close err source
	if (errSource)
	{
		dispatch_source_cancel(errSource);
		dispatch_release(errSource);
	}
	
	// Release hidden
	[_hidden release];
	
	// Kill the timer
	if (testTimer)
	{
		dispatch_source_cancel(testTimer);
		dispatch_release(testTimer);
	}
	
	// Kill the queue
	dispatch_release(mainQueue);
	
	// Remove notification
	[[NSNotificationCenter defaultCenter] removeObserver:self];

    [super dealloc];
}



/*
** TCTorManager - Notification
*/
#pragma mark -
#pragma mark TCTorManager - Notification

- (void)appWillQuit:(NSNotification *)notice
{
	if (_task)
	{
		[_task terminate];
		
		[_task waitUntilExit];
		[_task release];
		
		_task = nil;
		torPid = -1;
	}
}



/*
** TCTorManager - Running
*/
#pragma mark -
#pragma mark TCTorManager - Running

- (void)startWithConfig:(TCConfig *)config
{
	if (!config)
		return;
	
	// Retain config
	config->retain();
	
	// Stop current session if running
	[self stop];
	
	// Run in the main queue
	dispatch_async(mainQueue, ^{
		
		if (_running)
		{
			config->release();
			return;
		}
		
		// Set the default value
		config->set_tor_address("localhost");
		config->set_tor_port(60600);
		config->set_client_port(60601);
		config->set_mode(tc_config_basic);
		
		// Convert configuration
		NSString		*data_path = [self stringWithCPPString:config->real_path(config->get_tor_data_path())];
		NSString		*hidden_path = [self stringWithCPPString:(config->real_path(config->get_tor_data_path()) + "/hidden/")];
		NSString		*tor_path = [self stringWithCPPString:config->real_path(config->get_tor_path())];
		
		// Check conversion
		if (!data_path || !hidden_path || !tor_path)
		{
			[[TCLogsController sharedController] addGlobalLogEntry:@"tor_err_build_path"];
			  
			config->release();
			[self postNotification:TCTorManagerStatusChanged];
			  
			return;
		}
		
		// Build folders
		NSFileManager *mng = [NSFileManager defaultManager];
		
		[mng createDirectoryAtPath:data_path withIntermediateDirectories:NO attributes:nil error:nil];
		[mng createDirectoryAtPath:hidden_path withIntermediateDirectories:NO attributes:nil error:nil];

		// Build argument
		NSMutableArray	*args = [NSMutableArray array];
		
		[args addObject:@"--ClientOnly"];
		[args addObject:@"1"];
		
		[args addObject:@"--SocksPort"];
		[args addObject:@"60600"];
		
		[args addObject:@"--SocksListenAddress"];
		[args addObject:@"localhost"];
		
		
		[args addObject:@"--DataDirectory"];
		[args addObject:data_path];
		
		[args addObject:@"--HiddenServiceDir"];
		[args addObject:hidden_path];
		
		[args addObject:@"--HiddenServicePort"];
		[args addObject:@"11009 127.0.0.1:60601"];   
		
		
		// Build & handle pipe for tor task
		NSPipe		*_errPipe = [[NSPipe alloc] init];
		NSPipe		*_outPipe = [[NSPipe alloc] init];
		TCBuffer	*_errBuffer = new TCBuffer();
		TCBuffer	*_outBuffer = new TCBuffer();
		int			errFD = [[_errPipe fileHandleForReading] fileDescriptor];
		int			outFD = [[_outPipe fileHandleForReading] fileDescriptor];
		
		// Create source for pipe handle
		errSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, errFD, 0, mainQueue);
		outSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, outFD, 0, mainQueue);
		
		// Realease pipe when source canceled
		dispatch_source_set_cancel_handler(errSource, ^{ [_errPipe release]; _errBuffer->release(); });
		dispatch_source_set_cancel_handler(outSource, ^{ [_outPipe release]; _outBuffer->release(); });
		
		// Handle pipe data
		dispatch_source_set_event_handler(errSource, ^{
			unsigned long	size = dispatch_source_get_data(errSource);
			void			*data = malloc(size);
			ssize_t			res;
			
			if (data && (res = read(errFD, data, size)) > 0)
			{
				std::string *line;
				
				_errBuffer->appendData(data, res, false);
				line = _errBuffer->createStringSearch("\n", false);
				
				while ((line = _outBuffer->createStringSearch("\n", false)))
				{
					[[TCLogsController sharedController] addGlobalLogEntry:@"tor_err_log", line->c_str()];
					delete line;
				}
			}
			else
			{
				free(data);
				
				if (errSource)
				{
					dispatch_source_cancel(errSource);
					dispatch_release(errSource);
					errSource = 0;
				}
			}
		});
		
		dispatch_source_set_event_handler(outSource, ^{
			unsigned long	size = dispatch_source_get_data(outSource);
			void			*data = malloc(size);
			ssize_t			res;
			
			if (data && (res = read(outFD, data, size)) > 0)
			{
				std::string *line;
				
				_outBuffer->appendData(data, res, false);
				while ((line = _outBuffer->createStringSearch("\n", false)))
				{
					[[TCLogsController sharedController] addGlobalLogEntry:@"tor_out_log", line->c_str()];
					delete line;
				}
			}
			else
			{
				free(data);
				
				if (outSource)
				{
					dispatch_source_cancel(outSource);
					dispatch_release(outSource);
					outSource = 0;
				}
			}
		});
		
		// Activate sources
		dispatch_resume(errSource);
		dispatch_resume(outSource);

		// Build tor task
		_task = [[NSTask alloc] init];
		
		[_task setLaunchPath:tor_path];
		[_task setArguments:args];
		
		[_task setStandardError:_errPipe];
		[_task setStandardOutput:_outPipe];

		
		// Run tor task
		@try
		{
			[_task launch];
		}
		@catch (id error)
		{
			[[TCLogsController sharedController] addGlobalLogEntry:@"tor_err_launch"];
			
			config->release();
			[self postNotification:TCTorManagerStatusChanged];
			return;
		}
		
		torPid = [_task processIdentifier];
		
		// Check the existence of the hotname file
		std::string htname = config->real_path(config->get_tor_data_path()) + "/hidden/hostname";
		char		*cstname = strdup(htname.c_str());
		
		testTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, mainQueue);
		
		dispatch_source_set_timer(testTimer, DISPATCH_TIME_NOW, 1000000000L, 0);
		
		dispatch_source_set_event_handler(testTimer, ^{
			FILE *f = fopen(cstname, "r");
			
			if (f)
			{
				char	buffer[1024];
				size_t	rsz;
				
				rsz = fread(buffer, 1, sizeof(buffer) - 1, f);
				
				if (rsz > 0)
				{
					char *fnd;
					
					// End the string
					buffer[rsz] = '\0';
					
					// Search for the end part
					fnd = strstr(buffer, ".onion");
					
					if (fnd)
					{
						// End the string on the end part
						*fnd = '\0';
						
						// Build NSString address
						[_hidden release];
						_hidden = [[NSString alloc] initWithUTF8String:buffer];
						
						// Set the address in the config
						config->set_self_address(buffer);
						
						// Cancel ourself
						dispatch_source_cancel(testTimer);
						dispatch_release(testTimer);
						testTimer = 0;
						
						// Inform of the change
						_running = YES;
						[self postNotification:TCTorManagerStatusChanged];
					}
				}

				// Close
				fclose(f);
			}
		});
		
		// Clean items on cancel
		dispatch_source_set_cancel_handler(testTimer, ^{
			config->release();
			free(cstname);
		});

		// Start timer
		config->retain();
		dispatch_resume(testTimer);

		// Release config
		config->release();
	});
}

- (void)stop
{
	dispatch_async(mainQueue, ^{
		
		if (!_running)
			return;
		
		_running = NO;
		

		// kill tor
		if (_task)
		{
			[_task terminate];
			
			[_task waitUntilExit];
			[_task release];
			
			_task = nil;
			torPid = -1;
		}
		
		// Close error pipe handling
		if (errSource)
		{
			dispatch_source_cancel(errSource);
			dispatch_release(errSource);
			
			errSource = 0;
		}
		
		// Close output pipe handling
		if (outSource)
		{
			dispatch_source_cancel(outSource);
			dispatch_release(outSource);
			
			outSource = 0;
		}
		

		// Clean hidden hostname
		[_hidden release];
		_hidden = nil;
		
		// Kill timer
		if (testTimer)
		{
			dispatch_source_cancel(testTimer);
			dispatch_release(testTimer);
			
			testTimer = 0;
		}
	});
}

- (BOOL)isRunning
{
	__block BOOL result = NO;
	
	dispatch_sync(mainQueue, ^{
		result = _running;
	});
	
	return result;
}



/*
** TCTorManager - FileHandle
*/
#pragma mark -
#pragma mark TCTorManager - FileHandle

- (void)torOutput:(NSNotification *)notice
{
	NSData		*data = [[notice userInfo] objectForKey:NSFileHandleNotificationDataItem];
	NSString	*str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	
	NSLog(@"Str = [%@]", str);
	
	//readInBackgroundAndNotify
	
}



/*
** TCTorManager - Property
*/
#pragma mark -
#pragma mark TCTorManager - Property

- (NSString *)hiddenHostname
{
	__block NSString *result = nil;
	
	dispatch_sync(mainQueue, ^{
		if (_hidden)
			result = [[NSString alloc] initWithString:_hidden];
	});
	
	return [result autorelease];
}



/*
** TCTorManager - Tools
*/
#pragma mark -
#pragma mark TCTorManager - Tools

- (NSString *)stringWithCPPString:(const std::string &)str
{
	const char *cstr = str.c_str();
	
	if (!cstr)
		return nil;
	
	return [NSString stringWithUTF8String:cstr];
}

- (void)postNotification:(NSString *)notice
{
	NSDictionary *info = [NSDictionary dictionaryWithObjectsAndKeys:(_hidden ? _hidden : @""),			TCTorManagerInfoHostNameKey,
																	[NSNumber numberWithBool:_running],	TCTorManagerInfoRunningKey,
																	nil];
	
	if (_running)
		[[TCLogsController sharedController] addGlobalLogEntry:@"tor_is_running"];
	else
		[[TCLogsController sharedController] addGlobalLogEntry:@"tor_is_not_running"];
	
	// Notify
	dispatch_async(dispatch_get_main_queue(), ^{
		[[NSNotificationCenter defaultCenter] postNotificationName:notice object:self userInfo:info];
	});
}

@end



/*
** C Tools
*/
#pragma mark -
#pragma mark C Tools

void catch_signal(int sig)
{
	if (torPid > 0)
		kill(torPid, SIGINT);
}
