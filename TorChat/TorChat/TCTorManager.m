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

#import "TCConfigPlist.h"
#import "TCBuffer.h"
#import "TCOperationsQueue.h"

#import "TCPublicKey.h"
#import "TCFileSignature.h"
#import "TCDataSignature.h"

#import "TCInfo.h"
#import "TCDebugLog.h"

#import "TCSocket.h"


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

// Control
#define TCTorManagerTorControlHostFile	@"tor_ctrl"

// Context
#define TCTorManagerBaseUpdateURL			@"http://www.sourcemac.com/tor/%@"
#define TCTorManagerInfoUpdateURL			@"http://www.sourcemac.com/tor/info.plist"
#define TCTorManagerInfoSignatureUpdateURL	@"http://www.sourcemac.com/tor/info.plist.sig"



/*
** Prototypes
*/
#pragma mark - Prototypes

// Digest.
static NSData *file_sha1(NSURL *fileURL);

static NSString *s2k_from_data(NSData *data, uint8_t iterations);

// Hexa.
static NSString *hexa_from_bytes(const uint8_t *bytes, size_t len);
static NSString *hexa_from_data(NSData *data);

// Version.
static BOOL	version_greater(NSString *baseVersion, NSString *newVersion);



/*
** Interfaces
*/
#pragma mark - Interface

#pragma mark TCTorDownloadContext

@interface TCTorDownloadContext : NSObject

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


#pragma mark TCTorTask

@interface TCTorTask : NSObject <NSURLSessionDelegate>

@property (strong, atomic) void (^logHandler)(TCTorManagerLogKind kind, NSString *log);

// -- Life --
- (void)startWithBinariesPath:(NSString *)torBinPath dataPath:(NSString *)torDataPath identityPath:(NSString *)torIdentityPath torPort:(uint16_t)torPort torAddress:(NSString *)torAddress clientPort:(uint16_t)clientPort logHandler:(void (^)(TCTorManagerLogKind kind, NSString *log))logHandler completionHandler:(void (^)(TCInfo *info))handler;
- (void)stopWithCompletionHandler:(dispatch_block_t)handler;

// -- Download Context --
- (void)addDownloadContext:(TCTorDownloadContext *)context forKey:(id <NSCopying>)key;
- (void)removeDownloadContextForKey:(id)key;

@end


#pragma mark TCTorControl

@interface TCTorControl : NSObject <TCSocketDelegate>

@property (strong, atomic) void (^serverEvent)(NSString *type, NSString *content);
@property (strong, atomic) void (^socketError)(TCInfo *info);

// -- Instance --
- (instancetype)initWithIP:(NSString *)ip port:(uint16_t)port;

// -- Life --
- (void)stop;

// -- Commands --
- (void)sendAuthenticationCommandWithKeyHexa:(NSString *)keyHexa resultHandler:(void (^)(BOOL success))handler;
- (void)sendGetInfoCommandWithInfo:(NSString *)info resultHandler:(void (^)(BOOL success, NSString *info))handler;
- (void)sendSetEventsCommandWithEvents:(NSString *)events resultHandler:(void (^)(BOOL success))handler;

// -- Helpers --
+ (NSDictionary *)parseNoticeBootstrap:(NSString *)line;

@end


#pragma mark TCTorOperations

@interface TCTorOperations : NSObject

+ (dispatch_block_t)operationRetrieveRemoteInfoWithURLSession:(NSURLSession *)urlSession completionHandler:(void (^)(TCInfo *info))handler;
+ (void)operationStageArchiveFile:(NSURL *)fileURL toTorBinariesPath:(NSString *)torBinPath completionHandler:(void (^)(TCInfo *info))handler;
+ (void)operationCheckSignatureWithTorBinariesPath:(NSString *)torBinPath completionHandler:(void (^)(TCInfo *info))handler;
+ (void)operationLaunchTorWithBinariesPath:(NSString *)torBinPath dataPath:(NSString *)torDataPath identityPath:(NSString *)torIdentityPath torPort:(uint16_t)torPort torAddress:(NSString *)torAddress clientPort:(uint16_t)clientPort logHandler:(void (^)(TCTorManagerLogKind kind, NSString *log))logHandler completionHandler:(void (^)(TCInfo *info, NSTask *task, NSString *ctrlKeyHexa))handler;

@end



/*
** TCTorManager
*/
#pragma mark - TCTorManager

@implementation TCTorManager
{
	// Queues.
	dispatch_queue_t	_localQueue;
	dispatch_queue_t	_eventQueue;
	
	id <TCConfig>		_configuration;
	
	dispatch_source_t	_termSource;
	
	TCOperationsQueue	*_opQueue;
	
	// Task.
	TCTorTask			*_torTask;
	
	// Termination.
	id <NSObject>		_terminationObserver;
	
	// URL Session.
	NSURLSession		*_urlSession;
	
	// Path change.
	NSString			*_torIdentityPath;
	NSString			*_torBinPath;
	NSString			*_torDataPath;
	
	id					_torIdentityPathObserver;
	id					_torBinPathObserver;
	id					_torDataPathObserver;
	
	NSMutableSet		*_torComponentChanges;
	
	dispatch_source_t	_torChangesTimer;
}


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
        _localQueue = dispatch_queue_create("com.torchat.app.tormanager.local", DISPATCH_QUEUE_SERIAL);
		_eventQueue = dispatch_queue_create("com.torchat.app.tormanager.event", DISPATCH_QUEUE_SERIAL);
		
		// Operations queue.
		_opQueue = [[TCOperationsQueue alloc] initStarted];
		
		// Handle configuration.
		_configuration = configuration;
		
		// Handle path change.
		__weak TCTorManager *weakSelf = self;
		
		_torComponentChanges = [[NSMutableSet alloc] init];
		
		_torIdentityPath = [configuration pathForComponent:TCConfigPathComponentTorIdentity fullPath:YES];
		_torBinPath = [configuration pathForComponent:TCConfigPathComponentTorBinary fullPath:YES];
		_torDataPath = [configuration pathForComponent:TCConfigPathComponentTorData fullPath:YES];
		
		_torIdentityPathObserver = [_configuration addPathObserverForComponent:TCConfigPathComponentTorIdentity queue:nil usingBlock:^{
			[weakSelf handleTorPathComponentChange:TCConfigPathComponentTorIdentity];
		}];
		
		_torBinPathObserver = [_configuration addPathObserverForComponent:TCConfigPathComponentTorBinary queue:nil usingBlock:^{
			[weakSelf handleTorPathComponentChange:TCConfigPathComponentTorBinary];
		}];
		
		_torDataPathObserver = [_configuration addPathObserverForComponent:TCConfigPathComponentTorData queue:nil usingBlock:^{
			[weakSelf handleTorPathComponentChange:TCConfigPathComponentTorData];
		}];
		
		
		// Handle application standard termination.
		_terminationObserver = [[NSNotificationCenter defaultCenter] addObserverForName:NSApplicationWillTerminateNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
			
			dispatch_semaphore_t semaphore = dispatch_semaphore_create(0);

			[self stopWithCompletionHandler:^{
				dispatch_semaphore_signal(semaphore);
			}];
			
			dispatch_semaphore_wait(semaphore, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC));
		}];
		
		// SIGTERM handle.
		signal(SIGTERM, SIG_IGN);

		_termSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_SIGNAL, SIGTERM, 0, _localQueue);
		
		dispatch_source_set_event_handler(_termSource, ^{
			
			[self stopWithCompletionHandler:^{
				exit(0);
			}];
		});
		
		dispatch_resume(_termSource);
	}
    
    return self;
}

