/*
 *  TCMainController.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import <SMFoundation/SMFoundation.h>
#import <SMTor/SMTor.h>
#import <SMAssistant/SMAssistant.h>

#import "TCMainController.h"

#import "TCConfigSQLite.h"

#import "TCLogsManager.h"

#import "TCConfigurationHelperController.h"
#import "TCPreferencesWindowController.h"
#import "TCBuddiesWindowController.h"
#import "TCChatWindowController.h"
#import "TCFilesWindowController.h"
#import "TCLogsWindowController.h"

#import "TCPanel_Welcome.h"
#import "TCPanel_Security.h"
#import "TCPanel_Mode.h"
#import "TCPanel_Custom.h"
#import "TCPanel_Bundled.h"

#import "TCCoreManager.h"
#import "TCBuddy.h"

#import "SMTorConfiguration+TCConfig.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCMainController - Private
*/
#pragma mark - TCMainController - Private

@interface TCMainController ()  <TCCoreManagerObserver, TCBuddyObserver>
{
	dispatch_queue_t	_localQueue;
	SMOperationsQueue	*_opQueue;
	
	id <TCConfigAppEncryptable> _configuration;
	TCCoreManager				*_core;
	SMTorManager				*_torManager;
	
	// Buddies.
	NSMutableSet *_buddies;
	
	// Path monitor.
	id	_torBinPathObserver;
	id	_torDataPathObserver;
	
	dispatch_source_t _torChangesTimer;
}

@end



/*
** TCMainController
*/
#pragma mark - TCMainController

@implementation TCMainController


/*
** TCMainController - Instance
*/
#pragma mark - TCMainController - Instance

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		_localQueue = dispatch_queue_create("com.torchat.app.main-controller.local", DISPATCH_QUEUE_SERIAL);
		_opQueue = [[SMOperationsQueue alloc] initStarted];
		
		_buddies = [[NSMutableSet alloc] init];
	}
	
	return self;
}



/*
** TCMainController - Life
*/
#pragma mark - TCMainController - Life

#pragma mark Start

