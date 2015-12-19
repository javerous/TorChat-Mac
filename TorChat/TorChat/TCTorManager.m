/*
 *  TCTorManager.m
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



#include <signal.h>
#import <CommonCrypto/CommonCrypto.h>

#if defined(DEBUG) && DEBUG
# include <libproc.h>
#endif

#import "TCTorManager.h"

#import "TCLogsManager.h"

#import "TCConfigPlist.h"
#import "TCBuffer.h"
#import "TCOperationsQueue.h"

#import "TCPublicKey.h"
#import "TCFileSignature.h"
#import "TCDataSignature.h"

#import "TCInfo.h"



/*
** Defines
*/
#pragma mark - Defines

// Binary
#define TCTorManagerFileBinSignature	@"Signature"
#define TCTorManagerFileBinBinaries		@"Binaries"
#define TCTorManagerFileBinInfo			@"Info.plist"
#define TCTorManagerFileBinTor			@"tor"

#define TCTorManagerKeyInfoFiles		@"files"
#define TCTorManagerKeyInfoTorVersion	@"tor_version"
#define TCTorManagerKeyInfoHash			@"hash"

#define TCTorManagerKeyArchiveSize		@"size"
#define TCTorManagerKeyArchiveName		@"name"
#define TCTorManagerKeyArchiveVersion	@"version"
#define TCTorManagerKeyArchiveHash		@"hash"

// Identity
#define TCTorManagerFileIdentityHostname	@"hostname"
#define TCTorManagerFileIdentityPrivate		@"private_key"

// Context
#define TCTorManagerBaseUpdateURL			@"http://www.sourcemac.com/tor/%@"
#define TCTorManagerInfoUpdateURL			@"http://www.sourcemac.com/tor/info.plist"
#define TCTorManagerInfoSignatureUpdateURL	@"http://www.sourcemac.com/tor/info.plist.sig"



/*
** Prototypes
*/
#pragma mark - Prototypes

NSData	*file_sha1(NSURL *fileURL);
BOOL	version_greater(NSString *baseVersion, NSString *newVersion);



/*
** TCTorDownloadContext - Interface
*/
#pragma mark - TCTorDownloadContext - Interface

@interface TCTorDownloadContext : NSObject
{
	FILE		*_file;
	NSUInteger	_bytesDownloaded;
	CC_SHA1_CTX	_sha1;
}

// -- Instance --
- (id)initWithPath:(NSString *)path;

// -- Methods --
- (void)handleData:(NSData *)data;
- (void)handleComplete:(NSError *)error;

- (NSData *)sha1;

- (void)close;

// -- Properties --
@property (strong, nonatomic) void (^updateHandler) (TCTorDownloadContext *context, NSUInteger bytesDownloaded, BOOL complete, NSError *error);

@end



/*
** TCTorManager - Private
*/
#pragma mark - TCTorManager - Private

@interface TCTorManager () <NSURLSessionDelegate>
{
	dispatch_queue_t	_localQueue;
	dispatch_queue_t	_eventQueue;
	
	TCOperationsQueue	*_opQueue;

	dispatch_source_t	_testTimer;
	
	dispatch_source_t	_termSource;
	
	id <TCConfig>		_configuration;
	
	NSURLSession		*_torURLSession;
	
	NSMutableDictionary	*_torDownloadContexts;
	
	BOOL				_isStarted;
    BOOL				_isRunning;
	
	NSTask				*_task;
	
	NSFileHandle		*_errHandle;
	NSFileHandle		*_outHandle;
	
	NSString			*_hidden;
	
	id <NSObject>		_terminationObserver;
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
		
		// Operations queue.
		_opQueue = [[TCOperationsQueue alloc] initStarted];

		// Containers.
		_torDownloadContexts = [[NSMutableDictionary alloc] init];
		
		// Handle configuration.
		_configuration = configuration;
#warning Add observer for tor paths, so we can move datas.
		