- (void)dealloc
{
	// Stop notification.
	[[NSNotificationCenter defaultCenter] removeObserver:_terminationObserver];
	
	[_configuration removePathObserver:_torIdentityPathObserver];
	[_configuration removePathObserver:_torBinPathObserver];
	[_configuration removePathObserver:_torDataPathObserver];
}



/*
** TCTorManager - Life
*/
#pragma mark - TCTorManager - Life

- (void)startWithHandler:(void (^)(TCInfo *info))handler
{
	if (!handler)
		handler = ^(TCInfo *error) { };
	

	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
		
		TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
		
		// -- Stop current instance --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {
			[self stopWithCompletionHandler:^{
				ctrl(TCOperationsControlContinue);
			}];
		}];
		
		// -- Start new instance --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {

			uint16_t torPort = [_configuration torPort];
			NSString *torAddress = [_configuration torAddress];
			uint16_t clientPort = [_configuration clientPort];
			
			_torTask = [[TCTorTask alloc] init];
			
			[_torTask startWithBinariesPath:_torBinPath dataPath:_torDataPath identityPath:_torIdentityPath torPort:torPort torAddress:torAddress clientPort:clientPort logHandler:self.logHandler completionHandler:^(TCInfo *info) {
				
				switch (info.kind)
				{
					case TCInfoInfo:
					{
						switch ((TCTorManagerEventStart)(info.code))
						{
							case TCTorManagerEventStartHostname:
							{
								// Set the address in the config.
								[_configuration setSelfAddress:info.context];
								break;
							}
							
							case TCTorManagerEventStartURLSession:
							{
								dispatch_async(_localQueue, ^{
									_urlSession = info.context;
								});
								break;
							}
								
							case TCTorManagerEventStartDone:
							{
								ctrl(TCOperationsControlContinue);
								break;
							}
							
							default:
								break;
						}
						
						break;
					}
						
					case TCInfoWarning:
					{
						dispatch_async(_localQueue, ^{
							if (info.code == TCTorManagerWarningStartCanceled)
							{
								_torTask = nil;
								_urlSession = nil;
							}
						});
						
						ctrl(TCOperationsControlContinue);

						break;
					}
						
					case TCInfoError:
					{
						dispatch_async(_localQueue, ^{
							_torTask = nil;
							_urlSession = nil;
						});
						
						ctrl(TCOperationsControlContinue);
						break;
					}
				}
				
				handler(info);
			}];
		}];
		
		// -- Finish --
		queue.finishHandler = ^(BOOL canceled) {
			opCtrl(TCOperationsControlContinue);
		};
		
		// -- Start --
		[queue start];
	}];
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	if (!handler)
		handler = ^{ };
	
	dispatch_async(_localQueue, ^{
		
		TCTorTask *torTask = _torTask;
		
		if (torTask)
		{
			_torTask = nil;
			_urlSession = nil;

			[torTask stopWithCompletionHandler:^{
				handler();
			}];
		}
		else
			dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), handler);
	});
}



/*
** TCTorManager - Update
*/
#pragma mark - TCTorManager - Update

- (dispatch_block_t)checkForUpdateWithCompletionHandler:(void (^)(TCInfo *error))handler
{
	if (!handler)
		return NULL;
	
	TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];

	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
		
		// -- Check that we are running --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			if (!_torTask || !_urlSession)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorCheckUpdateTorNotRunning]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Retrieve remote info --
		__block NSString *remoteVersion = nil;
		
		[queue scheduleCancelableOnQueue:_localQueue block:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {

			dispatch_block_t cancelHandler;
			
			cancelHandler = [TCTorOperations operationRetrieveRemoteInfoWithURLSession:_urlSession completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorRetrieveRemoteInfo info:info]);
					ctrl(TCOperationsControlFinish);
				}
				if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationInfo)
					{
						NSDictionary *remoteInfo = info.context;
						
						remoteVersion = remoteInfo[TCTorManagerKeyArchiveVersion];
						
						ctrl(TCOperationsControlContinue);
					}
				}
			}];
			
			addCancelBlock(cancelHandler);
		}];
		
		// -- Check local signature --
		__block NSString *localVersion = nil;
		
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			[TCTorOperations operationCheckSignatureWithTorBinariesPath:_torBinPath completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoCheckUpdateDomain code:TCTorManagerErrorCheckUpdateLocalSignature info:info]);
					ctrl(TCOperationsControlFinish);
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationInfo)
					{
						localVersion = ((NSDictionary *)info.context)[TCTorManagerKeyInfoTorVersion];
					}
					else if (info.code == TCTorManagerEventOperationDone)
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
		
		// -- Finish --
		queue.finishHandler = ^(BOOL canceled) {
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[queue start];
	}];
	
	// Return cancel block.
	return ^{
		TCDebugLog(@"<cancel checkForUpdateWithCompletionHandler (global)>");
		[queue cancel];
	};
}

- (dispatch_block_t)updateWithEventHandler:(void (^)(TCInfo *info))handler
{
	TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
	
	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
	
		// -- Check that we are running --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			if (!_torTask || !_urlSession)
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
		
		[queue scheduleCancelableOnQueue:_localQueue block:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
			
			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveInfoRetrieving]);
	
			// Retrieve remote informations.
			dispatch_block_t opCancel;

			opCancel = [TCTorOperations operationRetrieveRemoteInfoWithURLSession:_urlSession completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateArchiveInfo info:info]);
					ctrl(TCOperationsControlFinish);
				}
				if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationInfo)
					{
						NSDictionary *remoteInfo = info.context;
						
						remoteName = remoteInfo[TCTorManagerKeyArchiveName];
						remoteHash = remoteInfo[TCTorManagerKeyArchiveHash];
						remoteSize = remoteInfo[TCTorManagerKeyArchiveSize];
						
						ctrl(TCOperationsControlContinue);
					}
				}
			}];
			
			// Add cancelation block.
			addCancelBlock(opCancel);
		}];
		
		// -- Retrieve remote archive --
		NSString *downloadPath = [[_configuration pathForComponent:TCConfigPathComponentDownloads fullPath:YES] stringByAppendingPathComponent:@"_update"];
		NSString *downloadArchivePath = [downloadPath stringByAppendingPathComponent:@"tor.tgz"];
		
		[queue scheduleCancelableOnQueue:_localQueue block:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {

			// Create task.
			NSString				*urlString = [NSString stringWithFormat:TCTorManagerBaseUpdateURL, remoteName];
			NSURLSessionDataTask	*task = [_urlSession dataTaskWithURL:[NSURL URLWithString:urlString]];
			
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
					[_torTask removeDownloadContextForKey:@(task.taskIdentifier)];
					
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
			[_torTask addDownloadContext:context forKey:@(task.taskIdentifier)];
			
			// Resume task.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveSize context:remoteSize]);
			
			[task resume];
			
			addCancelBlock(^{
				TCDebugLog(@"Cancel <retrieve remote archive>");
				[task cancel];
			});
		}];
		
		// -- Stop tor --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			[self stopWithCompletionHandler:^{
				ctrl(TCOperationsControlContinue);
			}];
		}];
		
		// -- Stage archive --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {

			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateArchiveStage]);
			
			// Stage file.
			[TCTorOperations operationStageArchiveFile:[NSURL fileURLWithPath:downloadArchivePath] toTorBinariesPath:_torBinPath completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateArchiveStage]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Check signature --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateSignatureCheck]);
			
			// Check signature.
			[TCTorOperations operationCheckSignatureWithTorBinariesPath:_torBinPath completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorCheckUpdateLocalSignature info:info]);
					ctrl(TCOperationsControlFinish);
					return;
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Launch binary --
		[queue scheduleCancelableOnQueue:_localQueue block:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
			
			uint16_t torPort = [_configuration torPort];
			NSString *torAddress = [_configuration torAddress];
			uint16_t clientPort = [_configuration clientPort];
			
			TCTorTask *torTask = [[TCTorTask alloc] init];
			
			[torTask startWithBinariesPath:_torBinPath dataPath:_torDataPath identityPath:_torIdentityPath torPort:torPort torAddress:torAddress clientPort:clientPort logHandler:self.logHandler completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventStartURLSession)
					{
						dispatch_async(_localQueue, ^{
							_urlSession = info.context;
						});
					}
					else if (info.code == TCTorManagerEventStartDone)
					{
						dispatch_async(_localQueue, ^{
							_torTask = torTask;
						});
						
						ctrl(TCOperationsControlContinue);
					}
				}
				else if (info.kind == TCInfoWarning)
				{
					if (info.code == TCTorManagerWarningStartCanceled)
					{
						handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateRelaunch info:info]);
						ctrl(TCOperationsControlFinish);
					}
				}
				else if (info.kind == TCInfoError)
				{
					handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoUpdateDomain code:TCTorManagerErrorUpdateRelaunch info:info]);
					ctrl(TCOperationsControlFinish);
					return;
				}
			}];
			
			addCancelBlock(^{ [torTask stopWithCompletionHandler:nil]; });
		}];
		
		// -- Done --
		[queue scheduleBlock:^(TCOperationsControl ctrl) {

			// Notify step.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoUpdateDomain code:TCTorManagerEventUpdateDone]);
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Finish --
		queue.finishHandler = ^(BOOL canceled){
			if (downloadPath)
				[[NSFileManager defaultManager] removeItemAtPath:downloadPath error:nil];
			
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[queue start];
	}];
	
	// Return cancel block.
	return ^{
		TCDebugLog(@"<cancel updateWithEventHandler (global)>");
		[queue cancel];
	};
}



