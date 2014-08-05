/*
 *  TCTorManager.m
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



#include <signal.h>

#if defined(DEBUG) && DEBUG
# include <libproc.h>
#endif

#import "TCTorManager.h"

#import "TCConfigPlist.h"
#import "TCLogsManager.h"

#import "TCBuffer.h"



/*
** TCTorManager - Private
*/
#pragma mark - TCTorManager - Private

@interface TCTorManager ()
{
	dispatch_queue_t	_localQueue;
	dispatch_queue_t	_eventQueue;

	dispatch_source_t	_testTimer;
	
	dispatch_source_t	_termSource;
	
	id <TCConfig>		_configuration;
	
    BOOL				_running;
	
	NSTask				*_task;
	
	NSFileHandle		*_errHandle;
	NSFileHandle		*_outHandle;
	
	NSString			*_hidden;
}

@end



/*
** TCTorManager
*/
#pragma mark - TCTorManager

@implementation TCTorManager


/*
** TCTorManager - Instance
*/
#pragma mark - TCTorManager - Instance

- (id)initWithConfiguration:(id <TCConfig>)configuration
{
	self = [super init];
	
    if (self)
	{
		if (!configuration)
			return nil;
		
		// Create queues.
        _localQueue = dispatch_queue_create("com.torchat.cocoa.tormanager.local", DISPATCH_QUEUE_SERIAL);
		_eventQueue = dispatch_queue_create("com.torchat.cocoa.tormanager.event", DISPATCH_QUEUE_SERIAL);
		
		// Handle configuration.
		_configuration = configuration;
		
		// Handle application standard termination.
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationWillTerminate:) name:NSApplicationWillTerminateNotification object:nil];
		
		// SIGTERM handle.
		signal(SIGTERM, SIG_IGN);

		_termSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, _localQueue);
		
		dispatch_source_set_event_handler(_termSource, ^{
			[self terminateTor];
			exit(0);
		});
		
		dispatch_resume(_termSource);
	}
    
    return self;
}

- (void)dealloc
{
	// Stop notification.
	[[NSNotificationCenter defaultCenter] removeObserver:self];
		
	// Kill the task
	[_task waitUntilExit];
	
	_task = nil;
	
	_outHandle.readabilityHandler = nil;
	_errHandle.readabilityHandler = nil;

	// Kill the timer
	if (_testTimer)
		dispatch_source_cancel(_testTimer);
}



/*
** TCTorManager - Notification
*/
#pragma mark - TCTorManager - Notification

- (void)applicationWillTerminate:(NSNotification *)notice
{
	[self terminateTor];
}



/*
** TCTorManager - Running
*/
#pragma mark - TCTorManager - Running

