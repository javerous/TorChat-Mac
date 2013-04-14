/*
 *  TCBuddyInfoController.h
 *
 *  Copyright 2011 Avérous Julien-Pierre
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



@class TCCocoaBuddy;

@interface TCBuddyInfoController : NSWindowController <NSWindowDelegate>
{
	IBOutlet NSSegmentedControl	*toolBar;
	IBOutlet NSTabView			*views;
	
	IBOutlet NSImageView		*avatarView;
	IBOutlet NSTextField		*addressField;
	IBOutlet NSTextField		*aliasField;
	IBOutlet NSTextField		*profileNameField;
	IBOutlet NSTextField		*profileTextField;
	
	IBOutlet NSTextView			*notesField;
	
	IBOutlet NSTableView		*logTable;
	
@private
    TCCocoaBuddy				*_buddy;
	NSMutableArray				*_logs;
	NSString					*_address;
}

// -- IBAction --
- (IBAction)doToolBar:(id)sender;

// -- Tools --
+ (void)showInfo;
+ (void)showInfoOnBuddy:(TCCocoaBuddy *)buddy;

+ (void)removingBuddy:(TCCocoaBuddy *)buddy;

@end