/*
** TCTorManager - Path Change
*/
#pragma mark - TCTorManager - Path Change

- (void)handleTorPathComponentChange:(TCConfigPathComponent)pathComponent
{
	dispatch_async(_localQueue, ^{
		
		// Add component to list of update.
		[_torComponentChanges addObject:@(pathComponent)];
		
		// Lazily create timer.
		if (!_torChangesTimer)
		{
			_torChangesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
			
			dispatch_source_set_timer(_torChangesTimer, DISPATCH_TIME_FOREVER, 0, 0);

			dispatch_source_set_event_handler(_torChangesTimer, ^{
				dispatch_source_set_timer(_torChangesTimer, DISPATCH_TIME_FOREVER, 0, 0);
				
				if ([_torComponentChanges count] == 0)
					return;
				
				[self handleTorPathComponentsChange:[_torComponentChanges copy]];
				
				[_torComponentChanges removeAllObjects];
			});
			
			dispatch_resume(_torChangesTimer);
		}
		
		// Schedule a change.
		dispatch_source_set_timer(_torChangesTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 0, 1 * NSEC_PER_SEC);
	});
}

- (void)handleTorPathComponentsChange:(NSSet *)set
{
	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {

		TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
		
		TCDebugLog(@"Handle path change %@", set);
		
		// -- Stop Tor --
		__block BOOL needTorRelaunch = NO;
		
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			TCDebugLog(@" -> Stop tor %@.", _torTask);
			
			if (_torTask)
			{
				needTorRelaunch = YES;
				
				[_torTask stopWithCompletionHandler:^{
					ctrl(TCOperationsControlContinue);
				}];
			}
			else
				ctrl(TCOperationsControlContinue);
		}];
		
		// -- Move files --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			TCDebugLog(@" -> Move files.");

			for (NSNumber *item in set)
			{
				TCConfigPathComponent pathComponent = (TCConfigPathComponent)[item intValue];
				
				if (pathComponent == TCConfigPathComponentTorBinary)
					[self _moveTorBinaryFiles];
				else if (pathComponent == TCConfigPathComponentTorData)
					[self _moveTorDataFiles];
				else if (pathComponent == TCConfigPathComponentTorIdentity)
					[self _moveTorIdentityFiles];
			}
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Relaunch tor --
		[queue scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			if (!needTorRelaunch)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			TCDebugLog(@" -> Relaunch tor.");

			uint16_t torPort = [_configuration torPort];
			NSString *torAddress = [_configuration torAddress];
			uint16_t clientPort = [_configuration clientPort];
			
			TCTorTask *torTask = [[TCTorTask alloc] init];
			
			[torTask startWithBinariesPath:_torBinPath dataPath:_torDataPath identityPath:_torIdentityPath torPort:torPort torAddress:torAddress clientPort:clientPort logHandler:self.logHandler completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventStartURLSession)
					{
						dispatch_async(_localQueue, ^{
							_urlSession = info.context;
						});
					}
					else if (info.code == TCTorManagerEventStartDone)
					{
						dispatch_async(_localQueue, ^{
							_torTask = torTask;
						});
						
						ctrl(TCOperationsControlContinue);
					}
				}
				else if (info.kind == TCInfoWarning)
				{
					if (info.code == TCTorManagerWarningStartCanceled)
					{
						ctrl(TCOperationsControlFinish);
					}
				}
				else if (info.kind == TCInfoError)
				{
					NSLog(@"Error: Can't relaunch tor.");
					ctrl(TCOperationsControlFinish);
					return;
				}
			}];
		}];
		
		// -- Finish --
		queue.finishHandler = ^(BOOL canceled) {
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[queue start];
	}];
}

