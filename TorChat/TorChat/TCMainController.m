/*
 *  TCMainController.m
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

@import SMFoundation;
@import SMTor;
@import SMAssistant;

#import "TCMainController.h"

#import "TCConfigSQLite.h"

#import "TCLogsManager.h"

#import "TCBuddiesWindowController.h"
#import "TCPanel_Welcome.h"
#import "TCPanel_Security.h"
#import "TCPanel_Mode.h"
#import "TCPanel_Advanced.h"
#import "TCPanel_Basic.h"

#import "TCConfigurationHelperController.h"

#import "TCCoreManager.h"
#import "SMTorConfiguration+TCConfig.h"


/*
** TCMainController
*/
#pragma mark - TCMainController

@implementation TCMainController
{
	dispatch_queue_t	_localQueue;
	SMOperationsQueue	*_opQueue;

	id <TCConfigAppEncryptable> _configuration;
	SMTorManager				*_torManager;
	
	// Path monitor.
	id	_torIdentityPathObserver;
	id	_torBinPathObserver;
	id	_torDataPathObserver;
	
	dispatch_source_t _torChangesTimer;
}


/*
** TCMainController - Instance
*/
#pragma mark - TCMainController - Instance

+ (TCMainController *)sharedController
{
	static dispatch_once_t	pred;
	static TCMainController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCMainController alloc] init];
	});
	
	return instance;
}

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		_localQueue = dispatch_queue_create("com.torchat.app.main-controller.local", DISPATCH_QUEUE_SERIAL);
		_opQueue = [[SMOperationsQueue alloc] initStarted];
	}
	
	return self;
}



/*
** TCMainController - Life
*/
#pragma mark - TCMainController - Life

#pragma mark Start

- (void)startWithCompletionHandler:(void (^)(id <TCConfigAppEncryptable> configuration, TCCoreManager *core))handler
{
	if (!handler)
		handler = ^(id <TCConfigAppEncryptable> configuration, TCCoreManager *core) { };
	
	[_opQueue scheduleBlock:^(SMOperationsControl  _Nonnull opCtrl) {
		
		SMOperationsQueue *operations = [[SMOperationsQueue alloc] init];
		__block id <TCConfigAppEncryptable> configuration = nil;

		// -- Stop if necessary --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			[self _stopWithCompletionHandler:^{
				ctrl(SMOperationsControlContinue);
			}];
		}];
		
		// -- Try loading config from file --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			
			NSFileManager	*mng = [NSFileManager defaultManager];
			NSBundle		*bundle = [NSBundle mainBundle];
			NSString		*path = nil;
			
			// Try to find config on the same folder as the application
			if (!path)
			{
				path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
				
				if ([mng fileExistsAtPath:path] == NO)
					path = nil;
			}
			
			// Try to find on config home folder
			if (!path)
			{
				path = [@"~/torchat.conf" stringByExpandingTildeInPath];
				
				if ([mng fileExistsAtPath:path] == NO)
					path = nil;
			}
			
			// Skip configuration.
			if (!path)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			// Open configuration.
			[TCConfigurationHelperController openConfigurationAtPath:path completionHandler:^(TCConfigurationHelperCompletionType type, id <TCConfigAppEncryptable> aConfiguration) {
				switch (type)
				{
					case TCConfigurationHelperCompletionTypeCanceled:
					{
						ctrl(SMOperationsControlFinish);
						break;
					}
						
					case TCConfigurationHelperCompletionTypeDone:
					{
						configuration = aConfiguration;
						ctrl(SMOperationsControlContinue);
					}
				}
			}];
		}];
		
		
		// -- Try to create a config with assistant --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			
			// Check that we don't have configuration.
			if (configuration)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			// Show assistant.
			NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Security class], [TCPanel_Mode class], [TCPanel_Advanced class], [TCPanel_Basic class] ];
			
			[SMAssistantController startAssistantWithPanels:panels completionHandler:^(SMAssistantCompletionType assCompType, id context) {
				
				switch (assCompType)
				{
					case SMAssistantCompletionTypeCanceled:
					{
						ctrl(SMOperationsControlFinish);
						break;
					}
						
					case SMAssistantCompletionTypeDone:
					{
						if ([context isKindOfClass:[NSString class]])
						{
							// Open configuration.
							[TCConfigurationHelperController openConfigurationAtPath:context completionHandler:^(TCConfigurationHelperCompletionType confCompType, id <TCConfigAppEncryptable> aConfiguration) {
								switch (confCompType)
								{
									case TCConfigurationHelperCompletionTypeCanceled:
									{
										ctrl(SMOperationsControlFinish);
										break;
									}
										
									case TCConfigurationHelperCompletionTypeDone:
									{
										configuration = aConfiguration;
										ctrl(SMOperationsControlContinue);
										break;
									}
								}
							}];
						}
						else
						{
							configuration = context;
							ctrl(SMOperationsControlContinue);
						}
						
						break;
					}
				}
			}];
		}];
		
		// -- Start with configuration --
		__block TCCoreManager *core = nil;
		
		[operations scheduleBlock:^(SMOperationsControl ctrl) {
			[self _startWithConfiguration:configuration completionHandler:^(TCCoreManager *aCore) {
				core = aCore;
				ctrl(SMOperationsControlContinue);
			}];
		}];
		
		// -- Finish --
		operations.finishHandler = ^(BOOL canceled) {
			opCtrl(SMOperationsControlContinue);
			handler(configuration, core);
		};
		
		[operations start];
	}];
}

