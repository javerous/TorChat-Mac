/*
 *  TorChatAppDelegate.m
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

#import "TorChatAppDelegate.h"

#import "TCMainController.h"
#import "TCBuddiesWindowController.h"
#import "TCFilesWindowController.h"
#import "TCBuddyInfoWindowsController.h"
#import "TCLogsWindowController.h"
#import "TCPreferencesWindowController.h"
#import "TCChatWindowController.h"

#import "TCBuddy.h"
#import "TCCoreManager.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TorChatAppDelegate - Private
*/
#pragma mark - TorChatAppDelegate - Private

@interface TorChatAppDelegate ()

@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyShowMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyDeleteMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyChatMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyBlockMenu;
@property (strong, nonatomic) IBOutlet NSMenuItem	*buddyFileMenu;


- (IBAction)showPreferences:(id)sender;

- (IBAction)showTransfers:(id)sender;
- (IBAction)showBuddies:(id)sender;
- (IBAction)showLogs:(id)sender;
- (IBAction)showMessages:(id)sender;

- (IBAction)doBuddyShowInfo:(id)sender;
- (IBAction)doBuddyAdd:(id)sender;
- (IBAction)doBuddyRemove:(id)sender;
- (IBAction)doBuddyChat:(id)sender;
- (IBAction)doBuddyToggleBlocked:(id)sender;
- (IBAction)doBuddySendFile:(id)sender;

- (IBAction)doEditProfile:(id)sender;

@end



/*
** TorChatAppDelegate
*/
#pragma mark - TorChatAppDelegate

@implementation TorChatAppDelegate


/*
** TorChatAppDelegate - Life
*/
#pragma mark - TorChatAppDelegate - Life

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	// Start TorChat.
	[[TCMainController sharedController] startWithCompletionHandler:^(id <TCConfigAppEncryptable> _Nullable configuration, TCCoreManager * _Nullable core, NSError * _Nullable error) {
		
		if (!configuration || !core)
		{
			// Note:
			//  We have to show the error alert in the main thread (AppKit constraint), and because we have to wait for its end before calling terminate,
			//    all our code should run in a row in the main thread.
			//
			//  When we call [NSApplication terminate] method, if [NSApplication applicationShouldTerminate] return NSTerminateLater, then a new run-loop is
			//    launched, waiting for [NSApplication replyToApplicationShouldTerminate] to be called.
			//  If we call terminate in dispatch_get_main_queue(), then this new run-loop is going to run in our dispatched block,
			//    which makes our block waiting for the end of this run-loop, which makes the main run-loop waiting for the end of this run-loop. As our
			//    "stopWithCompletionHandler" relies on some code executed on the main queue to finish, we are dead-locking (the stop wait on the main-queue,
			//    itself waiting on the termination new run-loop, itself waiting for the termination-reply, itself waiting for the stop to be finished, etc.).
			//  Because of the mode in which the "terminate" new run-loop run, the sources scheduled on the main-run loop (including blocks dispatched
			//    on the main queue) continues to be executed. So we perform our termination on the main run-loop instead of the main queue : this way we
			//    prevent the described dead-lock.
			
			CFRunLoopRef runLoop = CFRunLoopGetMain();
			
			CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes, ^{
				
				if (error)
				{
					NSAlert *alert = [[NSAlert alloc] init];
					
					alert.messageText = NSLocalizedString(@"app_delegate_start_error_title", @"");
					alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"app_delegate_start_error_code", @""), error.code, error.localizedDescription];
					
					[alert runModal];
				}
				
				[[NSApplication sharedApplication] terminate:nil];
			});
			
			CFRunLoopWakeUp(runLoop);
		}
	}];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
	[[TCMainController sharedController] stopWithCompletionHandler:^{
		[sender replyToApplicationShouldTerminate:YES];
	}];

	return NSTerminateLater;
}



/*
** TorChatAppDelegate - IBActions
*/
#pragma mark - TorChatAppDelegate - IBActions

#pragma mark Application

- (IBAction)showPreferences:(id)sender
{
	[[TCPreferencesWindowController sharedController] showWindow:nil];
}

#pragma mark Windows

- (IBAction)showTransfers:(id)sender
{
	[[TCFilesWindowController sharedController] showWindow:sender];
}

- (IBAction)showBuddies:(id)sender
{
	[[TCBuddiesWindowController sharedController] showWindow:sender];
}

- (IBAction)showLogs:(id)sender
{
	[[TCLogsWindowController sharedController] showWindow:sender];
}

- (IBAction)showMessages:(id)sender
{
	[[TCChatWindowController sharedController] openChatWithBuddy:nil select:YES];
}


#pragma mark Buddies

- (IBAction)doBuddyShowInfo:(id)sender
{
	[[TCBuddiesWindowController sharedController] doShowInfo:sender];
}

- (IBAction)doBuddyAdd:(id)sender
{
	[[TCBuddiesWindowController sharedController] doAdd:sender];
}

- (IBAction)doBuddyRemove:(id)sender
{
	[[TCBuddiesWindowController sharedController] doRemove:sender];
}

- (IBAction)doBuddyChat:(id)sender
{
	[[TCBuddiesWindowController sharedController] doChat:sender];
}

- (IBAction)doBuddySendFile:(id)sender
{
	[[TCBuddiesWindowController sharedController] doSendFile:sender];
}

- (IBAction)doBuddyToggleBlocked:(id)sender
{
	[[TCBuddiesWindowController sharedController] doToggleBlock:sender];
}

- (IBAction)doEditProfile:(id)sender
{
	[[TCBuddiesWindowController sharedController] doEditProfile:sender];
}



/*
** TorChatAppDelegate - NSMenuItem
*/
#pragma mark - TorChatAppDelegate - NSMenuItem

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem
{
	if (menuItem == _buddyShowMenu || menuItem == _buddyDeleteMenu || menuItem == _buddyChatMenu || menuItem == _buddyBlockMenu || menuItem == _buddyFileMenu)
	{
		TCBuddy *buddy = [[TCBuddiesWindowController sharedController] selectedBuddy];
		
		if ([buddy blocked])
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_unblock_buddy", @"")];
		else
			[_buddyBlockMenu setTitle:NSLocalizedString(@"menu_block_buddy", @"")];
		
		if (!buddy)
			return NO;
	}
	
	return YES;
}

@end


NS_ASSUME_NONNULL_END