- (void)_moveTorBinaryFiles
{
	// > localQueue <
	
	TCDebugLog(@"~binPath - move files.");
	
	NSError *error = nil;
	
	// Check if we can / need a move.
	NSString *newPath = [_configuration pathForComponent:TCConfigPathComponentTorBinary fullPath:YES];
	
	if (!_torBinPath)
	{
		_torBinPath = newPath;
		return;
	}
	
	if ([_torBinPath isEqualToString:newPath])
		return;
	
	// Compose paths.
	NSString *oldPathSignature = [_torBinPath stringByAppendingPathComponent:TCTorManagerFileBinSignature];
	NSString *oldPathInfo = [_torBinPath stringByAppendingPathComponent:TCTorManagerFileBinInfo];
	NSString *oldPathBinaries = [_torBinPath stringByAppendingPathComponent:TCTorManagerFileBinBinaries];
	
	NSString *newPathSignature = [newPath stringByAppendingPathComponent:TCTorManagerFileBinSignature];
	NSString *newPathInfo = [newPath stringByAppendingPathComponent:TCTorManagerFileBinInfo];
	NSString *newPathBinaries = [newPath stringByAppendingPathComponent:TCTorManagerFileBinBinaries];
	
	// Create target directory.
	if ([[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&error] == NO)
	{
		if (error.domain != NSCocoaErrorDomain || error.code != NSFileWriteFileExistsError)
		{
			NSLog(@"Error: Can't create target directory (%@)", error);
			return;
		}
	}
	
	// Move paths.
	if ([[NSFileManager defaultManager] moveItemAtPath:oldPathSignature toPath:newPathSignature error:&error] == NO)
	{
		NSLog(@"Error: Can't move signature file (%@)", error);
		return;
	}
	
	if ([[NSFileManager defaultManager] moveItemAtPath:oldPathInfo toPath:newPathInfo error:&error] == NO)
	{
		NSLog(@"Error: Can't move info file (%@)", error);
		return;
	}
	
	if ([[NSFileManager defaultManager] moveItemAtPath:oldPathBinaries toPath:newPathBinaries error:&error] == NO)
	{
		NSLog(@"Error: Can't move binaries directory (%@)", error);
		return;
	}
	
	// Hold new path.
	_torBinPath = newPath;
	
	TCDebugLog(@"*** _torBinPath: %@", _torBinPath);
}

- (void)_moveTorDataFiles
{
	// > localQueue <

	TCDebugLog(@"~dataPath - move files.");

	NSError *error = nil;
	
	// Check if we can / need a move.
	NSString *newPath = [_configuration pathForComponent:TCConfigPathComponentTorData fullPath:YES];
	
	if (!_torDataPath)
	{
		_torDataPath = newPath;
		return;
	}
	
	if ([_torDataPath isEqualToString:newPath])
		return;
	
	// Create target directory.
	if ([[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&error] == NO)
	{
		if (error.domain != NSCocoaErrorDomain || error.code != NSFileWriteFileExistsError)
		{
			NSLog(@"Error: Can't create target directory (%@)", error);
			return;
		}
	}
	
	// Hold new path.
	_torDataPath = newPath;
	
	TCDebugLog(@"*** _torDataPath: %@", _torDataPath);
}

- (void)_moveTorIdentityFiles
{
	TCDebugLog(@"~identityPath - move files.");
	
	NSError *error = nil;
	
	// Check if we can / need a move.
	NSString *newPath = [_configuration pathForComponent:TCConfigPathComponentTorIdentity fullPath:YES];
	
	if (!_torIdentityPath)
	{
		_torIdentityPath = newPath;
		return;
	}
	
	if ([_torIdentityPath isEqualToString:newPath])
		return;
	
	// Compose paths.
	NSString *oldPathHostname = [_torIdentityPath stringByAppendingPathComponent:TCTorManagerFileIdentityHostname];
	NSString *oldPathPrivateKey = [_torIdentityPath stringByAppendingPathComponent:TCTorManagerFileIdentityPrivate];
	
	NSString *newPathHostname = [newPath stringByAppendingPathComponent:TCTorManagerFileIdentityHostname];
	NSString *newPathPrivateKey = [newPath stringByAppendingPathComponent:TCTorManagerFileIdentityPrivate];
	
	// Create target directory.
	if ([[NSFileManager defaultManager] createDirectoryAtPath:newPath withIntermediateDirectories:YES attributes:nil error:&error] == NO)
	{
		if (error.domain != NSCocoaErrorDomain || error.code != NSFileWriteFileExistsError)
		{
			NSLog(@"Error: Can't create target directory (%@)", error);
			return;
		}
	}
	
	// Move paths.
	if ([[NSFileManager defaultManager] moveItemAtPath:oldPathHostname toPath:newPathHostname error:&error] == NO)
	{
		NSLog(@"Error: Can't move identity file %@", error);
		return;
	}
	
	if ([[NSFileManager defaultManager] moveItemAtPath:oldPathPrivateKey toPath:newPathPrivateKey error:&error] == NO)
	{
		NSLog(@"Error: Can't move private-key file %@", error);
		return;
	}
	
	// Hold new path.
	_torIdentityPath = newPath;
	
	TCDebugLog(@"*** _torIdentityPath: %@", _torIdentityPath);
}

@end



/*
** TCTorTask
*/
#pragma mark - TCTorTask

@implementation TCTorTask
{
	TCOperationsQueue	*_opQueue;
	dispatch_queue_t	_localQueue;
	
	BOOL _isRunning;
	
	NSTask *_task;
	
	NSURLSession		*_torURLSession;
	NSMutableDictionary	*_torDownloadContexts;
	
	__weak TCOperationsQueue *_currentStartOperation;
}


/*
** TCTorTask - Instance
*/
#pragma mark - TCTorTask - Instance

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		// Queues.
		_localQueue = dispatch_queue_create("com.torchat.ui.tor-task.local", DISPATCH_QUEUE_SERIAL);
		_opQueue = [[TCOperationsQueue alloc] initStarted];
		
		// Containers.
		_torDownloadContexts = [[NSMutableDictionary alloc] init];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCTorTask dealloc");
}



/*
** TCTorTask - Life
*/
#pragma mark - TCTorTask - Life

- (void)startWithBinariesPath:(NSString *)torBinPath dataPath:(NSString *)torDataPath identityPath:(NSString *)torIdentityPath torPort:(uint16_t)torPort torAddress:(NSString *)torAddress clientPort:(uint16_t)clientPort logHandler:(void (^)(TCTorManagerLogKind kind, NSString *log))logHandler completionHandler:(void (^)(TCInfo *info))handler
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
					
					// Create URL session.
					NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
					
					sessionConfiguration.connectionProxyDictionary =  @{ (NSString *)kCFStreamPropertySOCKSProxyHost : (torAddress ?: @"localhost"),
																		 (NSString *)kCFStreamPropertySOCKSProxyPort : @(torPort) };
					
					_torURLSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
					
					// Give this session to caller.
					handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartURLSession context:_torURLSession]);
					
					// Say ready.
					handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartDone]);
					
					return;
				}
			}
		}
		
		free(pids);
	}
