//
//  TCBuddyCellView.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 05/08/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCBuddyCellView.h"

#import "TCBuddy.h"



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
	NSImage *image = [buddy profileAvatar];
	
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