		// Handle application standard termination.
		_terminationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
			[self _terminateTor];
		}];
		
		// SIGTERM handle.
		signal(SIGTERM, SIG_IGN);

		_termSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, _localQueue);
		
		dispatch_source_set_event_handler(_termSource, ^{
			[self _terminateTor];
			exit(0);
		});
		
		dispatch_resume(_termSource);
	}
    
    return self;
}

- (void)dealloc
{
	// Stop notification.
	[[NSNotificationCenter defaultCenter] removeObserver:_terminationObserver];
		
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
** TCTorManager - Life
*/
#pragma mark - TCTorManager - Life

- (void)startWithHandler:(void (^)(TCInfo *info))handler
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
					_isRunning = YES;
					free(pids);
					return;
				}
			}

		}

		free(pids);
	}
#endif
	
	if (!handler)
		handler = ^(TCInfo *error) { };
	
	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
		
		TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];

		// -- Initial check --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check status.
			if (_isStarted || _isRunning)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartAlreadyRunning]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Mark as started.
			_isStarted = YES;
			
			// Stop if running.
			[self _stop];
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];

		// -- Stage archive --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			// Check that the binary is already there.
			NSFileManager	*manager = [NSFileManager defaultManager];
			NSString		*path = [_configuration pathForComponent:TConfigPathComponentTorBinary fullPath:YES];
			
			path = [[path stringByAppendingPathComponent:TCTorManagerFileBinBinaries] stringByAppendingPathComponent:TCTorManagerFileBinTor];
			
			if ([manager fileExistsAtPath:path] == YES)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Stage the archive.
			NSURL *archiveUrl = [[NSBundle mainBundle] URLForResource:@"tor" withExtension:@"tgz"];
			
			NSLog(@"Staging...");
			
			[self operationStageArchiveFile:archiveUrl completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartUnarchive info:info]);
					ctrl(TCOperationsControlFinish);
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Check signature --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			NSLog(@"Signature...");
			
			[self operationCheckSignatureWithCompletionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartSignature info:info]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Launch binary --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			NSLog(@"Launching...");
			
			[self operationLaunchTor:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartLaunch info:info]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Wait hostname --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			NSLog(@"Wait hostname...");
			
			// Get the hostname file path.
			NSString *htnamePath = [[_configuration pathForComponent:TConfigPathComponentTorIdentity fullPath:YES] stringByAppendingPathComponent:TCTorManagerFileIdentityHostname];
			
			if (!htnamePath)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartConfiguration]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Wait for file appearance.
			_testTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
			
			dispatch_source_set_timer(_testTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0);
			
			dispatch_source_set_event_handler(_testTimer, ^{
				
				// > Try to read file.
				NSString *hostname = [NSString stringWithContentsOfFile:htnamePath encoding:NSASCIIStringEncoding error:nil];
				
				if (!hostname)
					return;
				
				// > Extract first part.
				NSRange rg = [hostname rangeOfString:@".onion"];
				
				if (rg.location == NSNotFound)
					return;
				
				_hidden = [hostname substringToIndex:rg.location];
				
				// > Set the address in the config
				[_configuration setSelfAddress:_hidden];
				
				// > Stop ourself.
				dispatch_source_cancel(_testTimer);
				_testTimer = nil;
				
				// Inform of the change.
				_isRunning = YES;
				
				handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartHostname context:_hidden]);
				handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartDone]);
			});
			
			// Start timer
			dispatch_resume(_testTimer);
			
			// Don't wait for the end of this.
			ctrl(TCOperationsControlContinue);
		}];

		// -- Finish --
		queue.finishHandler = ^{
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[queue start];
	}];
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
** TCTorManager - Update
*/
#pragma mark - TCTorManager - Update