#endif
	
	
	[_opQueue scheduleBlock:^(TCOperationsControl opCtrl) {
		
		TCOperationsQueue	*operations = [[TCOperationsQueue alloc] init];
		__block TCInfo		*errorInfo = nil;
		
		// -- Stop if running --
		[operations scheduleOnQueue:_localQueue block:^(TCOperationsControl ctrl) {
			
			// Stop.
			if (_isRunning)
				[self _stop];
			
			_isRunning = YES;
			_currentStartOperation = operations;
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Stage archive --
		[operations scheduleBlock:^(TCOperationsControl ctrl) {
			
			// Check that the binary is already there.
			NSFileManager	*manager = [NSFileManager defaultManager];
			NSString		*path;
			
			path = [[torBinPath stringByAppendingPathComponent:TCTorManagerFileBinBinaries] stringByAppendingPathComponent:TCTorManagerFileBinTor];
			
			if ([manager fileExistsAtPath:path] == YES)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Stage the archive.
			NSURL *archiveUrl = [[NSBundle mainBundle] URLForResource:@"tor" withExtension:@"tgz"];
			
			[TCTorOperations operationStageArchiveFile:archiveUrl toTorBinariesPath:torBinPath completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartUnarchive info:info];
					ctrl(TCOperationsControlFinish);
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Check signature --
		[operations scheduleBlock:^(TCOperationsControl ctrl) {
			
			[TCTorOperations operationCheckSignatureWithTorBinariesPath:torBinPath completionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoError)
				{
					errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartSignature info:info];
					ctrl(TCOperationsControlFinish);
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationDone)
						ctrl(TCOperationsControlContinue);
				}
			}];
		}];
		
		// -- Launch binary --
		__block NSString *ctrlKeyHexa = nil;
		
		[operations scheduleBlock:^(TCOperationsControl ctrl) {
			
			[TCTorOperations operationLaunchTorWithBinariesPath:torBinPath	dataPath:torDataPath identityPath:torIdentityPath torPort:torPort torAddress:torAddress clientPort:clientPort logHandler:logHandler completionHandler:^(TCInfo *info, NSTask *task, NSString *aCtrlKeyHexa) {

				if (info.kind == TCInfoError)
				{
					errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartLaunch info:info];
					ctrl(TCOperationsControlFinish);
				}
				else if (info.kind == TCInfoInfo)
				{
					if (info.code == TCTorManagerEventOperationDone)
					{
						ctrlKeyHexa = aCtrlKeyHexa;
						
						dispatch_async(_localQueue, ^{
							_task = task;
						});
						
						ctrl(TCOperationsControlContinue);
					}
				}
			}];
		}];
		
		// -- Wait hostname --
		[operations scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {

			// Get the hostname file path.
			NSString *htnamePath = [torIdentityPath stringByAppendingPathComponent:TCTorManagerFileIdentityHostname];
			
			if (!htnamePath)
			{
				errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartConfiguration];
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Wait for file appearance.
			dispatch_source_t testTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
			
			dispatch_source_set_timer(testTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0);
			
			dispatch_source_set_event_handler(testTimer, ^{
				
				// Try to read file.
				NSString *hostname = [NSString stringWithContentsOfFile:htnamePath encoding:NSASCIIStringEncoding error:nil];
				
				if (!hostname)
					return;
				
				// Extract first part.
				NSRange rg = [hostname rangeOfString:@".onion"];
				
				if (rg.location == NSNotFound)
					return;
				
				NSString *hidden = [hostname substringToIndex:rg.location];
				
				// Flag as running.
				_isRunning = YES;
				
				// Stop ourself.
				dispatch_source_cancel(testTimer);
				
				// Notify user.
				handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartHostname context:hidden]);
				
				// Continue.
				ctrl(TCOperationsControlContinue);
			});
			
			// Start timer
			dispatch_resume(testTimer);
			
			// Set cancelation.
			addCancelBlock(^{
				TCDebugLog(@"<cancel startWithBinariesPath (Wait hostname)>");
				dispatch_source_cancel(testTimer);
			});
		}];
		
		// -- Wait control info --
		__block NSString *torCtrlAddress = nil;
		__block NSString *torCtrlPort = nil;

		[operations scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
			
			// Get the hostname file path.
			NSString *ctrlInfoPath = [torDataPath stringByAppendingPathComponent:TCTorManagerTorControlHostFile];
			
			if (!ctrlInfoPath)
			{
				errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartConfiguration];
				ctrl(TCOperationsControlFinish);
			}

			// Wait for file appearance.
			dispatch_source_t testTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
			
			dispatch_source_set_timer(testTimer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0);
			
			dispatch_source_set_event_handler(testTimer, ^{
				
				// Try to read file.
				NSString *ctrlInfo = [NSString stringWithContentsOfFile:ctrlInfoPath encoding:NSASCIIStringEncoding error:nil];
				
				if (!ctrlInfo)
					return;
				
				// Try to parse content.
				NSRegularExpression *regExp = [NSRegularExpression regularExpressionWithPattern:@"PORT[^=]*=[^0-9]*([0-9\\.]+):([0-9]+)" options:NSRegularExpressionCaseInsensitive error:nil];
				NSArray				*results = [regExp matchesInString:ctrlInfo options:0 range:NSMakeRange(0, ctrlInfo.length)];
				
				if (results == 0)
					return;
				
				// Remove info file once parsed.
				[[NSFileManager defaultManager] removeItemAtPath:ctrlInfoPath error:nil];
				
				// Extract infos.
				NSTextCheckingResult *result = results[0];
				
				if (result.numberOfRanges < 3)
					return;
				
				torCtrlAddress = [ctrlInfo substringWithRange:[result rangeAtIndex:1]];
				torCtrlPort = [ctrlInfo substringWithRange:[result rangeAtIndex:2]];

				// Stop ourself.
				dispatch_source_cancel(testTimer);
				
				// Continue.
				ctrl(TCOperationsControlContinue);
			});
			
			// Start timer
			dispatch_resume(testTimer);
			
			// Set cancelation.
			addCancelBlock(^{
				TCDebugLog(@"<cancel startWithBinariesPath (Wait control info)>");
				dispatch_source_cancel(testTimer);
			});
		}];
		
		// -- Create & authenticate control socket --
		__block TCTorControl *control;
		
		[operations scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
			
			// Connect control.
			control = [[TCTorControl alloc] initWithIP:torCtrlAddress port:(uint16_t)[torCtrlPort intValue]];
			
			if (!control)
			{
				errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartControlConnect];
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Authenticate control.
			[control sendAuthenticationCommandWithKeyHexa:ctrlKeyHexa resultHandler:^(BOOL success) {
				
				if (!success)
				{
					errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartControlAuthenticate];
					ctrl(TCOperationsControlFinish);
					return;
				}
				
				ctrl(TCOperationsControlContinue);
			}];
			
			// Set cancelation.
			addCancelBlock(^{
				TCDebugLog(@"<cancel startWithBinariesPath (Create & authenticate control socket)>");
				[control stop];
				control = nil;
			});
		}];
		
		// -- Wait for bootstrap completion --
		[operations scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {

			// Check that we have a control.
			if (!control)
			{
				errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartControlMonitor];
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Snippet to handle bootstrap status.
			__block NSNumber *lastProgress = nil;

			void (^handleNoticeBootstrap)(NSString *) = ^(NSString *content) {
				
				NSDictionary *bootstrap = [TCTorControl parseNoticeBootstrap:content];

				if (!bootstrap)
					return;

				NSNumber *progress = bootstrap[@"progress"];
				NSString *summary = bootstrap[@"summary"];
				NSString *tag = bootstrap[@"tag"];
				
				// Notify prrogress.
				if ([progress integerValue] > [lastProgress integerValue])
				{
					lastProgress = progress;
					handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartBootstrapping context:@{ @"progress" : progress, @"summary" : summary }]);
				}
				
				// Done.
				if ([tag isEqualToString:@"done"])
				{
					[control stop];
					control = nil;
					
					ctrl(TCOperationsControlContinue);
				}
			};
			
			// Handle server events.
			control.serverEvent = ^(NSString *type, NSString *content) {
				if ([type isEqualToString:@"STATUS_CLIENT"])
					handleNoticeBootstrap(content);
			};
			
			// Activate events.
			[control sendSetEventsCommandWithEvents:@"STATUS_CLIENT" resultHandler:^(BOOL success) {
				
				if (!success)
				{
					errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartControlMonitor];
					ctrl(TCOperationsControlFinish);
					return;
				}
			}];
			
			// Ask current status (because if we tor is already bootstrapped, we are not going to receive other bootstrap events).
			[control sendGetInfoCommandWithInfo:@"status/bootstrap-phase" resultHandler:^(BOOL success, NSString *info) {
				
				if (!success)
				{
					errorInfo = [TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoStartDomain code:TCTorManagerErrorStartControlMonitor];
					ctrl(TCOperationsControlFinish);
					return;
				}

				handleNoticeBootstrap(info);
			}];
			
			// Set cancelation.
			addCancelBlock(^{
				TCDebugLog(@"<cancel startWithBinariesPath (Wait for bootstrap completion)>");
				[control stop];
				control = nil;
			});
		}];
		
		// -- NSURLSession --
		[operations scheduleBlock:^(TCOperationsControl ctrl) {
			
			// Create session configuration, and setup it to use tor.
			NSURLSessionConfiguration *sessionConfiguration = [NSURLSessionConfiguration ephemeralSessionConfiguration];
			
			sessionConfiguration.connectionProxyDictionary =  @{ (NSString *)kCFStreamPropertySOCKSProxyHost : (torAddress ?: @"localhost"),
																 (NSString *)kCFStreamPropertySOCKSProxyPort : @(torPort) };
			
			NSURLSession *urlSession = [NSURLSession sessionWithConfiguration:sessionConfiguration delegate:self delegateQueue:nil];
			
			dispatch_async(_localQueue, ^{
				_torURLSession = urlSession;
			});
			
			// Give this session to caller.
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartURLSession context:urlSession]);
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
		
		
		// -- Finish --
		operations.finishHandler = ^(BOOL canceled){

			// Handle error & cancelation.
			if (errorInfo || canceled)
			{
				if (canceled)
					handler([TCInfo infoOfKind:TCInfoWarning domain:TCTorManagerInfoStartDomain code:TCTorManagerWarningStartCanceled]);
				else
					handler(errorInfo);
				
				// Clean created things.
				dispatch_async(_localQueue, ^{
					[_task terminate];
					_task = nil;
					
					_torURLSession = nil;
				});
			}
			else
			{
				// Notify finish.
				handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoStartDomain code:TCTorManagerEventStartDone]);
			}
			
			// Continue on next operation.
			opCtrl(TCOperationsControlContinue);
		};
		
		// Start.
		[operations start];
	}];
}

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	dispatch_async(_localQueue, ^{
		
		// Stop.
		[self _stop];
		
		// Wait for completion.
		if (handler)
		{
			[_opQueue scheduleBlock:^(TCOperationsControl ctrl) {
				handler();
				ctrl(TCOperationsControlContinue);
			}];
		}
	});
}

