/*
 *  TCBuddiesController.h
 *
 *  Copyright 2013 Avérous Julien-Pierre
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



#import <Cocoa/Cocoa.h>

#import "TCCocoaBuddy.h"

#import "TCConfig.h"


/*
** Forward
*/
#pragma mark - Forward

@class TCController;

@class TCDropButton;



/*
** Notification
*/
#pragma mark - Notification

#define TCBuddiesControllerSelectChanged	@"TCBuddiesControllerSelectChanged"
#define TCBuddiesControllerBuddyKey			@"buddy"

#define TCBuddiesControllerAvatarChanged	@"TCBuddiesControllerAvatarChanged"
#define TCBuddiesControllerNameChanged		@"TCBuddiesControllerNameChanged"
#define TCBuddiesControllerTextChanged		@"TCBuddiesControllerTextChanged"



/*
** TCBuddiesController
*/
#pragma mark - TCBuddiesController

@interface TCBuddiesController : NSObject

// -- Propertie --
@property (strong, nonatomic) IBOutlet NSWindow				*mainWindow;
@property (strong, nonatomic) IBOutlet NSProgressIndicator	*indicator;
@property (strong, nonatomic) IBOutlet NSTableView			*tableView;
@property (strong, nonatomic) IBOutlet NSPopUpButton		*imTitle;
@property (strong, nonatomic) IBOutlet NSButton				*imRemove;
@property (strong, nonatomic) IBOutlet NSPopUpButton		*imStatus;
@property (strong, nonatomic) IBOutlet NSImageView			*imStatusImage;
@property (strong, nonatomic) IBOutlet TCDropButton			*imAvatar;

@property (strong, nonatomic) IBOutlet NSWindow				*addWindow;
@property (strong, nonatomic) IBOutlet NSTextField			*addNameField;
@property (strong, nonatomic) IBOutlet NSTextField			*addAddressField;
@property (strong, nonatomic) IBOutlet NSTextView			*addNotesField;

@property (strong, nonatomic) IBOutlet NSWindow				*profileWindow;
@property (strong, nonatomic) IBOutlet NSTextField			*profileName;
@property (strong, nonatomic) IBOutlet NSTextView			*profileText;

// -- Singleton --
+ (TCBuddiesController *)sharedController;

// -- IBAction --
- (IBAction)doStatus:(id)sender;
- (IBAction)doAvatar:(id)sender;
- (IBAction)doTitle:(id)sender;
- (IBAction)doRemove:(id)sender;
- (IBAction)doAdd:(id)sender;
- (IBAction)doChat:(id)sender;
- (IBAction)doSendFile:(id)sender;
- (IBAction)doToggleBlock:(id)sender;
- (IBAction)doEditProfile:(id)sender;

- (IBAction)doAddOk:(id)sender;
- (IBAction)doAddCancel:(id)sender;

- (IBAction)doProfileOk:(id)sender;
- (IBAction)doProfileCancel:(id)sender;

- (IBAction)showWindow:(id)sender;

// -- Tools --
- (TCCocoaBuddy *)selectedBuddy;

// -- Running --
- (void)stop;
- (void)startWithConfiguration:(id <TCConfig>)configuration;

// -- Blocked Buddies --
- (BOOL)addBlockedBuddy:(NSString *)address;
- (BOOL)removeBlockedBuddy:(NSString *)address;

@end
