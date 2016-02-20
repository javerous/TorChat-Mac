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

#import "TCConfigPlist.h"
#import "TCLogsManager.h"

#import "TCBuddiesWindowController.h"
#import "TCPanel_Welcome.h"
#import "TCPanel_Mode.h"
#import "TCPanel_Advanced.h"
#import "TCPanel_Basic.h"

#import "TCCoreManager.h"
#import "SMTorConfiguration+TCConfig.h"


/*
** TCMainController
*/
#pragma mark - TCMainController

@implementation TCMainController
{
	dispatch_queue_t _localQueue;
	
	id <TCConfigInterface>	_configuration;
	SMTorManager			*_torManager;
	
	SMAssistantController	*_assistant;
	
	BOOL _running;
	
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
	}
	
	return self;
}



/*
** TCMainController - Life
*/
#pragma mark - TCMainController - Life

- (void)startWithCompletionHandler:(void (^)(id <TCConfigInterface> configuration, TCCoreManager *core))handler
{
	if (!handler)
		handler = ^(id <TCConfigInterface> configuration, TCCoreManager *core) { };
	
	dispatch_async(_localQueue, ^{
		
		if (_running)
		{
			handler(_configuration, _core);
			return;
		}
		
		_running = YES;
		
		SMOperationsQueue *startQueue = [[SMOperationsQueue alloc] initStarted];
		
		// -- Try loading config from file --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(SMOperationsControl ctrl) {
			
			// Check that we don't have configuration.
			if (_configuration)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			NSFileManager	*mng;
			NSBundle		*bundle;
			NSString		*path = nil;
			
			mng = [NSFileManager defaultManager];
			bundle = [NSBundle mainBundle];
			
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
			
			// Try to open the file
			if (path)
			{
				_configuration = [[TCConfigPlist alloc] initWithFile:path];
				
				if (!_configuration)
				{
					NSString *key = NSLocalizedString(@"ac_error_read_file", @"");
					
					[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"ac_error_read_file", path];
					[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:key, path] runModal];
				}
			}
			
			// Continue.
			ctrl(SMOperationsControlContinue);
		 }];
	
		
		// -- Try to create a config with assistant --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(SMOperationsControl ctrl) {

			// Check that we don't have configuration.
			if (_configuration)
			{
				ctrl(SMOperationsControlContinue);
				return;
			}
			
			// Show assistant.
			NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Mode class], [TCPanel_Advanced class], [TCPanel_Basic class] ];
			
			_assistant = [SMAssistantController startAssistantWithPanels:panels completionHandler:^(id context) {
				_configuration = context;
				ctrl(SMOperationsControlContinue);
			}];
		}];
		
		// -- Start Tor if necessary --
		__block BOOL torAvailable = NO;
		
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(SMOperationsControl ctrl) {

			if (!_configuration)
			{
				NSLog(@"Unable to create configuration.");
				[[NSApplication sharedApplication] terminate:nil];
				return;
			}
			
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
			[SMTorWindowController startWithTorManager:_torManager infoHandler:^(SMInfo *startInfo) {
				
				[[TCLogsManager sharedManager] addGlobalLogWithInfo:startInfo];
				
				if ([startInfo.domain isEqualToString:SMTorManagerInfoStartDomain] == NO)
					return;
				
				switch (startInfo.kind)
				{
					case SMInfoInfo:
					{
						if (startInfo.code == SMTorManagerEventStartHostname)
						{
							[_configuration setSelfAddress:startInfo.context];
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
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(SMOperationsControl ctrl) {

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
					
					[[SMTorUpdateWindowController sharedController] handleUpdateFromVersion:oldVersion toVersion:newVersion torManager:_torManager infoHandler:^(SMInfo * _Nonnull info) {
						[[TCLogsManager sharedManager] addGlobalLogWithInfo:info];
					}];
				}
			}];
			
			// Don't wait for end.
			ctrl(SMOperationsControlContinue);
		}];
		
		// -- Launch torchat --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(SMOperationsControl ctrl) {
			
			// Create core manager.
			_core = [[TCCoreManager alloc] initWithConfiguration:_configuration];
		
			// Start buddy controller.
			[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration coreManager:_core];
		
			// Notify.
			handler(_configuration, _core);
		
			// Remove assistant, if any.
			_assistant = nil;
			
			// Continue.
			ctrl(SMOperationsControlContinue);
		}];
	});
}

- (void)stop
{
	dispatch_sync(_localQueue, ^{
		
		_running = NO;
		
		[_configuration synchronize];
		[[TCBuddiesWindowController sharedController] stop];
		
		_configuration = nil;
		_core = nil;
	});
}

- (void)reload
{
	dispatch_async(_localQueue, ^{
		
		if (!_running)
			return;
		
		[[TCBuddiesWindowController sharedController] stop];
		[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration coreManager:_core];
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