- (void)_stop
{
	// > localQueue <

	// Cancel any currently running operation.
	[_currentStartOperation cancel];
	_currentStartOperation = nil;
	
	// Terminate task.
	@try {
		[_task terminate];
		[_task waitUntilExit];
	} @catch (NSException *exception) {
		NSLog(@"Tor exception on terminate: %@", exception);
	}
	
	_task = nil;
	
	// Remove url session.
	[_torURLSession invalidateAndCancel];
	_torURLSession = nil;
	
	// Remove download contexts.
	[_torDownloadContexts removeAllObjects];
}



/*
** TCTorTask - NSURLSessionDelegate
*/
#pragma mark - TCTorTask - NSURLSessionDelegate

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



/*
** TCTorTask - Download Context
*/
#pragma mark - TCTorTask - Download Context

- (void)addDownloadContext:(TCTorDownloadContext *)context forKey:(id <NSCopying>)key
{
	if (!context || !key)
		return;
	
	dispatch_async(_localQueue, ^{
		_torDownloadContexts[key] = context;
	});
}

- (void)removeDownloadContextForKey:(id)key
{
	dispatch_async(_localQueue, ^{
		[_torDownloadContexts removeObjectForKey:key];
	});
}

@end



/*
** TCTorControl
*/
#pragma mark - TCTorControl

@implementation TCTorControl
{
	dispatch_queue_t _localQueue;
	
	TCSocket *_socket;
	
	NSMutableArray *_handlers;
	
	NSRegularExpression *_regexpEvent;
}


/*
** TCTorControl - Instance
*/
#pragma mark - TCTorControl - Instance

- (instancetype)initWithIP:(NSString *)ip port:(uint16_t)port
{
	self = [super init];
	
	if (self)
	{
		// Queues.
		_localQueue = dispatch_queue_create("com.torchat.ui.tor_control.local", DISPATCH_QUEUE_SERIAL);
		
		// Socket.
		_socket = [[TCSocket alloc] initWithIP:ip port:port];
		
		if (!_socket)
			return nil;
		
		_socket.delegate = self;
		
		[_socket setGlobalOperation:TCSocketOperationLine withSize:0 andTag:0];
		
		// Containers.
		_handlers = [[NSMutableArray alloc] init];
		
		// Regexp.
		_regexpEvent = [NSRegularExpression regularExpressionWithPattern:@"([A-Za-z0-9_]+) (.*)" options:0 error:nil];
	}
	
	return self;
}

- (void)dealloc
{
	TCDebugLog(@"TCTorControl dealloc");
}



/*
** TCTorControl - Life
*/
#pragma mark - TCTorControl - Life

- (void)stop
{
	dispatch_async(_localQueue, ^{
		
		// Stop socket.
		[_socket stop];
		
		// Finish handler.
		for (void (^handler)(NSNumber *code, NSString *line) in _handlers)
			handler(@(551), nil);
		
		[_handlers removeAllObjects];
	});
}



/*
** TCTorControl - Commands
*/
#pragma mark - TCTorControl - Commands

- (void)sendAuthenticationCommandWithKeyHexa:(NSString *)keyHexa resultHandler:(void (^)(BOOL success))handler
{
	dispatch_async(_localQueue, ^{
		
		NSData *command = [[NSString stringWithFormat:@"AUTHENTICATE %@\n", keyHexa] dataUsingEncoding:NSASCIIStringEncoding];
		
		[_handlers addObject:^(NSNumber *code, NSString *line) {
			handler([code integerValue] == 250);
		}];
		
		[_socket sendBytes:command.bytes ofSize:command.length copy:YES];
	});
}

- (void)sendGetInfoCommandWithInfo:(NSString *)info resultHandler:(void (^)(BOOL success, NSString *info))handler
{
	dispatch_async(_localQueue, ^{

		NSData *command = [[NSString stringWithFormat:@"GETINFO %@\n", info] dataUsingEncoding:NSASCIIStringEncoding];
		
		[_handlers addObject:^(NSNumber *code, NSString *line) {
			
			// Check code.
			if ([code integerValue] != 250)
			{
				handler(NO, nil);
				return;
			}
			
			// Check prefix.
			NSString *prefix = [NSString stringWithFormat:@"-%@=", info];
			
			if ([line hasPrefix:prefix] == NO)
			{
				handler(NO, nil);
				return;
			}
			
			// Give content.
			NSString *content = [line substringFromIndex:prefix.length];
			
			handler(YES, content);
		}];
		
		[_socket sendBytes:command.bytes ofSize:command.length copy:YES];
	});
}

- (void)sendSetEventsCommandWithEvents:(NSString *)events resultHandler:(void (^)(BOOL success))handler
{
	dispatch_async(_localQueue, ^{

		NSData *command = [[NSString stringWithFormat:@"SETEVENTS %@\n", events] dataUsingEncoding:NSASCIIStringEncoding];
		
		[_handlers addObject:^(NSNumber *code, NSString *line) {
			handler([code integerValue] == 250);
		}];
		
		[_socket sendBytes:command.bytes ofSize:command.length copy:YES];
	});
}



/*
** TCTorControl - Helpers
*/
#pragma mark - TCTorControl - Helpers

+ (NSDictionary *)parseNoticeBootstrap:(NSString *)line
{
	if (!line)
		return nil;
	
	// Create regexp.
	static dispatch_once_t		onceToken;
	static NSRegularExpression	*regexp;
	
	dispatch_once(&onceToken, ^{
		regexp = [NSRegularExpression regularExpressionWithPattern:@"NOTICE BOOTSTRAP PROGRESS=([0-9]+) TAG=([A-Za-z0-9_]+) SUMMARY=\"(.*)\"" options:0 error:nil];
	});
	
	// Parse.
	NSArray<NSTextCheckingResult *> *matches = [regexp matchesInString:line options:0 range:NSMakeRange(0, line.length)];
	
	if (matches.count != 1)
		return nil;
	
	NSTextCheckingResult *match = [matches firstObject];
	
	if ([match numberOfRanges] != 4)
		return nil;
	
	// Extract.
	NSString *progress = [line substringWithRange:[match rangeAtIndex:1]];
	NSString *tag = [line substringWithRange:[match rangeAtIndex:2]];
	NSString *summary = [line substringWithRange:[match rangeAtIndex:3]];
	
	return @{ @"progress" : @([progress integerValue]), @"tag" : tag, @"summary" : [summary stringByReplacingOccurrencesOfString:@"\\\"" withString:@"\""] };
}



/*
** TCTorControl - TCSocketDelegate
*/
#pragma mark - TCTorControl - TCSocketDelegate

