/*
 *  TCMainController.m
 *
<<<<<<< HEAD
 *  Copyright 2014 Avérous Julien-Pierre
=======
 *  Copyright 2016 Avérous Julien-Pierre
>>>>>>> javerous/master
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

<<<<<<< HEAD


=======
>>>>>>> javerous/master
#import "TCMainController.h"

#import "TCConfigPlist.h"
#import "TCLogsManager.h"

#import "TCBuddiesWindowController.h"
#import "TCUpdateWindowController.h"
<<<<<<< HEAD
=======
#import "TCTorWindowController.h"
>>>>>>> javerous/master
#import "TCAssistantWindowController.h"
#import "TCPanel_Welcome.h"
#import "TCPanel_Mode.h"
#import "TCPanel_Advanced.h"
#import "TCPanel_Basic.h"

#import "TCTorManager.h"
<<<<<<< HEAD
=======
#import "TCCoreManager.h"
#import "TCOperationsQueue.h"
>>>>>>> javerous/master

#import "TCInfo+Render.h"

#if defined(PROXY_ENABLED) && PROXY_ENABLED
# import "TCConfigProxy.h"
#endif


<<<<<<< HEAD

/*
** TCMainController - Private
*/
#pragma mark - TCMainController - Private

@interface TCMainController ()
{
	id <TCConfigInterface>	_configuration;
	TCTorManager	*_torManager;
	
	TCAssistantWindowController	*_assistant;
}

@end



/*
** TCMainController
*/
#pragma mark - TCMainController

@implementation TCMainController


/*
** TCMainController - Constructor & Destructor
*/
#pragma mark - TCMainController - Constructor & Destructor
=======
/*
** TCMainController
*/
#pragma mark - TCMainController

@implementation TCMainController
{
	dispatch_queue_t _localQueue;
	
	id <TCConfigInterface>	_configuration;
	TCTorManager			*_torManager;
	
	TCAssistantWindowController *_assistant;
	
	BOOL _running;
}


/*
** TCMainController - Instance
*/
#pragma mark - TCMainController - Instance
>>>>>>> javerous/master

+ (TCMainController *)sharedController
{
	static dispatch_once_t	pred;
	static TCMainController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCMainController alloc] init];
	});
	
	return instance;
}

<<<<<<< HEAD
- (id)init
{
	self = [super init];
	
    if (self)
	{
    }
    
    return self;
=======
- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		_localQueue = dispatch_queue_create("com.torchat.app.main-controller.local", DISPATCH_QUEUE_SERIAL);
	}
	
	return self;
>>>>>>> javerous/master
}



/*
<<<<<<< HEAD
** TCMainController - Running
*/
#pragma mark - TCMainController - Running

- (void)start
{
	static BOOL		running = NO;

	TCConfigPlist	*conf = nil;

	// Can't have more than one instance of this controller
	if (running)
		return;
	
	running = YES;
	
	// -- Try loading config from proxy --
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	
	if (!conf)
	{
		NSDistantObject *proxy = [NSConnection rootProxyForConnectionWithRegisteredName:TCProxyName host:nil];
				
		if (proxy)
		{
			// Set protocol methods
			[proxy setProtocolForProxy:@protocol(TCConfigProxy)];
			
			// Load
			conf = [[TCConfigPlist alloc] initWithFileProxy:(id <TCConfigProxy>)proxy];

			if (!conf)
			{
				[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_error_read_proxy"];
				[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_error_read_proxy", @"")] runModal];
			}
		}
	}

#endif
	
	// -- Try loading config from file --
	if (!conf)
	{
		NSFileManager	*mng;
		NSBundle		*bundle;
		NSString		*path = nil;

		mng = [NSFileManager defaultManager];
		bundle = [NSBundle mainBundle];
		
		// > Try to find config on the same folder as the application
		if (!path)
		{
			path = [[[bundle bundlePath] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"torchat.conf"];
		
			if ([mng fileExistsAtPath:path] == NO)
				path = nil;
		}
		
		// > Try to find on config home folder
		if (!path)
		{
			path = [@"~/torchat.conf" stringByExpandingTildeInPath];
			
			if ([mng fileExistsAtPath:path] == NO)
				path = nil;
		}
		
		// > Try to open the file
		if (path)
		{
			conf = [[TCConfigPlist alloc] initWithFile:path];
			
			if (!conf)
			{
				NSString *key = NSLocalizedString(@"ac_error_read_file", @"");
				
				[[TCLogsManager sharedManager] addGlobalAlertLog:@"ac_error_read_file", path];
				[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:key, path] runModal];
			}
		}
	}

// <DEBUG
#warning DEBUG
	NSLog(@"TConfigPathDomainReferal: %@", [conf pathForDomain:TConfigPathDomainReferal]);
	NSLog(@"TConfigPathDomainTorBinary: %@", [conf pathForDomain:TConfigPathDomainTorBinary]);
	NSLog(@"TConfigPathDomainTorData: %@", [conf pathForDomain:TConfigPathDomainTorData]);
	NSLog(@"TConfigPathDomainTorIdentity: %@", [conf pathForDomain:TConfigPathDomainTorIdentity]);
	NSLog(@"TConfigPathDomainDownloads: %@", [conf pathForDomain:TConfigPathDomainDownloads]);
// DEBUG >
	
	// > Check if we should launch assistant.
	if (!conf)
	{
		NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Mode class], [TCPanel_Advanced class], [TCPanel_Basic class] ];
		
		_assistant = [TCAssistantWindowController startAssistantWithPanels:panels completionHandler:^(id context) {
			
			NSDictionary *items = context;
	
			// Hold items.
			_configuration = items[@"configuration"];
			_torManager = items[@"tor_manager"];
			
			// Start buddy controller.
			[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration];
			
			// Remove instance.
			_assistant = nil;
		}];
	}
	else
	{
		// > Hold the config.
		_configuration = conf;
		
		// > Start tor.
		if ([_configuration mode] == TCConfigModeBasic)
		{
			_torManager = [[TCTorManager alloc] initWithConfiguration:_configuration];
			
			[_torManager startWithHandler:^(TCInfo *info) {
				[[TCLogsManager sharedManager] addGlobalLogEntry:[info render]];
			}];
		}
		
		// > Start buddy controller.
		[[TCBuddiesWindowController sharedController] startWithConfiguration:conf];
		
		// > Check for update.
		dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
			
			[_torManager checkForUpdateWithCompletionHandler:^(TCInfo *info) {
				
				if (info.kind == TCInfoInfo)
				{
					if ([info.domain isEqualToString:TCTorManagerInfoCheckUpdateDomain])
					{
						if (info.code == TCTorManagerEventCheckUpdateAvailable)
						{
							NSDictionary	*context = info.context;
							NSString		*oldVersion = context[@"old_version"];
							NSString		*newVersion = context[@"new_version"];
							
							[[TCUpdateWindowController sharedController] handleUpdateFromVersion:oldVersion toVersion:newVersion torManager:_torManager];
						}
					}
				}
			}];
		});
	}
	

