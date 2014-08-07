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

#import "TCLogsManager.h"

#import "TCConfigPlist.h"
#import "TCBuffer.h"
#import "TCOperationsQueue.h"

#import "TCFileSignature.h"
#import "TCPublicKey.h"



/*
** Defines
*/
#pragma mark - Defines

#define TCTorManagerFileSignature	@"Signature"
#define TCTorManagerFileBinaries	@"Binaries"
#define TCTorManagerFileInfo		@"Info.plist"
#define TCTorManagerFileTor			@"tor"

#define TCTorManagerKeyFiles		@"files"
#define TCTorManagerKeyTorVersion	@"tor_version"
#define TCTorManagerKeyHash			@"hash"



/*
** Prototypes
*/
#pragma mark - Prototypes

NSData *file_sha1(NSURL *fileURL);



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
	
	BOOL				_isStarted;
    BOOL				_isRunning;
	
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
			[self _terminateTor];
			exit(0);
		});
		
		dispatch_resume(_termSource);
		
		/*
		[self operationStageArchiveFile:[NSURL URLWithString:@"/Users/jp/Dropbox/Sources/TorChat-Mac/tor-update/TorChat/Resources/tor.tgz"] completionHandler:^(BOOL error) {
			
			if (error)
			{
				NSLog(@"Error: Can't stage archive");
				return;
			}
			
			[self operationCheckSignatureWithCompletionHandler:^(BOOL serror) {
				
				if (serror)
				{
					NSLog(@"Error: Signature invalid.");
					return;
				}
				
				NSLog(@"Info: Signature valid.");
				
				[self operationLaunchTor:^(BOOL terror) {
					
				}];
			}];
		}];
		 */
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
	[self _terminateTor];
}



/*
** TCTorManager - Life
*/
#pragma mark - TCTorManager - Life

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
	
	dispatch_async(_localQueue, ^{
		
		if (_isStarted || _isRunning)
			return;
		
		// Mark as started.
		_isStarted = YES;
		
		// Stop if running.
		[self _stop];
		
		// Start operations.
		TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
		
		// -- Stage archive --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			// Check that the binary is already there.
			NSFileManager	*manager = [NSFileManager defaultManager];
			NSString		*path = [_configuration pathForDomain:TConfigPathDomainTorBinary];
			
			path = [[path stringByAppendingPathComponent:TCTorManagerFileBinaries] stringByAppendingPathComponent:TCTorManagerFileTor];
			
			if ([manager fileExistsAtPath:path] == YES)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Stage the archive.
			NSURL *archiveUrl = [[NSBundle mainBundle] URLForResource:@"tor" withExtension:@"tgz"];
			
			[self operationStageArchiveFile:archiveUrl completionHandler:^(BOOL error) {
				
				if (error)
					ctrl(TCOperationsControlFinish);
				else
					ctrl(TCOperationsControlContinue);
			}];
		}];
		
		// -- Check signature --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			[self operationCheckSignatureWithCompletionHandler:^(BOOL error) {
				if (error)
					ctrl(TCOperationsControlFinish);
				else
					ctrl(TCOperationsControlContinue);
			}];
		}];

		// -- Launch binary --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {

			[self operationLaunchTor:^(BOOL error) {
				
				if (error)
				{
					ctrl(TCOperationsControlFinish);
					return;
				}
				
				_isRunning = YES;
				
				[self sendEvent:TCTorManagerEventRunning context:nil];
				
				ctrl(TCOperationsControlContinue);
			}];
		}];
		
		// -- Wait hostname --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {

			ctrl(TCOperationsControlContinue);

			
		}];
		
		// Start.
		[queue start];
	});