- (void)checkForUpdateWithCompletionHandler:(void (^)(TCInfo *error))handler
{
	if (!handler)
		return;
	
	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
		
		TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
		
		// -- Check that we are running --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			if (!_isRunning)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorCheckUpdateTorNotRunning]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Retrieve remote info --
		__block NSString *remoteVersion = nil;
		
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			[self operationRetrieveRemoteInfoWithCompletionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorCheckUpdateRemoteInfo info:info]);
					ctrl(TCOperationsControlFinish);
				}
				if (info.code == TCTorManagerEventInfo)
				{
					if (info.code == TCTorManagerEventInfo)
					{
						NSDictionary *remoteInfo = info.context;
						
						remoteVersion = remoteInfo[TCTorManagerKeyArchiveVersion];
						
						ctrl(TCOperationsControlContinue);
					}
				}
			}];
		}];
		
		// -- Check local signature --
		__block NSString *localVersion = nil;
		
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			[self operationCheckSignatureWithCompletionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorCheckUpdateLocalSignature info:info]);
					ctrl(TCOperationsControlFinish);
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventInfo)
					{
						localVersion = ((NSDictionary *)info.context)[TCTorManagerKeyInfoTorVersion];
					}
					else if (info.code == TCTorManagerEventDone)
					{
						ctrl(TCOperationsControlContinue);
					}
				}
			}];
		}];
		
		// -- Compare versions --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			
			if (version_greater(localVersion, remoteVersion))
			{
				NSDictionary *context = @{ @"old_version" : localVersion, @"new_version" : remoteVersion };
				
				handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerEventCheckUpdateAvailable context:context]);
			}
			else
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorCheckUpdateNothingNew]);
			
			ctrl(TCOperationsControlFinish);
		}];
		
		queue.finishHandler = ^{
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[queue start];
	}];
}

- (dispatch_block_t)updateWithEventHandler:(void (^)(TCInfo *info))handler
{
	if (!handler)
		handler = ^(TCInfo *info){ };
	
	__block dispatch_block_t	currentBlock = NULL;
	__block BOOL				cancelled = NO;
	
	dispatch_block_t cancelBlock = ^{
		NSLog(@"Cancel <updateWithEventHandler>");
		
		dispatch_async(_localQueue, ^{
			
			if (cancelled)
				return;
			
			cancelled = YES;
			
			if (currentBlock)
				currentBlock();
		});
	};
	
	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
	
		TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
		
		// -- Check that we are running --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			if (!_isRunning)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateTorNotRunning]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Retrieve remote info --
		__block NSString	*remoteName = nil;
		__block NSData		*remoteHash = nil;
		__block NSNumber	*remoteSize = nil;
		
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			dispatch_block_t opCancel;
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}

			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveInfoRetrieving]);
	
			// Retrieve remote informations.
			opCancel = [self operationRetrieveRemoteInfoWithCompletionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateArchiveInfo info:info]);
					ctrl(TCOperationsControlFinish);
				}
				if (info.code == TCTorManagerEventInfo)
				{
					if (info.code == TCTorManagerEventInfo)
					{
						NSDictionary *remoteInfo = info.context;
						
						remoteName = remoteInfo[TCTorManagerKeyArchiveName];
						remoteHash = remoteInfo[TCTorManagerKeyArchiveHash];
						remoteSize = remoteInfo[TCTorManagerKeyArchiveSize];
						
						ctrl(TCOperationsControlContinue);
					}
				}
			}];
			
			// Update current cancellation block.
			currentBlock = ^{
				NSLog(@"Cancel <retrieve remote info>");
				opCancel();
				ctrl(TCOperationsControlFinish);
			};
		}];
		
		// -- Retrieve remote archive --
		NSString *downloadPath = [[_configuration pathForComponent:TConfigPathComponentDownloads fullPath:YES] stringByAppendingPathComponent:@"_update"];
		NSString *downloadArchivePath = [downloadPath stringByAppendingPathComponent:@"tor.tgz"];
		
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Create task.
			NSString				*urlString = [NSString stringWithFormat:TCTorManagerBaseUpdateURL, remoteName];
			NSURLSessionDataTask	*task = [[self _torURLSession] dataTaskWithURL:[NSURL URLWithString:urlString]];
			
			// Get download path.
			if (!downloadPath)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateConfiguration]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Create context.
			TCTorDownloadContext *context = [[TCTorDownloadContext alloc] initWithPath:downloadArchivePath];
			
			if (!context)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateInternal]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			context.updateHandler = ^(TCTorDownloadContext *aContext, NSUInteger bytesDownloaded, BOOL complete, NSError *error) {
				
				// > Handle complete.
				if (complete || bytesDownloaded > [remoteSize unsignedIntegerValue])
				{
					if (complete)
					{
						if (error)
						{
							handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateArchiveDownload context:error]);
							ctrl(TCOperationsControlFinish);
							return;
						}
					}
					else
					{
						[task cancel];
						[aContext close];
					}
					
					// > Remove context.
					dispatch_async(_localQueue, ^{
						[_torDownloadContexts removeObjectForKey:@(task.taskIdentifier)];
					});
					
					// > Check hash.
					if ([[aContext sha1] isEqualToData:remoteHash] == NO)
					{
						handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateArchiveDownload context:error]);
						ctrl(TCOperationsControlFinish);
						return;
					}
					
					// > Continue.
					ctrl(TCOperationsControlContinue);
				}
				else
					handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveDownloading context:@(bytesDownloaded)]);
			};
			
			// Handle context.
			[_torDownloadContexts setObject:context forKey:@(task.taskIdentifier)];
			
			// Resume task.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveSize context:remoteSize]);
			
			[task resume];
			
			// Update current cancellation block.
			currentBlock = ^{
				NSLog(@"Cancel 2");
				[task cancel];
				ctrl(TCOperationsControlFinish);
			};
		}];
		
		// -- Stop tor --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Stop tor.
			[self _stop];
			
			// Continue steps.
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Stage archive --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveStage]);
			
			// Stage file.
			[self operationStageArchiveFile:[NSURL fileURLWithPath:downloadArchivePath] completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateArchiveStage]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Check signature --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateSignatureCheck]);
			
			// Check signature.
			[self operationCheckSignatureWithCompletionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorSignature info:info]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Launch binary --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateRelaunch]);
			
			// Launch tor.
			[self operationLaunchTor:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateRelaunch info:info]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Done --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Check cancel state.
			if (cancelled)
			{
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateDone]);
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Finish --
		queue.finishHandler = ^{
			if (downloadPath)
				[[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
			
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[queue start];
	}];
	
	return cancelBlock;
}