- (void)socket:(TCSocket *)socket operationAvailable:(TCSocketOperation)operation tag:(NSUInteger)tag content:(id)content
{
	dispatch_async(_localQueue, ^{
	
		NSArray *lines = content;
		
		for (NSData *line in lines)
		{
			NSString *lineStr = [[[NSString alloc] initWithData:line encoding:NSASCIIStringEncoding] stringByTrimmingCharactersInSet:[NSCharacterSet newlineCharacterSet]];
			
			if (lineStr.length < 3)
				continue;
			
			NSString	*code = [lineStr substringWithRange:NSMakeRange(0, 3)];
			NSInteger	codeValue = [code integerValue];
			
			if (codeValue <= 0)
				continue;
			
			NSString *info = [[lineStr substringFromIndex:3] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
			
			// Handle events.
			if (codeValue == 650)
			{
				// > Get event handler.
				void (^serverEvent)(NSString *type, NSString *content) = self.serverEvent;
				
				if (!serverEvent)
					continue;
				
				// > Parse event structure.
				NSArray<NSTextCheckingResult *> *matches = [_regexpEvent matchesInString:info options:0 range:NSMakeRange(0, info.length)];
				
				if (matches.count != 1)
					continue;
				
				NSTextCheckingResult *match = [matches firstObject];
				
				if (match.numberOfRanges != 3)
					continue;
				
				NSString *type = [info substringWithRange:[match rangeAtIndex:1]];
				NSString *finfo = [info substringWithRange:[match rangeAtIndex:2]];
				
				// > Notify event.
				serverEvent(type, finfo);
			}
			// Handle common reply.
			else
			{
				// Get handler.
				if ([_handlers count] == 0)
					continue;
				
				void (^handler)(NSNumber *code, NSString *line) = [_handlers firstObject];
				
				[_handlers removeObjectAtIndex:0];
				
				// Give content.
				handler(@(codeValue), info);
			}
			
		}
	});
}

- (void)socket:(TCSocket *)socket error:(TCInfo *)error
{
	// Finish handlers.
	dispatch_async(_localQueue, ^{
		for (void (^handler)(NSNumber *code, NSString *line) in _handlers)
			handler(@(551), nil);
		
		[_handlers removeAllObjects];
	});
		
	// Notify error.
	void (^socketError)(TCInfo *info) = self.socketError;
	
	if (!socketError)
		return;
	
	socketError(error);
}

@end



/*
** TCTorDownloadContext
*/
#pragma mark - TCTorDownloadContext

@implementation TCTorDownloadContext
{
	FILE		*_file;
	NSUInteger	_bytesDownloaded;
	CC_SHA1_CTX	_sha1;
}

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
** TCTorOperations
*/
#pragma mark - TCTorOperations

@implementation TCTorOperations

+ (dispatch_block_t)operationRetrieveRemoteInfoWithURLSession:(NSURLSession *)urlSession completionHandler:(void (^)(TCInfo *info))handler
{
	if (!handler)
		return NULL;
	
	TCOperationsQueue *queue = [[TCOperationsQueue alloc] init];
	
	// -- Get remote info --
	__block NSData *remoteInfoData = nil;
	
	[queue scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
		
		// Create task.
		NSURL					*url = [NSURL URLWithString:TCTorManagerInfoUpdateURL];
		NSURLSessionDataTask	*task;
		
		task = [urlSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			
			// Check error.
			if (error)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationNetwork context:error]);
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
		addCancelBlock(^{
			TCDebugLog(@"<cancel operationRetrieveRemoteInfoWithURLSession (Get remote info)>");
			[task cancel];
		});
	}];
	
	// -- Get signature, check it & parse plist --
	__block NSDictionary *remoteInfo = nil;
	
	[queue scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
		
		// Create task.
		NSURL					*url = [NSURL URLWithString:TCTorManagerInfoSignatureUpdateURL];
		NSURLSessionDataTask	*task;
		
		task = [urlSession dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			
			// Check error.
			if (error)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationNetwork context:error]);
				ctrl(TCOperationsControlFinish);
				return;
			}
			
			// Check content.
			NSData *publicKey = [[NSData alloc] initWithBytesNoCopy:(void *)kPublicKey length:sizeof(kPublicKey) freeWhenDone:NO];
			
			if ([TCDataSignature validateSignature:data forData:remoteInfoData withPublicKey:publicKey] == NO)
			{
				handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationSignature context:error]);
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
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventOperationInfo context:remoteInfo]);
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventOperationDone context:remoteInfo]);
		}];
		
		// Resume task.
		[task resume];
		
		// Cancellation block.
		addCancelBlock(^{
			TCDebugLog(@"<cancel operationRetrieveRemoteInfoWithURLSession (Get signature, check it & parse plist)>");
			[task cancel];
		});
	}];
	
	// Queue start.
	[queue start];
	
	// Cancel block.
	return ^{
		TCDebugLog(@"<cancel operationRetrieveRemoteInfoWithURLSession (global)>");
		[queue cancel];
	};
}

+ (void)operationStageArchiveFile:(NSURL *)fileURL toTorBinariesPath:(NSString *)torBinPath completionHandler:(void (^)(TCInfo *info))handler
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
	if ([torBinPath hasSuffix:@"/"])
		torBinPath = [torBinPath substringToIndex:([torBinPath length] - 1)];
	
	if (!torBinPath)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationIO]);
		return;
	}
	
	// Create target directory.
	if ([fileManager createDirectoryAtPath:torBinPath withIntermediateDirectories:YES attributes:nil error:nil] == NO)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationConfiguration]);
		return;
	}
	
	// Copy tarball.
	NSString *newFilePath = [torBinPath stringByAppendingPathComponent:@"_temp.tgz"];
	
	[fileManager removeItemAtPath:newFilePath error:nil];
	
	if ([fileManager copyItemAtPath:[fileURL path] toPath:newFilePath error:nil] == NO)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationIO]);
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
			handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationExtract context:@([aTask terminationStatus])]);
		else
			handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventOperationDone]);
		
		[fileManager removeItemAtPath:newFilePath error:nil];
	};
	
	@try {
		[task launch];
	}
	@catch (NSException *exception) {
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationExtract context:@(-1)]);
		[fileManager removeItemAtPath:newFilePath error:nil];
	}
}

+ (void)operationCheckSignatureWithTorBinariesPath:(NSString *)torBinPath completionHandler:(void (^)(TCInfo *info))handler
{
	// Check parameters.
	if (!handler)
		handler = ^(TCInfo *info) { };
	
	// Get tor path.
	if (!torBinPath)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationConfiguration]);
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
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationIO]);
		return;
	}
	
	// Check signature.
	NSData *publicKey = [[NSData alloc] initWithBytesNoCopy:(void *)kPublicKey length:sizeof(kPublicKey) freeWhenDone:NO];
	
	if ([TCFileSignature validateSignature:data forContentsOfURL:[NSURL fileURLWithPath:infoPath] withPublicKey:publicKey] == NO)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationSignature context:infoPath]);
		return;
	}
	
	// Read info.plist.
	NSData			*infoData = [NSData dataWithContentsOfFile:infoPath];
	NSDictionary	*info = [NSPropertyListSerialization propertyListWithData:infoData options:NSPropertyListImmutable format:nil error:nil];
	
	if (!info)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationIO]);
		return;
	}
	
	// Give info.
	handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventOperationInfo context:info]);
	
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
			handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationSignature context:filePath]);
			return;
		}
	}
	
	// Finish.
	handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventOperationDone]);
}