- (void)startWithCompletionHandler:(void (^)(TCMainControllerResult result, id _Nullable context))handler
{
	if (!handler)
		handler = ^(TCMainControllerResult result, id _Nullable context) { };
	
	[_opQueue scheduleBlock:^(SMOperationsControl  _Nonnull opCtrl) {
		
		SMOperationsQueue *operations = [[SMOperationsQueue alloc] init];
		
		__block TCMainControllerResult	startResult = TCMainControllerResultErrored;
		__block id						startResultContext = nil;
		
		// -- Stop if necessary --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			[self _stopWithCompletionHandler:^{
				ctrl(SMOperationsControlContinue);
			}];
		}];
		
		
		// -- Try loading config from file --
		__block id <TCConfigAppEncryptable> configuration = nil;

		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			
			// Search an accessible config path.
			NSFileManager	*mng = [NSFileManager defaultManager];
			NSString		*path = nil;

			NSArray *defaultSearchPaths = @[
				[[NSBundle mainBundle].bundlePath.stringByDeletingLastPathComponent stringByAppendingPathComponent:@"torchat.conf"], // config in same folder of the app (autonomous USB-key, DMG, etc.) - best to be first.
				@"~/torchat.conf".stringByExpandingTildeInPath,						// visible config in home directory.
				@"~/.torchat.conf".stringByExpandingTildeInPath,					// hidden config in home directory.
				@"~/.config/torchat.conf".stringByExpandingTildeInPath,				// visible config in config directory.
				@"~/Library/Preferences/torchat.conf".stringByExpandingTildeInPath,	// visible config in OS X Preferences directory.
			];
			
			for (NSString *tryPath in defaultSearchPaths)
			{
				if ([mng isReadableFileAtPath:tryPath])
				{
					path = tryPath;
					break;
				}
			}
			
			// No path found : continue on assistant.
			if (!path)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			// Open configuration.
			[TCConfigurationHelperController openConfigurationAtPath:path completionHandler:^(TCConfigurationHelperResult result, id _Nullable context) {
				
				switch (result)
				{
						
					case TCConfigurationHelperResultDone:
					{
						configuration = context;
						ctrl(SMOperationsControlContinue);
						break;
					}
						
					case TCConfigurationHelperResultCanceled:
					{
						startResult = TCMainControllerResultCanceled;
						ctrl(SMOperationsControlFinish);
						break;
					}
						
					case TCConfigurationHelperResultErrored:
					{
						startResult = TCMainControllerResultErrored;
						startResultContext = context;
						ctrl(SMOperationsControlFinish);
						break;
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
			NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Security class], [TCPanel_Mode class], [TCPanel_Custom class], [TCPanel_Bundled class] ];
			
			[SMAssistantController startAssistantWithPanels:panels completionHandler:^(SMAssistantCompletionType assCompType, id context) {
				
				switch (assCompType)
				{
					case SMAssistantCompletionTypeCanceled:
					{
						startResult = TCMainControllerResultCanceled;
						ctrl(SMOperationsControlFinish);
						break;
					}
						
					case SMAssistantCompletionTypeDone:
					{
						if ([context isKindOfClass:[NSString class]])
						{
							// Open configuration.
							[TCConfigurationHelperController openConfigurationAtPath:context completionHandler:^(TCConfigurationHelperResult confCompResult, id _Nullable confCompContext) {
								
								switch (confCompResult)
								{
									case TCConfigurationHelperResultDone:
									{
										configuration = confCompContext;
										ctrl(SMOperationsControlContinue);
										break;
									}
										
									case TCConfigurationHelperResultCanceled:
									{
										startResult = TCMainControllerResultCanceled;
										ctrl(SMOperationsControlFinish);
										break;
									}
										
									case TCConfigurationHelperResultErrored:
									{
										startResult = TCMainControllerResultErrored;
										startResultContext = confCompContext;
										ctrl(SMOperationsControlFinish);
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
		
		
		// -- Start bundled tor if necessary --
		__block SMTorManager *torManager = nil;

		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			
			// Start tor only in bundled mode.
			if (configuration.mode != TCConfigModeBundled)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			void (^fatalErrorHandler)(NSString *errorCause) = self.fatalErrorHandler;
			
			// Create tor manager.
			SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:configuration];
			
			torManager = [[SMTorManager alloc] initWithConfiguration:torConfig];
			
			if (!torManager)
			{
				startResult = TCMainControllerResultErrored;
				startResultContext = [NSError errorWithDomain:TCMainControllerErrorDomain code:10 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"main_ctrl_conf_error_tor_manager", @"") }];
				ctrl(SMOperationsControlFinish);
				return;
			}
			
			torManager.logHandler = ^(SMTorLogKind kind, NSString *log, BOOL fatalLog) {
				
				switch (kind)
				{
					case SMTorLogStandard:
						[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogInfo message:@"tor_out_log", log];
						break;
						
					case SMTorLogError:
						[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"tor_error_log", log];
						break;
				}
				
				if (fatalLog && fatalErrorHandler)
					fatalErrorHandler(log);
			};
			
			// Start tor manager via UI.
			[SMTorStartController startWithTorManager:torManager infoHandler:^(SMInfo *startInfo) {
				
				[[TCLogsManager sharedManager] addGlobalLogWithInfo:startInfo];
				
				if ([startInfo.domain isEqualToString:SMTorInfoStartDomain] == NO)
					return;
				
				switch (startInfo.kind)
				{
					case SMInfoInfo:
					{
						if (startInfo.code == SMTorEventStartServiceID)
						{
							configuration.selfIdentifier = startInfo.context;
						}
						if (startInfo.code == SMTorEventStartServicePrivateKey)
						{
							configuration.selfPrivateKey = startInfo.context;
						}
						else if (startInfo.code == SMTorEventStartDone)
						{
							ctrl(SMOperationsControlContinue);
						}
						break;
					}
						
					case SMInfoWarning:
					{
						if (startInfo.code == SMTorWarningStartCanceled)
						{
							startResult = TCMainControllerResultCanceled;

							ctrl(SMOperationsControlFinish);
						}
						break;
					}
						
					case SMInfoError:
					{
						startResult = TCMainControllerResultErrored;
						startResultContext = [NSError errorWithDomain:TCMainControllerErrorDomain code:11 userInfo:@{ NSLocalizedDescriptionKey: [startInfo renderMessage] }];
						
						ctrl(SMOperationsControlFinish);
						
						break;
					}
				}
			}];
			
			// Monitor paths changes.
			[self monitorPathsChanges];
		}];
		
		// -- Update Tor if necessary --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			
			if (configuration.mode != TCConfigModeBundled)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			// Launch update check.
			[torManager checkForUpdateWithInfoHandler:^(SMInfo *updateInfo) {
				
				// > Log check.
				[[TCLogsManager sharedManager] addGlobalLogWithInfo:updateInfo];
				
				// > Handle update.
				if (updateInfo.kind == SMInfoInfo && [updateInfo.domain isEqualToString:SMTorInfoCheckUpdateDomain] && updateInfo.code == SMTorEventCheckUpdateAvailable)
				{
					NSDictionary	*context = updateInfo.context;
					NSString		*oldVersion = context[@"old_version"];
					NSString		*newVersion = context[@"new_version"];
					
					[SMTorUpdateController handleUpdateWithTorManager:torManager oldVersion:oldVersion newVersion:newVersion infoHandler:^(SMInfo * _Nonnull info) {
						[[TCLogsManager sharedManager] addGlobalLogWithInfo:info];
					}];
				}
			}];
			
			// Don't wait for end.
			ctrl(SMOperationsControlContinue);
		}];
		
		// -- Create core --
		__block TCCoreManager *core = nil;

		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			
			// Create core manager.
			core = [[TCCoreManager alloc] initWithConfiguration:configuration];
			
			if (!core)
			{
				startResult = TCMainControllerResultErrored;
				startResultContext = [NSError errorWithDomain:TCMainControllerErrorDomain code:12 userInfo:@{ NSLocalizedDescriptionKey: NSLocalizedString(@"main_ctrl_conf_error_core_manager", @"") }];
				
				ctrl(SMOperationsControlFinish);
				
				return;
			}
			
			[core addObserver:self];
			
			// Handle current buddies.
			NSArray *buddies = core.buddies;
			
			for (TCBuddy *buddy in buddies)
			{
				[buddy addObserver:self];
				[_buddies addObject:buddy];
			};
			
			ctrl(SMOperationsControlContinue);
		}];
		
		// -- Create controllers --
		[operations scheduleOnQueue:dispatch_get_main_queue() block:^(SMOperationsControl ctrl) {

			_preferencesController = [[TCPreferencesWindowController alloc] initWithConfiguration:configuration coreManager:core];
			_buddiesController = [[TCBuddiesWindowController alloc] initWithMainController:self configuration:configuration coreManager:core];
			_chatController = [[TCChatWindowController alloc] initWithConfiguration:configuration coreManager:core];
			_filesController = [[TCFilesWindowController alloc] initWithConfiguration:configuration coreManager:core];
			_logsController = [[TCLogsWindowController alloc] initWithConfiguration:configuration];
			
			// Show buddies.
			[_buddiesController showWindow:nil];
			
			// Set result.
			startResult = TCMainControllerResultStarted;
			startResultContext = nil;
			
			// Start core.
			dispatch_async(_localQueue, ^{
				[core start];
				ctrl(SMOperationsControlContinue);
			});
		}];
		
		// -- Finish --
		operations.finishHandler = ^(BOOL canceled) {
			
			if (startResult == TCMainControllerResultStarted)
			{
				_configuration = configuration;
				_torManager = torManager;
				_core = core;
			}
			
			handler(startResult, startResultContext);

			opCtrl(SMOperationsControlContinue);
		};
		
		// Start.
		[operations start];
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
	
	// Synchronize controllers.
	// > Preferences.
	if (_preferencesController)
	{
		dispatch_group_enter(group);
		
		[_preferencesController synchronizeWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}
	
	// > Buddies.
	if (_buddiesController)
	{
		dispatch_group_enter(group);
	
		[_buddiesController synchronizeWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}
	
	// > Chat.
	if (_chatController)
	{
		dispatch_group_enter(group);
		
		[_chatController synchronizeWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}
	
	// > File.
	if (_filesController)
	{
		dispatch_group_enter(group);
		
		[_filesController synchronizeWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}
	
	// > Logs.
	if (_logsController)
	{
		dispatch_group_enter(group);
		
		[_logsController synchronizeWithCompletionHandler:^{
			dispatch_group_leave(group);
		}];
	}

	// Unmonitor.
	for (TCBuddy *buddy in _buddies)
		[buddy removeObserver:self];
	
	[_buddies removeAllObjects];

	// Stop core.
	if (_core)
	{
		[_core removeObserver:self];

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
	
	// Wait for sync & stops.
	dispatch_group_notify(group, dispatch_get_main_queue(), ^{
		
		// > Close windows.
		[_preferencesController close];
		[_buddiesController close];
		[_chatController close];
		[_filesController close];
		[_logsController close];
		
		// > Unset controllers.
		_preferencesController = nil;
		_buddiesController = nil;
		_chatController = nil;
		_filesController = nil;
		_logsController = nil;
		
		dispatch_async(_localQueue, ^{
			
			// > Close configuration.
			[_configuration close];
			_configuration = nil;
			
			// > Notify.
			handler();
		});
	});
}



/*
** TCMainController - TCCoreManagerObserver
*/
#pragma mark - TCMainController - TCCoreManagerObserver

- (void)torchatManager:(TCCoreManager *)manager information:(SMInfo *)info
{
	// Log the item
	[[TCLogsManager sharedManager] addGlobalLogWithInfo:info];
	
	// Handle buddy life.
	if (info.kind == SMInfoInfo)
	{
		if (info.code == TCCoreEventBuddyNew)
		{
			TCBuddy *buddy = (TCBuddy *)info.context;

			[buddy addObserver:self];
			
			dispatch_async(_localQueue, ^{
				[_buddies addObject:buddy];
			});
		}
		else if (info.code == TCCoreEventBuddyRemove)
		{
			TCBuddy *buddy = (TCBuddy *)info.context;
			
			[buddy removeObserver:self];
			
			dispatch_async(_localQueue, ^{
				[_buddies removeObject:buddy];
			});
		}
	}
}



/*
** TCMainController - TCBuddyObserver
*/
#pragma mark - TCMainController - TCBuddyObserver

- (void)buddy:(TCBuddy *)buddy information:(SMInfo *)info
{
	// Skip spammy logs.
	if ([info.domain isEqualToString:TCBuddyInfoDomain] && info.kind == SMInfoInfo && (info.code == TCBuddyEventFileReceiveRunning || info.code == TCBuddyEventFileSendRunning))
		return;
	
	[[TCLogsManager sharedManager] addBuddyLogWithBuddyIdentifier:buddy.identifier name:buddy.finalName info:info];
}



/*
** TCMainController - Helpers
*/
#pragma mark - TCMainController - Helpers

- (void)monitorPathsChanges
{
	__weak TCMainController *weakSelf = self;
	
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

NS_ASSUME_NONNULL_END