#if 0
	// Stop current session if running.
	[self stop];
	
	// Run in the main queue.
	dispatch_async(_localQueue, ^{
		
		if (_running)
			return;
#warning FIXME: handle instalation if necessary.
		return;

		
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
#endif
}

- (void)stop
{
	dispatch_async(_localQueue, ^{
		[self _stop];
	});
}

- (void)_stop
{
	// > localQueue <

	if (!_isRunning)
		return;
	
	_isRunning = NO;
	_isStarted = NO;
	
	// Terminate tor.
	[self _terminateTor];
	
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
	
}

- (BOOL)isRunning
{
	__block BOOL result = NO;
	
	dispatch_sync(_localQueue, ^{
		result = _isRunning;
	});
	
	return result;
}



/*
** TCTorManager - Operations
*/
#pragma mark - TCTorManager - Operations

- (void)operationStageArchiveFile:(NSURL *)fileURL completionHandler:(void (^)(BOOL error))handler
{
	NSLog(@"Staging...");
	
	// Check parameters.
	if (!handler)
		handler = ^(BOOL error) { };
	
	if (!fileURL)
	{
		handler(YES);
		return;
	}
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Get target directory.
	NSString *torBinPath = [_configuration pathForDomain:TConfigPathDomainTorBinary];
	
	if ([torBinPath hasSuffix:@"/"])
		torBinPath = [torBinPath substringToIndex:([torBinPath length] - 1)];
	
	if (!torBinPath)
	{
		handler(YES);
		return;
	}
	
	// Create target directory.
	if ([fileManager createDirectoryAtPath:torBinPath withIntermediateDirectories:YES attributes:nil error:nil] == NO)
	{
		handler(YES);
		return;
	}
	
	// Copy tarball.
	NSString *newFilePath = [torBinPath stringByAppendingPathComponent:@"_temp.tgz"];
	
	[fileManager removeItemAtPath:newFilePath error:nil];
	
	if ([fileManager copyItemAtPath:[fileURL path] toPath:newFilePath error:nil] == NO)
	{
		handler(YES);
		return;
	}
	
	// Configure sandbox.
	NSMutableString *profile = [[NSMutableString alloc] init];
	
	[profile appendFormat:@"(version 1)"];
	[profile appendFormat:@"(deny default (with no-log))"];						// Deny all by default.
	[profile appendFormat:@"(allow process-fork process-exec)"];				// Allow fork-exec
	[profile appendFormat:@"(allow file-read* (subpath \"/usr/lib\"))"];		// Allow to read libs.
	[profile appendFormat:@"(allow file-read* (literal \"/usr/bin/tar\"))"];	// Allow to read tar (execute).
	[profile appendFormat:@"(allow file-read* (literal \"%@\"))", [newFilePath stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]]; // Allow to read the archive.
	[profile appendFormat:@"(allow file* (subpath \"%@\"))", [torBinPath stringByReplacingOccurrencesOfString:@"\"" withString:@"\\\""]];	// Allow to write result.
	
#if DEBUG
	[profile appendFormat:@"(allow file-read* (subpath \"/System/Library\"))"];	// Allow to read tar.
	[profile appendFormat:@"(allow file-read* (subpath \"/Applications\"))"];	// Allow to read tar.
#endif
	
	// Create & launch task.
	NSTask *task = [[NSTask alloc] init];
	
	[task setLaunchPath:@"/usr/bin/sandbox-exec"];
	[task setCurrentDirectoryPath:torBinPath];
	
	[task setArguments:@[ @"-p", profile, @"/usr/bin/tar", @"-x", @"-z", @"-f", [newFilePath lastPathComponent], @"--strip-components", @"1" ]];
	
	[task setStandardError:nil];
	[task setStandardOutput:nil];
	
	task.terminationHandler = ^(NSTask *aTask) {
		handler([aTask terminationStatus] != 0);
		[fileManager removeItemAtPath:newFilePath error:nil];
	};
	
	@try {
		[task launch];
	}
	@catch (NSException *exception) {
		handler(YES);
		[fileManager removeItemAtPath:newFilePath error:nil];
	}
}

- (void)operationCheckSignatureWithCompletionHandler:(void (^)(BOOL error))handler
{
	NSLog(@"Checking...");

	// Check parameters.
	if (!handler)
		handler = ^(BOOL error) { };
	
	// Get tor path.
	NSString *torBinPath = [_configuration pathForDomain:TConfigPathDomainTorBinary];
	
	if (!torBinPath)
	{
		handler(YES);
		return;
	}
	
	// Build paths.
	NSString *signaturePath = [torBinPath stringByAppendingPathComponent:TCTorManagerFileSignature];
	NSString *binariesPath = [torBinPath stringByAppendingPathComponent:TCTorManagerFileBinaries];
	NSString *infoPath = [torBinPath stringByAppendingPathComponent:TCTorManagerFileInfo];
	
	// Read signature.
	NSData *data = [NSData dataWithContentsOfFile:signaturePath];
	
	if (!data)
	{
		handler(YES);
		return;
	}
	
	// Check signature.
	NSData *publicKey = [[NSData alloc] initWithBytesNoCopy:(void *)kPublicKey length:sizeof(kPublicKey) freeWhenDone:NO];
	
	if ([TCFileSignature validateSignature:data forContentsOfURL:[NSURL fileURLWithPath:infoPath] withPublicKey:publicKey] == NO)
	{
		handler(YES);
		return;
	}
	
	// Read info.plist.
	NSData			*infoData = [NSData dataWithContentsOfFile:infoPath];
	NSDictionary	*info = [NSPropertyListSerialization propertyListWithData:infoData options:NSPropertyListImmutable format:nil error:nil];
	
	if (!infoData)
	{
		handler(YES);
		return;
	}
	
	// Check files hash.
	NSDictionary *files = info[TCTorManagerKeyFiles];
	
	for (NSString *file in files)
	{
		NSString		*filePath = [binariesPath stringByAppendingPathComponent:file];
		NSDictionary	*fileInfo = files[file];
		NSData			*infoHash = fileInfo[TCTorManagerKeyHash];
		NSData			*diskHash = file_sha1([NSURL fileURLWithPath:filePath]);
		
		if (!diskHash || [infoHash isEqualToData:diskHash] == NO)
		{
			handler(YES);
			return;
		}
	}
	
	// Finish.
	handler(NO);
}

- (void)operationLaunchTor:(void (^)(BOOL error))handler
{
	NSLog(@"Launching...");

	NSString	*torPath = [_configuration pathForDomain:TConfigPathDomainTorBinary];
	NSString	*dataPath = [_configuration pathForDomain:TConfigPathDomainTorData];
	NSString	*identityPath = [_configuration pathForDomain:TConfigPathDomainTorIdentity];
	
	// Check conversion.
	if (!torPath || !dataPath || !identityPath)
	{
		[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_err_build_path"];
		[self sendEvent:TCTorManagerEventError context:nil];
		return;
	}
	
	// Create directories.
	NSFileManager *mng = [NSFileManager defaultManager];
	
	[mng createDirectoryAtPath:dataPath withIntermediateDirectories:NO attributes:nil error:nil];
	[mng createDirectoryAtPath:identityPath withIntermediateDirectories:NO attributes:nil error:nil];
	
	// Create arguments.
	NSMutableArray	*args = [NSMutableArray array];
	
	[args addObject:@"--ClientOnly"];
	[args addObject:@"1"];
	
	[args addObject:@"--SocksPort"];
	[args addObject:[@([_configuration torPort]) stringValue]];
	
	[args addObject:@"--SocksListenAddress"];
	[args addObject:([_configuration torAddress] ?: @"localhost")];
	
	
	[args addObject:@"--DataDirectory"];
	[args addObject:dataPath];
	
	[args addObject:@"--HiddenServiceDir"];
	[args addObject:identityPath];
	
	[args addObject:@"--HiddenServicePort"];
	[args addObject:[NSString stringWithFormat:@"11009 127.0.0.1:%u", [_configuration clientPort]]];
	
	
	// Build & handle pipe for 'tor' task.
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
	
	// Build tor task.
	NSString *torExecPath = [[torPath stringByAppendingPathComponent:TCTorManagerFileBinaries] stringByAppendingPathComponent:TCTorManagerFileTor];
	
	_task = [[NSTask alloc] init];
	
	[_task setLaunchPath:torExecPath];
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

- (void)_terminateTor
{
	// > localQueue <
	
	if (_task)
	{
		[_task terminate];
		
		[_task waitUntilExit];
		
		_task = nil;
	}
}

@end



/*
** C Tools
*/
#pragma mark - C Tools

NSData *file_sha1(NSURL *fileURL)
{
	if (!fileURL)
		return nil;
	
	// Declarations.
	NSData			*result = nil;
	CFReadStreamRef	readStream = NULL;
	SecTransformRef digestTransform = NULL;
	
	// Create read stream.
	readStream = CFReadStreamCreateWithFile(kCFAllocatorDefault, (__bridge CFURLRef)fileURL);
	
	if (!readStream)
		goto end;
	
	if (CFReadStreamOpen(readStream) != true)
		goto end;
	
	// Create digest transform.
	digestTransform = SecDigestTransformCreate(kSecDigestSHA1, 0, NULL);
	
	if (digestTransform == NULL)
		goto end;
	
	// Set digest input.
	SecTransformSetAttribute(digestTransform, kSecTransformInputAttributeName, readStream, NULL);
	
	// Execute.
	result = (__bridge_transfer NSData *)SecTransformExecute(digestTransform, NULL);
	
end:
	
	if (digestTransform)
		CFRelease(digestTransform);
	
	if (readStream)
	{
		CFReadStreamClose(readStream);
		CFRelease(readStream);
	}
	
	return result;
}