/*
** TCTorManager - Operations
*/
#pragma mark - TCTorManager - Operations

- (dispatch_block_t)operationRetrieveRemoteInfoWithCompletionHandler:(void (^)(TCInfo *info))handler
{
	if (!handler)
		return NULL;
	
	__block dispatch_block_t	currentBlock = NULL;
	__block BOOL				cancelled = NO;
	
	dispatch_block_t cancelBlock = ^{
		NSLog(@"Cancel <operationRetrieveRemoteInfoWithCompletionHandler>");
		
		dispatch_async(_localQueue, ^{
			
			if (cancelled)
				return;
			
			cancelled = YES;
			
			if (currentBlock)
				currentBlock();
		});
	};
	
	TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
	
	// -- Get remote info --
	__block NSData	*remoteInfoData = nil;
	
	[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
		
		// Check cancellation.
		if (cancelled)
		{
			ctrl(TCOperationsControlFinish);
			return;
		}
		
		// Create task.
		NSURL					*url = [NSURL URLWithString:TCTorManagerInfoUpdateURL];
		NSURLSessionDataTask	*task;
		
		task = [[self _torURLSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {

			// Check error.
			if (error)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorNetwork context:error]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Hold data.
			remoteInfoData = data;
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
		
		// Resume task.
		[task resume];
		
		// Cancellation block.
		currentBlock = ^{
			[task cancel];
			ctrl(TCOperationsControlFinish);
		};
	}];
	
	// -- Get signature, check it & parse plist --
	__block NSDictionary *remoteInfo = nil;
	
	[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
		
		// Check cancellation.
		if (cancelled)
		{
			ctrl(TCOperationsControlFinish);
			return;
		}
		
		// Create task.
		NSURL					*url = [NSURL URLWithString:TCTorManagerInfoSignatureUpdateURL];
		NSURLSessionDataTask	*task;
		
		task = [[self _torURLSession] dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			
			// Check error.
			if (error)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorNetwork context:error]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Check content.
			NSData *publicKey = [[NSData alloc] initWithBytesNoCopy:(void *)kPublicKey length:sizeof(kPublicKey) freeWhenDone:NO];
			
			if ([TCDataSignature validateSignature:data forData:remoteInfoData withPublicKey:publicKey] == NO)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorSignature context:error]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Parse content.
			NSError *pError = nil;
			
			remoteInfo = [NSPropertyListSerialization propertyListWithData:remoteInfoData options:NSPropertyListImmutable format:nil error:&pError];
			
			if (!remoteInfo)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorInternal context:pError]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Give result.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventInfo context:remoteInfo]);
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventDone context:remoteInfo]);
		}];
		
		// Resume task.
		[task resume];
		
		// Cancellation block.
		currentBlock = ^{
			[task cancel];
			ctrl(TCOperationsControlFinish);
		};
	}];
	
	// Queue start.
	[queue start];
	
	return cancelBlock;
}