+ (void)operationLaunchTorWithBinariesPath:(NSString *)torBinPath dataPath:(NSString *)torDataPath identityPath:(NSString *)torIdentityPath torPort:(uint16_t)torPort torAddress:(NSString *)torAddress clientPort:(uint16_t)clientPort logHandler:(void (^)(TCTorManagerLogKind kind, NSString *log))logHandler completionHandler:(void (^)(TCInfo *info, NSTask *task, NSString *ctrlKeyHexa))handler
{
	if (!handler)
		return;
	
	// Check conversion.
	if (!torBinPath || !torDataPath || !torIdentityPath)
	{
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationConfiguration], nil, nil);
		return;
	}
	
	TCDebugLog(@"~~~~~ launch-tor");
	TCDebugLog(@"_torBinPath '%@'", torBinPath);
	TCDebugLog(@"_torDataPath '%@'", torDataPath);
	TCDebugLog(@"_torIdentityPath '%@'", torIdentityPath);
	TCDebugLog(@"-----");
	
	// Create directories.
	NSFileManager *mng = [NSFileManager defaultManager];
	
	[mng createDirectoryAtPath:torDataPath withIntermediateDirectories:NO attributes:nil error:nil];
	[mng createDirectoryAtPath:torIdentityPath withIntermediateDirectories:NO attributes:nil error:nil];
	
	[mng setAttributes:@{ NSFilePosixPermissions : @(0700) } ofItemAtPath:torDataPath error:nil];
	[mng setAttributes:@{ NSFilePosixPermissions : @(0700) } ofItemAtPath:torIdentityPath error:nil];
	
	// Clean previous file.
	[mng removeItemAtPath:[torDataPath stringByAppendingPathComponent:TCTorManagerTorControlHostFile] error:nil];
	
	// Create control password.
	NSMutableData	*ctrlPassword = [[NSMutableData alloc] initWithLength:32];
	NSString		*hashedPassword;
	NSString		*hexaPassword;
	
	arc4random_buf(ctrlPassword.mutableBytes, ctrlPassword.length);
	
	hashedPassword = s2k_from_data(ctrlPassword, 96);
	hexaPassword = hexa_from_data(ctrlPassword);
	
	// Log snippet.
	dispatch_queue_t logQueue = dispatch_queue_create("com.torchar.uit.tor-task.output", DISPATCH_QUEUE_SERIAL);
	
	void (^handleLog)(NSFileHandle *, TCBuffer *buffer, TCTorManagerLogKind) = ^(NSFileHandle *handle, TCBuffer *buffer, TCTorManagerLogKind kind) {
		NSData *data;
		
		@try {
			data = [handle availableData];
		}
		@catch (NSException *exception) {
			handle.readabilityHandler = nil;
			return;
		}
		
		// Parse data.
		dispatch_async(logQueue, ^{
			
			NSData *line;
			
			[buffer appendBytes:[data bytes] ofSize:[data length] copy:YES];
			
			[buffer dataUpToCStr:"\n" includeSearch:NO];
			
			while ((line = [buffer dataUpToCStr:"\n" includeSearch:NO]))
			{
				NSString *string = [[NSString alloc] initWithData:line encoding:NSUTF8StringEncoding];
				
				logHandler(kind, string);
			}
		});
	};
	
	// Build tor task.
	NSTask *task = [[NSTask alloc] init];
	
	// > handle output.
	if (logHandler)
	{
		NSPipe		*errPipe = [[NSPipe alloc] init];
		NSPipe		*outPipe = [[NSPipe alloc] init];
		TCBuffer	*errBuffer = [[TCBuffer alloc] init];
		TCBuffer	*outBuffer =  [[TCBuffer alloc] init];
		
		NSFileHandle *errHandle = [errPipe fileHandleForReading];
		NSFileHandle *outHandle = [outPipe fileHandleForReading];
		
		errHandle.readabilityHandler = ^(NSFileHandle *handle) { handleLog(handle, errBuffer, TCTorManagerLogError); };
		outHandle.readabilityHandler = ^(NSFileHandle *handle) { handleLog(handle, outBuffer, TCTorManagerLogStandard); };
		
		[task setStandardError:errPipe];
		[task setStandardOutput:outPipe];
	}
	
	// > Set launch path.
	NSString *torExecPath = [[torBinPath stringByAppendingPathComponent:TCTorManagerFileBinBinaries] stringByAppendingPathComponent:TCTorManagerFileBinTor];
	
	[task setLaunchPath:torExecPath];
	
	// > Set arguments.
	NSMutableArray *args = [NSMutableArray array];
	
	[args addObject:@"--ClientOnly"];
	[args addObject:@"1"];
	
	[args addObject:@"--SocksPort"];
	[args addObject:[@(torPort) stringValue]];
	
	[args addObject:@"--SocksListenAddress"];
	[args addObject:(torAddress ?: @"localhost")];
	
	[args addObject:@"--DataDirectory"];
	[args addObject:torDataPath];
	
	[args addObject:@"--HiddenServiceDir"];
	[args addObject:torIdentityPath];
	
	[args addObject:@"--HiddenServicePort"];
	[args addObject:[NSString stringWithFormat:@"11009 127.0.0.1:%u", clientPort]];
	
	[args addObject:@"--ControlPort"];
	[args addObject:@"auto"];
	
	[args addObject:@"--ControlPortWriteToFile"];
	[args addObject:[torDataPath stringByAppendingPathComponent:TCTorManagerTorControlHostFile]];
	
	[args addObject:@"--HashedControlPassword"];
	[args addObject:hashedPassword];
	
	
	[task setArguments:args];
	
	
	// Run tor task.
	@try {
		[task launch];
	} @catch (NSException *exception) {
		handler([TCInfo infoOfKind:TCInfoError domain:TCTorManagerInfoOperationDomain code:TCTorManagerErrorOperationTor context:@(-1)], nil, nil);
		return;
	}
	
	// Notify the launch.
	handler([TCInfo infoOfKind:TCInfoInfo domain:TCTorManagerInfoOperationDomain code:TCTorManagerEventOperationDone], task, hexaPassword);
}

@end



/*
** C Tools
*/
#pragma mark - C Tools

#pragma mark Digest

static NSData *file_sha1(NSURL *fileURL)
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

static NSString *s2k_from_data(NSData *data, uint8_t iterations)
{
	size_t		dataLen = data.length;
	const void	*dataBytes = data.bytes;
	
	uint8_t	buffer[8 + 1 + CC_SHA1_DIGEST_LENGTH]; // 8 (salt) + 1 (iterations) + 20 (sha1)
	
	// Generate salt.
	arc4random_buf(buffer, 8);
	
	// Set number of iterations.
	buffer[8] = iterations;
	
	// Hash key.
	size_t	amount = ((uint32_t)16 + (iterations & 15)) << ((iterations >> 4) + 6);
	size_t	slen = 8 + dataLen;
	char	*sbytes = malloc(slen);
	
	memcpy(sbytes, buffer, 8);
	memcpy(sbytes + 8, dataBytes, dataLen);
	
	CC_SHA1_CTX ctx;
	
	CC_SHA1_Init(&ctx);
	
	while (amount)
	{
		if (amount >= slen)
		{
			CC_SHA1_Update(&ctx, sbytes, (CC_LONG)slen);
			amount -= slen;
		}
		else
		{
			CC_SHA1_Update(&ctx, sbytes, (CC_LONG)amount);
			amount = 0;
		}
	}
	
	CC_SHA1_Final(buffer + 9, &ctx);
	
	free(sbytes);
	
	// Generate hexadecimal.
	NSString *hexa = hexa_from_bytes(buffer, sizeof(buffer));
	
	return [@"16:" stringByAppendingString:hexa];
}


#pragma mark Hexa

static  NSString *hexa_from_bytes(const uint8_t *bytes, size_t len)
{
	if (!bytes || len == 0)
		return nil;
	
	static char hexTable[] = "0123456789abcdef";
	NSMutableString *result = [[NSMutableString alloc] init];
	
	for (size_t i = 0; i < len; i++)
	{
		uint8_t ch = bytes[i];
		
		[result appendFormat:@"%c%c", hexTable[(ch >> 4) & 0xf], hexTable[(ch & 0xf)]];
	}
	
	return result;
}

NSString *hexa_from_data(NSData *data)
{
	return hexa_from_bytes(data.bytes, data.length);
}


#pragma mark Version

static BOOL version_greater(NSString *baseVersion, NSString *newVersion)
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