- (void)startWithConfiguration:(id <TCConfigAppEncryptable>)configuration completionHandler:(void (^)(TCCoreManager *core))handler
{
	if (!handler)
		handler = ^(TCCoreManager *core) { };
	
	[_opQueue scheduleBlock:^(SMOperationsControl  _Nonnull opCtrl) {
		
		SMOperationsQueue *operations = [[SMOperationsQueue alloc] initStarted];
		
		// -- Stop if necessary --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			[self _stopWithCompletionHandler:^{
				ctrl(SMOperationsControlContinue);
			}];
		}];
		
		// -- Start with configuration --
		[operations scheduleBlock:^(SMOperationsControl ctrl) {
			[self _startWithConfiguration:configuration completionHandler:^(TCCoreManager *core) {
				ctrl(SMOperationsControlContinue);
				opCtrl(SMOperationsControlContinue);
				handler(core);
			}];
		}];
	}];
}


- (void)_startWithConfiguration:(id <TCConfigAppEncryptable>)configuration completionHandler:(void (^)(TCCoreManager *core))handler
{
	// > opQueue <
	
	SMOperationsQueue *operationQueue = [[SMOperationsQueue alloc] initStarted];
	
	// -- Start Tor if necessary --
	__block BOOL torAvailable = NO;
	
	[operationQueue scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
		
		if (!configuration)
		{
			NSLog(@"Unable to create configuration.");
			[[NSApplication sharedApplication] terminate:nil];
			return;
		}
		
		_configuration = configuration;
		
		// Start tor only in basic mode.
		if ([_configuration mode] != TCConfigModeBasic)
		{
			ctrl(SMOperationsControlContinue);
			return;
		}
		
		// Create tor manager.
		SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:_configuration];
		
		_torManager = [[SMTorManager alloc] initWithConfiguration:torConfig];
		
		_torManager.logHandler = ^(SMTorManagerLogKind kind, NSString *log) {
			
			switch (kind)
			{
				case SMTorManagerLogStandard:
					[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogInfo message:@"tor_out_log", log];
					break;
					
				case SMTorManagerLogError:
					[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"tor_error_log", log];
					break;
			}
		};
		
		// Start tor manager via UI.
		[SMTorStartController startWithTorManager:_torManager infoHandler:^(SMInfo *startInfo) {
			
			[[TCLogsManager sharedManager] addGlobalLogWithInfo:startInfo];
			
			if ([startInfo.domain isEqualToString:SMTorManagerInfoStartDomain] == NO)
				return;
			
			switch (startInfo.kind)
			{
				case SMInfoInfo:
				{
					if (startInfo.code == SMTorManagerEventStartHostname)
					{
						[_configuration setSelfIdentifier:startInfo.context];
					}
					else if (startInfo.code == SMTorManagerEventStartDone)
					{
						torAvailable = YES;
						ctrl(SMOperationsControlContinue);
					}
					break;
				}
					
				case SMInfoWarning:
				{
					if (startInfo.code == SMTorManagerWarningStartCanceled)
						ctrl(SMOperationsControlContinue);
					break;
				}
					
				case SMInfoError:
				{
					ctrl(SMOperationsControlContinue);
					break;
				}
			}
		}];
		
		// Monitor paths changes.
		[self monitorPathsChanges];
	}];
	
	// -- Update Tor if necessary --
	[operationQueue scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
		
		if (torAvailable == NO)
		{
			ctrl(SMOperationsControlContinue);
			return;
		}
		
		// Launch update check.
		[_torManager checkForUpdateWithInfoHandler:^(SMInfo *updateInfo) {
			
			// > Log check.
			[[TCLogsManager sharedManager] addGlobalLogWithInfo:updateInfo];
			
			// > Handle update.
			if (updateInfo.kind == SMInfoInfo && [updateInfo.domain isEqualToString:SMTorManagerInfoCheckUpdateDomain] && updateInfo.code == SMTorManagerEventCheckUpdateAvailable)
			{
				NSDictionary	*context = updateInfo.context;
				NSString		*oldVersion = context[@"old_version"];
				NSString		*newVersion = context[@"new_version"];
				
				[SMTorUpdateController handleUpdateWithTorManager:_torManager oldVersion:oldVersion newVersion:newVersion infoHandler:^(SMInfo * _Nonnull info) {
					[[TCLogsManager sharedManager] addGlobalLogWithInfo:info];
				}];
			}
		}];
		
		// Don't wait for end.
		ctrl(SMOperationsControlContinue);
	}];
	
	// -- Launch torchat --
	[operationQueue scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
		
		// Create core manager.
		_core = [[TCCoreManager alloc] initWithConfiguration:_configuration];
		
		// Start buddy controller.
		[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration coreManager:_core];
		
		// Notify.
		handler(_core);
		
		// Continue.
		ctrl(SMOperationsControlContinue);
	}];
}