- (void)operationStageArchiveFile:(NSURL *)fileURL completionHandler:(void (^)(TCInfo *info))handler
{
	// Check parameters.
	if (!handler)
		handler = ^(TCInfo *error) { };
	
	if (!fileURL)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorInternal]);
		return;
	}
	
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	// Get target directory.
	NSString *torBinPath = [_configuration pathForComponent:TConfigPathComponentTorBinary fullPath:YES];
	
	if ([torBinPath hasSuffix:@"/"])
		torBinPath = [torBinPath substringToIndex:([torBinPath length] - 1)];
	
	if (!torBinPath)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorIO]);
		return;
	}
	
	// Create target directory.
	if ([fileManager createDirectoryAtPath:torBinPath withIntermediateDirectories:YES attributes:nil error:nil] == NO)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorConfiguration]);
		return;
	}
	
	// Copy tarball.
	NSString *newFilePath = [torBinPath stringByAppendingPathComponent:@"_temp.tgz"];
	
	[fileManager removeItemAtPath:newFilePath error:nil];
	
	if ([fileManager copyItemAtPath:[fileURL path] toPath:newFilePath error:nil] == NO)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorIO]);
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
	[profile appendFormat:@"(allow file-read* (subpath \"/System/Library\"))"];	// Allow to read system things.
	[profile appendFormat:@"(allow file-read* (subpath \"/Applications\"))"];	// Allow to read Applications.
#endif
	
	// Create & launch task.
	NSTask *task = [[NSTask alloc] init];
	
	[task setLaunchPath:@"/usr/bin/sandbox-exec"];
	[task setCurrentDirectoryPath:torBinPath];
	
	[task setArguments:@[ @"-p", profile, @"/usr/bin/tar", @"-x", @"-z", @"-f", [newFilePath lastPathComponent], @"--strip-components", @"1" ]];
	
	[task setStandardError:nil];
	[task setStandardOutput:nil];
	
	task.terminationHandler = ^(NSTask *aTask) {
		
		if ([aTask terminationStatus] != 0)
			handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorExtract context:@([aTask terminationStatus])]);
		else
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventDone]);
		
		[fileManager removeItemAtPath:newFilePath error:nil];
	};
	
	@try {
		[task launch];
	}
	@catch (NSException *exception) {
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorExtract context:@(-1)]);
		[fileManager removeItemAtPath:newFilePath error:nil];
	}
}

