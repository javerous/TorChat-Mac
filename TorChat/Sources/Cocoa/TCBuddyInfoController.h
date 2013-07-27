/*
 *  TCBuddyInfoController.h
 *
 *  Copyright 2012 Avérous Julien-Pierre
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



/*
** Forward
*/
#pragma mark - Forward

@class TCCocoaBuddy;
@class TCDragImageView;



/*
** TCBuddyInfoController
*/
#pragma mark - TCBuddyInfoController

@interface TCBuddyInfoController : NSWindowController <NSWindowDelegate>

// -- Property --
@property (strong, nonatomic) IBOutlet NSSegmentedControl	*toolBar;
@property (strong, nonatomic) IBOutlet NSTabView			*views;

@property (strong, nonatomic) IBOutlet TCDragImageView		*avatarView;
@property (strong, nonatomic) IBOutlet NSImageView			*statusView;
@property (strong, nonatomic) IBOutlet NSTextField			*addressField;
@property (strong, nonatomic) IBOutlet NSTextField			*aliasField;

@property (strong, nonatomic) IBOutlet NSTextView			*notesField;

@property (strong, nonatomic) IBOutlet NSTableView			*logTable;

@property (strong, nonatomic) IBOutlet NSTextView			*infoView;

// -- IBAction --
- (IBAction)doToolBar:(id)sender;

// -- Tools --
+ (void)showInfo;
+ (void)showInfoOnBuddy:(TCCocoaBuddy *)buddy;

+ (void)removingBuddy:(TCCocoaBuddy *)buddy;

@end