// <DEBUG
#warning DEBUG
	
	//[[TCUpdateWindowController sharedController] showWindow:nil];
	
	[[TCUpdateWindowController sharedController] handleUpdateFromVersion:@"1.2.0" toVersion:@"1.2.1" torManager:_torManager];

	/*
	[_torManager checkForUpdateWithCompletionHandler:^(TCInfo *info) {
		
		if (info.kind == TCInfoInfo)
		{
			if ([info.domain isEqualToString:TCTorManagerInfoUpdateDomain])
			{
				if (info.code == TCTorManagerEventUpdateAvailable)
				{
					NSDictionary	*context = info.context;
					NSString		*oldVersion = context[@"old_version"];
					NSString		*newVersion = context[@"new_version"];

					[[TCUpdateWindowController sharedController] handleUpdateFromVersion:oldVersion toVersion:newVersion torManager:_torManager];
				}
			}
		}
		
		//NSLog(@"info: %@", [info render]);
	}];*/
	/*
	
	__block NSUInteger archiveSize = 0;
	dispatch_block_t cancelBlock = NULL;

	
	cancelBlock = [_torManager updateWithEventHandler:^(TCInfo *info){

		if (info.kind == TCInfoInfo)
		{
			switch ((TCTorManagerEventUpdate)info.code)
			{
				case TCTorManagerEventUpdateArchiveInfoRetrieving:
					NSLog(@"Retrieving archive info...");
					break;
					
				case TCTorManagerEventUpdateArchiveSize:
					NSLog(@"Archive size: %@ bytes", info.context);
					archiveSize = [info.context unsignedIntegerValue];
					break;
					
				case TCTorManagerEventUpdateArchiveDownloading:
					//NSLog(@"Downloading: %@ bytes (%f)", info.context, ((float)[info.context unsignedIntegerValue] * 100.0) / (float)archiveSize);

					break;
					
				case TCTorManagerEventUpdateArchiveStage:
					NSLog(@"Archive staging...");
					break;
					
				case TCTorManagerEventUpdateSignatureCheck:
					NSLog(@"Checking signature...");
					break;
					
				case TCTorManagerEventUpdateRelaunch:
					NSLog(@"Relaunching binary...");
					break;
					
				case TCTorManagerEventUpdateDone:
					NSLog(@"Update done.");
					break;
			}
		}
		else
			NSLog(@"Error: %@", [info render]);
	}];
	
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		cancelBlock();
	});
	 */
// DEBUG>
=======
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
		
		TCOperationsQueue *startQueue = [[TCOperationsQueue alloc] initStarted];
		
		// -- Try loading config from proxy --