- (void)operationCheckSignatureWithCompletionHandler:(void (^)(TCInfo *info))handler
{
	// Check parameters.
	if (!handler)
		handler = ^(TCInfo *info) { };
	
	// Get tor path.
	NSString *torBinPath = [_configuration pathForComponent:TConfigPathComponentTorBinary fullPath:YES];
	
	if (!torBinPath)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorConfiguration]);
		return;
	}
	
	// Build paths.
	NSString *signaturePath = [torBinPath stringByAppendingPathComponent:TCTorManagerFileBinSignature];
	NSString *binariesPath = [torBinPath stringByAppendingPathComponent:TCTorManagerFileBinBinaries];
	NSString *infoPath = [torBinPath stringByAppendingPathComponent:TCTorManagerFileBinInfo];
	
	// Read signature.
	NSData *data = [NSData dataWithContentsOfFile:signaturePath];
	
	if (!data)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorIO]);
		return;
	}
	
	// Check signature.
	NSData *publicKey = [[NSData alloc] initWithBytesNoCopy:(void *)kPublicKey length:sizeof(kPublicKey) freeWhenDone:NO];
	
	if ([TCFileSignature validateSignature:data forContentsOfURL:[NSURL fileURLWithPath:infoPath] withPublicKey:publicKey] == NO)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorSignature context:infoPath]);
		return;
	}
	
	// Read info.plist.
	NSData			*infoData = [NSData dataWithContentsOfFile:infoPath];
	NSDictionary	*info = [NSPropertyListSerialization propertyListWithData:infoData options:NSPropertyListImmutable format:nil error:nil];
	
	if (!info)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorIO]);
		return;
	}
	
	// Give info.
	handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventInfo context:info]);
	
	// Check files hash.
	NSDictionary *files = info[TCTorManagerKeyInfoFiles];
	
	for (NSString *file in files)
	{
		NSString		*filePath = [binariesPath stringByAppendingPathComponent:file];
		NSDictionary	*fileInfo = files[file];
		NSData			*infoHash = fileInfo[TCTorManagerKeyInfoHash];
		NSData			*diskHash = file_sha1([NSURL fileURLWithPath:filePath]);
		
		if (!diskHash || [infoHash isEqualToData:diskHash] == NO)
		{
			handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorSignature context:filePath]);
			return;
		}
	}
	
	// Finish.
	handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventDone]);
}

- (void)operationLaunchTor:(void (^)(TCInfo *info))handler
{
	if (!handler)
		handler = ^(TCInfo *info) { };
	
	NSString	*torPath = [_configuration pathForComponent:TConfigPathComponentTorBinary fullPath:YES];
	NSString	*dataPath = [_configuration pathForComponent:TConfigPathComponentTorData fullPath:YES];
	NSString	*identityPath = [_configuration pathForComponent:TConfigPathComponentTorIdentity fullPath:YES];
	
	// Check conversion.
	if (!torPath || !dataPath || !identityPath)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorConfiguration]);
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
	__weak TCTorManager *weakSelf = self;
	
	_errHandle = [errPipe fileHandleForReading];
	_outHandle = [outPipe fileHandleForReading];
	
	_errHandle.readabilityHandler = ^(NSFileHandle *handle) {
		
		NSData			*data;
		TCTorManager	*wSelf = weakSelf;
		
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
				
				[wSelf sendLog:string kind:TCTorManagerLogError];
			}
		});
	};
	
	_outHandle.readabilityHandler = ^(NSFileHandle *handle) {
		
		NSData			*data;
		TCTorManager	*wSelf = weakSelf;
		
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
				
				[wSelf sendLog:string kind:TCTorManagerLogStandard];
			}
		});
	};
	
	// Build tor task.
	NSString *torExecPath = [[torPath stringByAppendingPathComponent:TCTorManagerFileBinBinaries] stringByAppendingPathComponent:TCTorManagerFileBinTor];
	
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
#warning FIXME: log in handler
		//_logHandler();
		//[[TCLogsManager sharedManager] addGlobalLogEntry:@"tor_error_launch"];
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorTor context:@(-1)]);
		return;
	}
	
	// Notify the launch.
	handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventDone]);
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

