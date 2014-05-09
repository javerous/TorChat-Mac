/*
 *  TCChatCellView.m
 *
 *  Copyright 2014 Avérous Julien-Pierre
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



#import "TCChatCellView.h"

#import "TCButton.h"
#import "TCThreePartImageView.h"



/*
** TCChatCellView - Private
*/
#pragma mark - TCChatCellView - Private

@interface TCChatCellView ()
{
	NSTrackingArea *_trakingArea;
}

@property (strong, nonatomic) IBOutlet NSImageView		*avatarView;
@property (strong, nonatomic) IBOutlet NSTextField		*unreadField;

@property (strong, nonatomic) IBOutlet TCButton					*closeButton;
@property (strong, nonatomic) IBOutlet TCThreePartImageView		*balloonView;

@end



/*
** TCChatCellView
*/
#pragma mark - TCChatCellView

@implementation TCChatCellView


/*
** TCChatCellView - Instance
*/
#pragma mark - TCChatCellView - Instance

- (void)awakeFromNib
{
	[_closeButton setImage:[NSImage imageNamed:@"file_stop"]];
	[_closeButton setRollOverImage:[NSImage imageNamed:@"file_stop_rollover"]];
	[_closeButton setPushImage:[NSImage imageNamed:@"file_stop_pushed"]];
	
	_balloonView.startCap = [NSImage imageNamed:@"balloon_left"];
	_balloonView.centerFill = [NSImage imageNamed:@"balloon_center"];
	_balloonView.endCap = [NSImage imageNamed:@"balloon_right"];
	
	_trakingArea = [[NSTrackingArea alloc] initWithRect:NSZeroRect options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveInKeyWindow | NSTrackingInVisibleRect) owner:self userInfo:nil];

	[self addTrackingArea:_trakingArea];
}



/*
** TCChatCellView - Content
*/
#pragma mark - TCChatCellView - Content

- (void)setContent:(NSDictionary *)content
{
	if (!content)
		return;
	
	// Set avatar.
	NSImage *avatar = content[TCChatCellAvatarKey];

	if (avatar)
		_avatarView.image = avatar;
	else
		_avatarView.image = [NSImage imageNamed:NSImageNameUser];
	
	// Set name.
	NSString *name = content[TCChatCellNameKey];

	if ([name length] > 0)
		self.textField.stringValue = name;
	else
		self.textField.stringValue = @"-";
	
	// Set text.
	NSString *text = content[TCChatCellChatTextKey];

	if ([text length] > 0)
		_unreadField.stringValue = text;
	else
		_unreadField.stringValue = @"";
	
	// Set close button (NSTrackingArea seem to be boggus on this).
	BOOL closeButton = [content[TCChatCellCloseKey] boolValue];
	
	[_closeButton setHidden:(closeButton == NO)];
}



/*
** TCChatCellView - NSTrackingArea
*/
#pragma mark - TCChatCellView - NSTrackingArea

- (void)mouseEntered:(NSEvent *)theEvent
{
	[_closeButton setHidden:NO];
}

- (void)mouseExited:(NSEvent *)theEvent
{
	[_closeButton setHidden:YES];
}



/*
** TCChatCellView - NSTableCellView
*/
#pragma mark - TCChatCellView - NSTableCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    [super setBackgroundStyle:style];

	[[_unreadField cell] setBackgroundStyle:NSBackgroundStyleLight];
}

@end
