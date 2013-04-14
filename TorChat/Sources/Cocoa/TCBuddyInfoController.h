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
@property (assign) IBOutlet NSSegmentedControl	*toolBar;
@property (assign) IBOutlet NSTabView			*views;

@property (assign) IBOutlet TCDragImageView		*avatarView;
@property (assign) IBOutlet NSImageView			*statusView;
@property (assign) IBOutlet NSTextField			*addressField;
@property (assign) IBOutlet NSTextField			*aliasField;

@property (assign) IBOutlet NSTextView			*notesField;

@property (assign) IBOutlet NSTableView			*logTable;

@property (assign) IBOutlet NSTextView			*infoView;

// -- IBAction --
- (IBAction)doToolBar:(id)sender;

// -- Tools --
+ (void)showInfo;
+ (void)showInfoOnBuddy:(TCCocoaBuddy *)buddy;

+ (void)removingBuddy:(TCCocoaBuddy *)buddy;

@end