- (void)start
{
#if defined(DEBUG) && DEBUG
	
	// To speed up debugging, if we are building in debug mode, do not launch a new tor instance if there is already one running.
	
	int count = proc_listpids(PROC_ALL_PIDS, 0, NULL, 0);
	
	if (count > 0)
	{
		pid_t *pids = malloc((unsigned)count * sizeof(pid_t));
		
		count = proc_listpids(PROC_ALL_PIDS, 0, pids, count * (int)sizeof(pid_t));

		for (int i = 0; i < count; ++i)
		{
			char name[1024];
						
			if (proc_name(pids[i], name, sizeof(name)) > 0)
			{
				if (strcmp(name, "tor") == 0)
				{
					free(pids);
					return;
				}
			}

		}

		free(pids);
	}
#endif
	
	// Stop current session if running.
	[self stop];
	
	// Run in the main queue.
	dispatch_async(_localQueue, ^{
		
		if (_running)
			return;
		
#warning FIXME: handle instalation if necessary.
		return;
		NSString	*data_path = [_configuration realPath:[_configuration torDataPath]];
		NSString	*hidden_path = [_configuration realPath:[[_configuration torDataPath] stringByAppendingPathComponent:@"hidden"]];
		NSString	*tor_path = [_configuration realPath:[_configuration torPath]];
		
		// Check conversion.
		if (!data_path || !hidden_path || !tor_path)
		{
			[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_err_build_path"];
			[self sendEvent:TCTorManagerEventError context:nil];
			return;
		}
		
		// Build folders.
		NSFileManager *mng = [NSFileManager defaultManager];
		
		[mng createDirectoryAtPath:data_path withIntermediateDirectories:NO attributes:nil error:nil];
		[mng createDirectoryAtPath:hidden_path withIntermediateDirectories:NO attributes:nil error:nil];

		// Build argument.
		NSMutableArray	*args = [NSMutableArray array];
		
		[args addObject:@"--ClientOnly"];
		[args addObject:@"1"];
		
		[args addObject:@"--SocksPort"];
		[args addObject:[@([_configuration torPort]) stringValue]];
		
		[args addObject:@"--SocksListenAddress"];
		[args addObject:([_configuration torAddress] ?: @"localhost")];
		
		
		[args addObject:@"--DataDirectory"];
		[args addObject:data_path];
		
		[args addObject:@"--HiddenServiceDir"];
		[args addObject:hidden_path];
		
		[args addObject:@"--HiddenServicePort"];
		[args addObject:[NSString stringWithFormat:@"11009 127.0.0.1:%u", [_configuration clientPort]]];
		
		
		// Build & handle pipe for tor task.
		NSPipe			*errPipe = [[NSPipe alloc] init];
		NSPipe			*outPipe = [[NSPipe alloc] init];
		TCBuffer		*errBuffer = [[TCBuffer alloc] init];
		TCBuffer		*outBuffer =  [[TCBuffer alloc] init];
		dispatch_queue_t	localQueue = _localQueue;
		
		_errHandle = [errPipe fileHandleForReading];
		_outHandle = [outPipe fileHandleForReading];
				
		_errHandle.readabilityHandler = ^(NSFileHandle *handle) {
			
			NSData *data;
			
			@try {
				data = [handle availableData];
			}
			@catch (NSException *exception) {
				handle.readabilityHandler = nil;
				return;
			}
		
			// Parse data.
			dispatch_async(localQueue, ^{
				
				NSData *line;

				[errBuffer appendBytes:[data bytes] ofSize:[data length] copy:YES];

				[errBuffer dataUpToCStr:"\n" includeSearch:NO];

				while ((line = [errBuffer dataUpToCStr:"\n" includeSearch:NO]))
				{
					NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
					
					[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_err_log", [string UTF8String]];
				}
			});
		};
		
		_outHandle.readabilityHandler = ^(NSFileHandle *handle) {
						
			NSData *data;
			
			@try {
				data = [handle availableData];
			}
			@catch (NSException *exception) {
				handle.readabilityHandler = nil;
				return;
			}
			
			// Parse data.
			dispatch_async(localQueue, ^{
				
				NSData *line;
				
				[outBuffer appendBytes:[data bytes] ofSize:[data length] copy:YES];
				
				[outBuffer dataUpToCStr:"\n" includeSearch:NO];
				
				while ((line = [outBuffer dataUpToCStr:"\n" includeSearch:NO]))
				{
					NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
					
					[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_out_log", [string UTF8String]];
				}
			});
		};
		
		// Build tor task
		_task = [[NSTask alloc] init];
		
		[_task setLaunchPath:tor_path];
		[_task setArguments:args];
		
		[_task setStandardError:errPipe];
		[_task setStandardOutput:outPipe];

		// Run tor task
		@try
		{
			[_task launch];
		}
		@catch (id error)
		{
			[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_err_launch"];
			[self sendEvent:TCTorManagerEventError context:nil];
			return;
		}
		
		// Check the existence of the hostname file
		NSString *htname = [_configuration realPath:[[_configuration torDataPath] stringByAppendingPathComponent:@"hidden/hostname"]];
		
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
						[_configuration setSelfAddress:_hidden];
						
						// Cancel ourself
						dispatch_source_cancel(_testTimer);
						_testTimer = nil;
						
						// Inform of the change.
						_running = YES;
						[self sendEvent:TCTorManagerEventRunning context:nil];
						[self sendEvent:TCTorManagerEventHostname context:_hidden];
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

		// Terminate tor.
		[self terminateTor];
		
		// Stop handle.
		_errHandle.readabilityHandler = nil;
		_outHandle.readabilityHandler = nil;
		
		_errHandle = nil;
		_outHandle = nil;

		// Clean hidden hostname.
		_hidden = nil;
		
		// Kill timer.
		if (_testTimer)
		{
			dispatch_source_cancel(_testTimer);
			_testTimer = nil;
		}
		
		// Notify.
		[self sendEvent:TCTorManagerEventStopped context:nil];
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
** TCTorManager - Helpers
*/
#pragma mark - TCTorManager - Helpers

- (void)sendEvent:(TCTorManagerEvent)event context:(id)context
{
	dispatch_async(_eventQueue, ^{
		
		void (^eventHandler)(TCTorManagerEvent event, id context) = _eventHandler;
		
		if (!eventHandler)
			return;
		
		eventHandler(event, context);
	});
}

- (void)terminateTor
{
	if (_task)
	{
		[_task terminate];
		
		[_task waitUntilExit];
		
		_task = nil;
	}
}

@end
