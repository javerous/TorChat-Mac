/*
 *  TCTorManager.mm
 *
 *  Copyright 2013 Avérous Julien-Pierre
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

#import "TCBuffer.h"



/*
** Globals
*/
#pragma mark - Globals

static pid_t torPid = -1;



/*
** Prototypes
*/
#pragma mark - Prototypes

void catch_signal(int sig);



/*
** TCTorManager - Private
*/
#pragma mark - TCTorManager - Private

@interface TCTorManager ()
{
    BOOL				_running;
	
	NSTask				*_task;
	dispatch_source_t	_errSource;
	dispatch_source_t	_outSource;
	
	NSString			*_hidden;
	
	dispatch_queue_t	_localQueue;
	dispatch_source_t	_testTimer;
}

- (void)postNotification:(NSString *)notice;

@end



/*
** TCTorManager
*/
#pragma mark - TCTorManager

@implementation TCTorManager


/*
** TCTorManager - Constructor & Destructor
*/
#pragma mark - TCTorManager - Constructor & Destructor

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
	self = [super init];
	
    if (self)
	{
        _localQueue = dispatch_queue_create("com.torchat.cocoa.tormanager.local", DISPATCH_QUEUE_SERIAL);
		
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
	
	_task = nil;
	torPid = -1;
	
	// Close out source
	if (_outSource)
		dispatch_source_cancel(_outSource);
	
	// Close err source
	if (_errSource)
		dispatch_source_cancel(_errSource);
	
	
	// Kill the timer
	if (_testTimer)
		dispatch_source_cancel(_testTimer);
	
	// Remove notification
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}



/*
** TCTorManager - Notification
*/
#pragma mark - TCTorManager - Notification

- (void)appWillQuit:(NSNotification *)notice
{
	if (_task)
	{
		[_task terminate];
		
		[_task waitUntilExit];
		
		_task = nil;
		torPid = -1;
	}
}



/*
** TCTorManager - Running
*/
#pragma mark - TCTorManager - Running