#if defined(PROXY_ENABLED) && PROXY_ENABLED
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(TCOperationsControl ctrl) {
			
			// Check that we don't have configuration.
			if (_configuration)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Create distant object.
			NSDistantObject *proxy = [NSConnection rootProxyForConnectionWithRegisteredName:TCProxyName host:nil];
			
			if (proxy)
			{
				// Set protocol methods
				[proxy setProtocolForProxy:@protocol(TCConfigProxy)];
				
				// Load
				_configuration = [[TCConfigPlist alloc] initWithFileProxy:proxy];
				
				if (!_configuration)
				{
					[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"ac_error_read_proxy"];
					[[NSAlert alertWithMessageText:NSLocalizedString(@"logs_error_title", @"") defaultButton:nil alternateButton:nil otherButton:nil informativeTextWithFormat:NSLocalizedString(@"ac_error_read_proxy", @"")] runModal];
				}
			}
			
			// Continue.
			ctrl(TCOperationsControlContinue);
		}];
#endif
		
		// -- Try loading config from file --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(TCOperationsControl ctrl) {
			
			// Check that we don't have configuration.
			if (_configuration)
			{
				ctrl(TCOperationsControlContinue);
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
			ctrl(TCOperationsControlContinue);
		 }];
	
		
		// -- Try to create a config with assistant --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(TCOperationsControl ctrl) {

			// Check that we don't have configuration.
			if (_configuration)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Show assistant.
			NSArray *panels = @[ [TCPanel_Welcome class], [TCPanel_Mode class], [TCPanel_Advanced class], [TCPanel_Basic class] ];
			
			_assistant = [TCAssistantWindowController startAssistantWithPanels:panels completionHandler:^(id context) {
				_configuration = context;
				ctrl(TCOperationsControlContinue);
			}];
		}];
		
		// -- Start Tor if necessary --
		__block BOOL torAvailable = NO;
		
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(TCOperationsControl ctrl) {

			if (!_configuration)
			{
				NSLog(@"Unable to create configuration.");
				[[NSApplication sharedApplication] terminate:nil];
				return;
			}
			
			// Start tor only in basic mode.
			if ([_configuration mode] != TCConfigModeBasic)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Create tor manager.
			_torManager = [[TCTorManager alloc] initWithConfiguration:_configuration];
			
			_torManager.logHandler = ^(TCTorManagerLogKind kind, NSString *log) {
				
				switch (kind)
				{
					case TCTorManagerLogStandard:
						[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogInfo message:@"tor_out_log", log];
						break;
						
					case TCTorManagerLogError:
						[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogError message:@"tor_error_log", log];
						break;
				}
			};
			
			// Start tor manager via UI.
			[TCTorWindowController startWithTorManager:_torManager handler:^(TCInfo *startInfo) {
				
				[[TCLogsManager sharedManager] addGlobalLogWithInfo:startInfo];
				
				if ([startInfo.domain isEqualToString:TCTorManagerInfoStartDomain] == NO)
					return;
				
				switch (startInfo.kind)
				{
					case TCInfoInfo:
					{
						if (startInfo.code == TCTorManagerEventStartDone)
						{
							torAvailable = YES;
							ctrl(TCOperationsControlContinue);
						}
						break;
					}
						
					case TCInfoWarning:
					{
						if (startInfo.code == TCTorManagerWarningStartCanceled)
							ctrl(TCOperationsControlContinue);
						break;
					}
						
					case TCInfoError:
					{
						ctrl(TCOperationsControlContinue);
						break;
					}
				}
			}];
		}];
		
		// -- Update Tor if necessary --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(TCOperationsControl ctrl) {

			if (torAvailable == NO)
			{
				ctrl(TCOperationsControlContinue);
				return;
			}
			
			// Launch update check.
			[_torManager checkForUpdateWithCompletionHandler:^(TCInfo *updateInfo) {
				
				// > Log check.
				[[TCLogsManager sharedManager] addGlobalLogWithInfo:updateInfo];
				
				// > Handle update.
				if (updateInfo.kind == TCInfoInfo && [updateInfo.domain isEqualToString:TCTorManagerInfoCheckUpdateDomain] && updateInfo.code == TCTorManagerEventCheckUpdateAvailable)
				{
					NSDictionary	*context = updateInfo.context;
					NSString		*oldVersion = context[@"old_version"];
					NSString		*newVersion = context[@"new_version"];
					
					[[TCUpdateWindowController sharedController] handleUpdateFromVersion:oldVersion toVersion:newVersion torManager:_torManager];
				}
			}];
			
			// Don't wait for end.
			ctrl(TCOperationsControlContinue);
		}];
		
		// -- Launch torchat --
		[startQueue scheduleOnQueue:dispatch_get_main_queue() block:^(TCOperationsControl ctrl) {
			
			// Create core manager.
			_core = [[TCCoreManager alloc] initWithConfiguration:_configuration];
		
			// Start buddy controller.
			[[TCBuddiesWindowController sharedController] startWithConfiguration:_configuration coreManager:_core];
		
			// Notify.
			handler(_configuration, _core);
		
			// Remove assistant, if any.
			_assistant = nil;
			
			// Continue.
			ctrl(TCOperationsControlContinue);
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
>>>>>>> javerous/master
}

@end
