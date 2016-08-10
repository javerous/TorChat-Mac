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

#import <SMFoundation/SMFoundation.h>
#import <SMTor/SMTor.h>
#import <SMAssistant/SMAssistant.h>

#import "TCMainController.h"

#import "TCConfigSQLite.h"

#import "TCLogsManager.h"

#import "TCBuddiesWindowController.h"
#import "TCChatWindowController.h"
#import "TCFilesWindowController.h"
#import "TCConfigurationHelperController.h"

#import "TCPanel_Welcome.h"
#import "TCPanel_Security.h"
#import "TCPanel_Mode.h"
#import "TCPanel_Custom.h"
#import "TCPanel_Bundled.h"

#import "TCCoreManager.h"
#import "TCBuddy.h"

#import "SMTorConfiguration+TCConfig.h"


/*
** TCMainController - Private
*/
#pragma mark - TCMainController - Private

@interface TCMainController ()  <TCCoreManagerObserver, TCBuddyObserver>
{
	dispatch_queue_t	_localQueue;
	SMOperationsQueue	*_opQueue;
	
	id <TCConfigAppEncryptable> _configuration;
	SMTorManager				*_torManager;
	
	// Buddies.
	NSMutableSet *_buddies;
	
	// Path monitor.
	id	_torBinPathObserver;
	id	_torDataPathObserver;
	
	dispatch_source_t _torChangesTimer;
}

@property (assign, nonatomic) BOOL isStarting;

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
		
		_buddies = [[NSMutableSet alloc] init];
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
			NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Security class], [TCPanel_Mode class], [TCPanel_Custom class], [TCPanel_Bundled class] ];
			
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
			self.isStarting = NO;
			opCtrl(SMOperationsControlContinue);
			handler(configuration, core);
		};
		
		// Start.
		self.isStarting = YES;
		[operations start];
	}];
}

- (void)startWithConfiguration:(id <TCConfigAppEncryptable>)configuration completionHandler:(void (^)(TCCoreManager *core))handler
{
	if (!handler)
		handler = ^(TCCoreManager *core) { };
	
	[_opQueue scheduleBlock:^(SMOperationsControl  _Nonnull opCtrl) {
		
		SMOperationsQueue *operations = [[SMOperationsQueue alloc] init];
		
		// -- Stop if necessary --
		[operations scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
			[self _stopWithCompletionHandler:^{
				ctrl(SMOperationsControlContinue);
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
			self.isStarting = NO;
			opCtrl(SMOperationsControlContinue);
			handler(core);
		};
		
		// Start.
		self.isStarting = YES;
		[operations start];
	}];
}


- (void)_startWithConfiguration:(id <TCConfigAppEncryptable>)configuration completionHandler:(void (^)(TCCoreManager *core))handler
{
	// > opQueue <

	SMOperationsQueue *operationQueue = [[SMOperationsQueue alloc] initStarted];
	
	// -- Start Tor if necessary --
	[operationQueue scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
		
		if (!configuration)
		{
			NSLog(@"Unable to create configuration.");
			[[NSApplication sharedApplication] terminate:nil];
			return;
		}
		
		_configuration = configuration;
		
		// Start tor only in bundled mode.
		if ([_configuration mode] != TCConfigModeBundled)
		{
			ctrl(SMOperationsControlContinue);
			return;
		}
		
		// Create tor manager.
		SMTorConfiguration *torConfig = [[SMTorConfiguration alloc] initWithTorChatConfiguration:_configuration];
		
		_torManager = [[SMTorManager alloc] initWithConfiguration:torConfig];
		
		_torManager.logHandler = ^(SMTorLogKind kind, NSString *log) {
			
			switch (kind)
			{
				case SMTorLogStandard:
					[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogInfo message:@"tor_out_log", log];
					break;
					
				case SMTorLogError:
					[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"tor_error_log", log];
					break;
			}
		};

		// Start tor manager via UI.
		[SMTorStartController startWithTorManager:_torManager infoHandler:^(SMInfo *startInfo) {
			
			[[TCLogsManager sharedManager] addGlobalLogWithInfo:startInfo];
			
			if ([startInfo.domain isEqualToString:SMTorInfoStartDomain] == NO)
				return;
			
			switch (startInfo.kind)
			{
				case SMInfoInfo:
				{
					if (startInfo.code == SMTorEventStartServiceID)
					{
						[_configuration setSelfIdentifier:startInfo.context];
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
						_torManager = nil;
						ctrl(SMOperationsControlContinue);
					}
					break;
				}
					
				case SMInfoError:
				{
					_torManager = nil;
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
		
		if (_torManager == nil)
		{
			ctrl(SMOperationsControlContinue);
			return;
		}
		
		// Launch update check.
		[_torManager checkForUpdateWithInfoHandler:^(SMInfo *updateInfo) {
			
			// > Log check.
			[[TCLogsManager sharedManager] addGlobalLogWithInfo:updateInfo];
			
			// > Handle update.
			if (updateInfo.kind == SMInfoInfo && [updateInfo.domain isEqualToString:SMTorInfoCheckUpdateDomain] && updateInfo.code == SMTorEventCheckUpdateAvailable)
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
	
	// -- Launch controllers --
	[operationQueue scheduleOnQueue:_localQueue block:^(SMOperationsControl ctrl) {
		
		if (_torManager == nil && [_configuration mode] == TCConfigModeBundled)
		{
			handler(nil);
			ctrl(SMOperationsControlContinue);
			return;
		}
		
		// Create core manager.
		_core = [[TCCoreManager alloc] initWithConfiguration:_configuration];
		
		// Observe core.
		[_core addObserver:self];
		
		// Handle current buddies.
		NSArray *buddies = [_core buddies];
		
		for (TCBuddy *buddy in buddies)
		{
			[buddy addObserver:self];
			[_buddies addObject:buddy];
		};
		
		// Start controllers.
		dispatch_group_t group = dispatch_group_create();
		
		// > Buddies.
		dispatch_group_enter(group);
		
		[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration coreManager:_core completionHandler:^{
			dispatch_group_leave(group);
		}];
		
		// > Chat.
		dispatch_group_enter(group);

		[[TCChatWindowController sharedController] startWithConfiguration:_configuration coreManager:_core completionHandler:^{
			dispatch_group_leave(group);
		}];
	
		// > Files.
		dispatch_group_enter(group);
		
		[[TCFilesWindowController sharedController] startWithCoreManager:_core completionHandler:^{
			dispatch_group_leave(group);
		}];
		
		// Wait.
		dispatch_group_notify(group, dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
			handler(_core);
			[_core start];
			ctrl(SMOperationsControlContinue);
		});
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
	
	// Stop controlers.
	// > Buddies.
	dispatch_group_enter(group);
	
	[[TCBuddiesWindowController sharedController] stopWithCompletionHandler:^{
		dispatch_group_leave(group);
	}];
	
	// > Chat.
	dispatch_group_enter(group);

	[[TCChatWindowController sharedController] stopWithCompletionHandler:^{
		dispatch_group_leave(group);
	}];
	
	// > File.
	dispatch_group_enter(group);

	[[TCFilesWindowController sharedController] stopWithCompletionHandler:^{
		dispatch_group_leave(group);
	}];

	// Unmonitor.
	for (TCBuddy *buddy in _buddies)
		[buddy removeObserver:self];
	
	[_buddies removeAllObjects];

	[_core removeObserver:self];
	
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
	[[TCLogsManager sharedManager] addBuddyLogWithBuddyIdentifier:[buddy identifier] name:[buddy finalName] info:info];
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