- (void)startWithConfiguration:(id <TCConfig>)configuration
{
	if (!configuration)
		return;

	// Stop current session if running
	[self stop];
	
	// Run in the main queue
	dispatch_async(_localQueue, ^{
		
		if (_running)
			return;
		
		// Set the default value
		[configuration setTorAddress:@"localhost"];
		[configuration setTorPort:60600];
		[configuration setClientPort:60601];
		[configuration setMode:tc_config_basic];
		
		// Convert configuration
		NSString	*data_path = [configuration realPath:[configuration torDataPath]];
		NSString	*hidden_path = [configuration realPath:[[configuration torDataPath] stringByAppendingPathComponent:@"hidden"]];
		NSString	*tor_path = [configuration realPath:[configuration torPath]];
		
		// Check conversion
		if (!data_path || !hidden_path || !tor_path)
		{
			[[TCLogsController sharedController] addGlobalLogEntry:@"tor_err_build_path"];
			  
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
		TCBuffer	*_errBuffer = [[TCBuffer alloc] init];
		TCBuffer	*_outBuffer =  [[TCBuffer alloc] init];
		int			errFD = [[_errPipe fileHandleForReading] fileDescriptor];
		int			outFD = [[_outPipe fileHandleForReading] fileDescriptor];
		
		// Create source for pipe handle
		_errSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)errFD, 0, _localQueue);
		_outSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_READ, (uintptr_t)outFD, 0, _localQueue);
		
		// Realease pipe when source canceled
		dispatch_source_set_cancel_handler(_errSource, ^{ });
		dispatch_source_set_cancel_handler(_outSource, ^{ });
		
		// Handle pipe data
		dispatch_source_set_event_handler(_errSource, ^{
			
			unsigned long	size = dispatch_source_get_data(_errSource);
			void			*data = malloc(size);
			ssize_t			res;
			
			if (data && (res = read(errFD, data, size)) > 0)
			{
				NSData *line;
				
				[_errBuffer appendBytes:data ofSize:(NSUInteger)res copy:NO];

				line = [_errBuffer dataUpToCStr:"\n" includeSearch:NO];
				
				while ((line = [_outBuffer dataUpToCStr:"\n" includeSearch:NO]))
				{
					NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
					
					[[TCLogsController sharedController] addGlobalLogEntry:@"tor_err_log", [string UTF8String]];
				}
			}
			else
			{
				free(data);
				
				if (_errSource)
				{
					dispatch_source_cancel(_errSource);
					_errSource = nil;
				}
			}
		});
		
		dispatch_source_set_event_handler(_outSource, ^{
			unsigned long	size = dispatch_source_get_data(_outSource);
			void			*data = malloc(size);
			ssize_t			res;
			
			if (data && (res = read(outFD, data, size)) > 0)
			{
				NSData *line;
				
				[_outBuffer appendBytes:data ofSize:(NSUInteger)res copy:NO];
				
				while ((line = [_outBuffer dataUpToCStr:"\n" includeSearch:NO]))
				{
					NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];

					[[TCLogsController sharedController] addGlobalLogEntry:@"tor_out_log", [string UTF8String]];
				}
			}
			else
			{
				free(data);
				
				if (_outSource)
				{
					dispatch_source_cancel(_outSource);
					_outSource = nil;
				}
			}
		});
		
		// Activate sources
		dispatch_resume(_errSource);
		dispatch_resume(_outSource);

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
			
			[self postNotification:TCTorManagerStatusChanged];
			return;
		}
		
		torPid = [_task processIdentifier];
		
		// Check the existence of the hostname file
		NSString *htname = [configuration realPath:[[configuration torDataPath] stringByAppendingPathComponent:@"hidden/hostname"]];
		
		_testTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
		
		dispatch_source_set_timer(_testTimer, DISPATCH_TIME_NOW, 1000000000L, 0);
		
		dispatch_source_set_event_handler(_testTimer, ^{
			
			FILE *f = fopen([htname UTF8String], "r");
			
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
						_hidden = [[NSString alloc] initWithUTF8String:buffer];
						
						// Set the address in the config
						[configuration setSelfAddress:_hidden];
						
						// Cancel ourself
						dispatch_source_cancel(_testTimer);
						_testTimer = 0;
						
						// Inform of the change
						_running = YES;
						[self postNotification:TCTorManagerStatusChanged];
					}
				}

				// Close
				fclose(f);
			}
		});
		
		// Start timer
		dispatch_resume(_testTimer);
	});
}

- (void)stop
{
	dispatch_async(_localQueue, ^{
		
		if (!_running)
			return;
		
		_running = NO;
		

		// kill tor
		if (_task)
		{
			[_task terminate];
			
			[_task waitUntilExit];
			
			_task = nil;
			torPid = -1;
		}
		
		// Close error pipe handling
		if (_errSource)
		{
			dispatch_source_cancel(_errSource);
			_errSource = nil;
		}
		
		// Close output pipe handling
		if (_outSource)
		{
			dispatch_source_cancel(_outSource);
			_outSource = nil;
		}
		

		// Clean hidden hostname
		_hidden = nil;
		
		// Kill timer
		if (_testTimer)
		{
			dispatch_source_cancel(_testTimer);
			_testTimer = nil;
		}
	});
}

- (BOOL)isRunning
{
	__block BOOL result = NO;
	
	dispatch_sync(_localQueue, ^{
		result = _running;
	});
	
	return result;
}



/*
** TCTorManager - Property
*/
#pragma mark - TCTorManager - Property

- (NSString *)hiddenHostname
{
	__block NSString *result = nil;
	
	dispatch_sync(_localQueue, ^{
		
		if (_hidden)
			result = [[NSString alloc] initWithString:_hidden];
	});
	
	return result;
}



/*
** TCTorManager - Tools
*/
#pragma mark - TCTorManager - Tools

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
#pragma mark - C Tools

void catch_signal(int sig)
{
	if (torPid > 0)
		kill(torPid, SIGINT);
}