- (void)sendLog:(NSString *)log kind:(TCTorManagerLogKind)kind
{
	if ([log length] == 0)
		return;
	
	dispatch_async(_eventQueue, ^{
		
		void (^logHandler)(TCTorManagerLogKind kind, NSString *log) = _logHandler;
		
		if (!logHandler)
			return;
		
		logHandler(kind, log);
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

- (NSURLSession *)torURLSession
{
	__block NSURLSession *result = nil;
	
	dispatch_sync(_localQueue, ^{
		result = [self _torURLSession];
	});
	
	return result;
}

- (NSURLSession *)_torURLSession
{
	// > localQueue <
	
	if (_torURLSession)
		return _torURLSession;
	
	// Create session configuration, and setup it to use tor.
	NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
	
	sessionConfiguration.connectionProxyDictionary =  @{ (NSString *)kCFStreamPropertySOCKSProxyHost : ([_configuration torAddress] ?: @"localhost"),
														 (NSString *)kCFStreamPropertySOCKSProxyPort : @([_configuration torPort]) };
	
	_torURLSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
	
	return _torURLSession;
}



/*
** TCTorManager - NSURLSession
*/
#pragma mark - TCTorManager - NSURLSession

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
	dispatch_async(_localQueue, ^{
		
		// Get context.
		TCTorDownloadContext *context = _torDownloadContexts[@(dataTask.taskIdentifier)];
		
		if (!context)
			return;
	
		// Handle data.
		[context handleData:data];
	});
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
	dispatch_async(_localQueue, ^{
		
		// Get context.
		TCTorDownloadContext *context = _torDownloadContexts[@(task.taskIdentifier)];
		
		if (!context)
			return;
		
		// Handle complete.
		[context handleComplete:error];
	});
}

@end



/*
** TCTorDownloadContext
*/
#pragma mark - TCTorDownloadContext

@implementation TCTorDownloadContext

- (id)initWithPath:(NSString *)path
{
	self = [super init];
	
	if (self)
	{
		if (!path)
			return nil;
		
		// Create directory.
		[[NSFileManager defaultManager] createDirectoryAtPath:[path stringByDeletingLastPathComponent] withIntermediateDirectories:YES attributes:nil error:nil];
		
		// Create file.
		_file = fopen([path fileSystemRepresentation], "w");
		
		if (!_file)
			return nil;
		
		// Init sha1.
		CC_SHA1_Init(&_sha1);
	}
	
	return self;
}

- (void)dealloc
{
	[self close];
}

- (void)handleData:(NSData *)data
{
	if ([data length] == 0)
		return;
	
	// Write data.
	if (_file)
	{
		if (fwrite([data bytes], [data length], 1, _file) == 1)
		{
			CC_SHA1_Update(&_sha1, [data bytes], (CC_LONG)[data length]);
		}
	}
	
	// Update count.
	_bytesDownloaded += [data length];
	
	// Call handler.
	if (_updateHandler)
		_updateHandler(self, _bytesDownloaded, NO, nil);
}

- (void)handleComplete:(NSError *)error
{
	[self close];
	
	if (_updateHandler)
		_updateHandler(self, _bytesDownloaded, YES, error);
}

- (NSData *)sha1
{
	NSMutableData *result = [[NSMutableData alloc] initWithLength:CC_SHA1_DIGEST_LENGTH];
	
	CC_SHA1_Final([result mutableBytes], &_sha1);
	
	return result;
}

- (void)close
{
	if (!_file)
		return;
	
	fclose(_file);
	_file = NULL;
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

BOOL version_greater(NSString *baseVersion, NSString *newVersion)
{
	if (!newVersion)
		return NO;
	
	if (!baseVersion)
		return YES;
	
	NSArray		*baseParts = [baseVersion componentsSeparatedByString:@"."];
	NSArray		*newParts = [newVersion componentsSeparatedByString:@"."];
	NSUInteger	count = MAX([baseParts count], [newParts count]);
	
	for (NSUInteger i = 0; i < count; i++)
	{
		NSUInteger baseValue = 0;
		NSUInteger newValue = 0;
		
		if (i < [baseParts count])
			baseValue = (NSUInteger)[baseParts[i] intValue];
		
		if (i < [newParts count])
			newValue = (NSUInteger)[newParts[i] intValue];
		
		if (newValue > baseValue)
			return YES;
		else if (newValue < baseValue)
			return NO;
	}
	
	return NO;
}
