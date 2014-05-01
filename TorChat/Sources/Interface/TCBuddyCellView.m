/*
 *  TCBuddyCellView.m
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



#import "TCBuddyCellView.h"

#import "TCBuddy.h"
#import "TCImage.h"



/*
** TCBuddyCellView - Private
*/
#pragma mark - TCBuddyCellView - Private

@interface TCBuddyCellView ()

@property (retain, nonatomic) IBOutlet NSImageView *statusView;
@property (retain, nonatomic) IBOutlet NSImageView *avatarView;
@property (retain, nonatomic) IBOutlet NSTextField *addressField;

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
	if (!buddy)
		return;
	
	// Status.
	if ([buddy blocked])
		[_statusView setImage:[NSImage imageNamed:@"blocked_buddy"]];
	else
	{
		switch ([buddy status])
		{
			case tcstatus_offline:
				[_statusView setImage:[NSImage imageNamed:@"stat_offline"]];
				break;
				
			case tcstatus_available:
				[_statusView setImage:[NSImage imageNamed:@"stat_online"]];
				break;
				
			case tcstatus_away:
				[_statusView setImage:[NSImage imageNamed:@"stat_away"]];
				break;
			case tcstatus_xa:
				[_statusView setImage:[NSImage imageNamed:@"stat_xa"]];
				break;
		}
	}
	
	// Name.
	NSString *name = [buddy finalName];
	
	if (name)
		[self.textField setStringValue:name];
	else
		[self.textField setStringValue:@""];
	
	// Address.
	[_addressField setStringValue:[buddy address]];
	
	// Avatar.
	TCImage *tcImage = [buddy profileAvatar];
	NSImage *image = [tcImage imageRepresentation];
	
	if (image)
		[_avatarView setImage:image];
	else
		[_avatarView setImage:[NSImage imageNamed:NSImageNameUser]];
}



/*
** TCBuddyCellView - NSTableCellView
*/
#pragma mark - TCBuddyCellView - NSTableCellView

- (void)setBackgroundStyle:(NSBackgroundStyle)style
{
    [super setBackgroundStyle:style];
	
    switch (style)
	{
        case NSBackgroundStyleLight:
			[_addressField setTextColor:[NSColor grayColor]];
            break;
			
        case NSBackgroundStyleDark:
        default:
			[_addressField setTextColor:[NSColor whiteColor]];
            break;
    }
}


@end