#pragma mark Stop

- (void)stopWithCompletionHandler:(dispatch_block_t)handler
{
	if (!handler)
		handler = ^{ };
	
	[_opQueue scheduleOnQueue:_localQueue block:^(SMOperationsControl  _Nonnull ctrl) {
		[self _stopWithCompletionHandler:^{
			handler();
			ctrl(SMOperationsControlContinue);
		}];
	}];
}

- (void)_stopWithCompletionHandler:(dispatch_block_t)handler
{
	// > opQueue + _localQueue <
	
	if (!handler)
		handler = ^{ };
	
	dispatch_group_t group = dispatch_group_create();
	
	// Stop buddies.
	dispatch_group_enter(group);
	
	[[TCBuddiesWindowController sharedController] stopWithCompletionHandler:^{
		dispatch_group_leave(group);
	}];

	// Stop core.
	if (_core)
	{
		dispatch_group_enter(group);

		[_core stopWithCompletionHandler:^{
			_core = nil;
			dispatch_group_leave(group);
		}];
	}
	
	// Stop Tor.
	if (_torManager)
	{
		dispatch_group_enter(group);

		[_torManager stopWithCompletionHandler:^{
			_torManager = nil;
			dispatch_group_leave(group);
		}];
	}
	
	// Wait for end.
	dispatch_group_notify(group, _localQueue, ^{
		
		// > Clean configuration.
		if (_configuration)
		{
			[_configuration synchronize];
			_configuration = nil;
		}
		
		// > Notify.
		handler();
	});
}



/*
** TCMainController - Helpers
*/
#pragma mark - TCMainController - Helpers

- (void)monitorPathsChanges
{
	__weak TCMainController *weakSelf = self;

	_torIdentityPathObserver = [_configuration addPathObserverForComponent:TCConfigPathComponentTorIdentity queue:nil usingBlock:^{
		[weakSelf handleTorPathChange];
	}];
	
	_torBinPathObserver = [_configuration addPathObserverForComponent:TCConfigPathComponentTorBinary queue:nil usingBlock:^{
		[weakSelf handleTorPathChange];
	}];
	
	_torDataPathObserver = [_configuration addPathObserverForComponent:TCConfigPathComponentTorData queue:nil usingBlock:^{
		[weakSelf handleTorPathChange];
	}];
}

- (void)handleTorPathChange
{
	dispatch_async(_localQueue, ^{
		
		// Lazily create timer.
		if (!_torChangesTimer)
		{
			_torChangesTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
			
			dispatch_source_set_timer(_torChangesTimer, DISPATCH_TIME_FOREVER, 0, 0);
			
			dispatch_source_set_event_handler(_torChangesTimer, ^{
				dispatch_source_set_timer(_torChangesTimer, DISPATCH_TIME_FOREVER, 0, 0);
				
				SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:_configuration];
				
				[_torManager loadConfiguration:torConfig infoHandler:nil];
			});
			
			dispatch_resume(_torChangesTimer);
		}
		
		// Schedule a change.
		dispatch_source_set_timer(_torChangesTimer, dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), 0, 1 * NSEC_PER_SEC);
	});
}

@end
