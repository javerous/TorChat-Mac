/*
 *  TCBuddyCellView.m
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

#import "TCBuddyCellView.h"

#import "TCBuddy.h"
#import "TCImage.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCBuddyCellView - Private
*/
#pragma mark - TCBuddyCellView - Private

@interface TCBuddyCellView ()

@property (retain, nonatomic) IBOutlet NSImageView *statusView;
@property (retain, nonatomic) IBOutlet NSImageView *avatarView;
@property (retain, nonatomic) IBOutlet NSTextField *identifierField;

@end




/*
** TCBuddyCellView
*/
#pragma mark - TCBuddyCellView

@implementation TCBuddyCellView


/*
** TCBuddyCellView - Content
*/
#pragma mark - TCBuddyCellView - Content

- (void)setBuddy:(TCBuddy *)buddy
{
	NSAssert(buddy, @"buddy is nil");
	
	// Status.
	if (buddy.blocked)
		_statusView.image = [NSImage imageNamed:@"blocked_buddy"];
	else
	{
		switch (buddy.status)
		{
			case TCStatusOffline:
				_statusView.image = [NSImage imageNamed:@"stat_offline"];
				break;
				
			case TCStatusAvailable:
				_statusView.image = [NSImage imageNamed:@"stat_online"];
				break;
				
			case TCStatusAway:
				_statusView.image = [NSImage imageNamed:@"stat_away"];
				break;
			case TCStatusXA:
				_statusView.image = [NSImage imageNamed:@"stat_xa"];
				break;
		}
	}
	
	// Name.
	NSString *name = buddy.finalName;
	
	if (name)
		self.textField.stringValue = name;
	else
		self.textField.stringValue = @"";
	
	// Identifier.
	_identifierField.stringValue = buddy.identifier;
	
	// Avatar.
	TCImage *tcImage = buddy.profileAvatar;
	NSImage *image = [tcImage imageRepresentation];

	if (image)
		_avatarView.image = image;
	else
		_avatarView.image = [NSImage imageNamed:NSImageNameUser];
}



/*
** TCBuddyCellView - NSTableCellView
*/
#pragma mark - TCBuddyCellView - NSTableCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    super.backgroundStyle = style;
	
    switch (style)
	{
        case NSBackgroundStyleLight:
			_identifierField.textColor = [NSColor grayColor];
            break;
			
        case NSBackgroundStyleDark:
        default:
			_identifierField.textColor = [NSColor whiteColor];
            break;
    }
}

@end


NS_ASSUME_NONNULL_END
