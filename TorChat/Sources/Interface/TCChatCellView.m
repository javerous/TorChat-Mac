//
//  TCChatCellView.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 09/08/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCChatCellView.h"

#import "TCButton.h"



/*
** TCChatCellView - Private
*/
#pragma mark - TCChatCellView - Private

@interface TCChatCellView ()
{
	NSTrackingArea		*_trakingArea;
}

@property (retain, nonatomic) IBOutlet NSImageView		*avatarView;
@property (retain, nonatomic) IBOutlet NSTextField		*unreadField;

@property (retain, nonatomic) IBOutlet TCButton			*closeButton;

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
	
	NSImage		*avatar = content[TCChatCellAvatarKey];
	NSString	*name = content[TCChatCellNameKey];
	NSString	*text = content[TCChatCellChatTextKey];
	
	if (avatar)
		_avatarView.image = avatar;
	else
		_avatarView.image = [NSImage imageNamed:NSImageNameUser];
	
	if ([name length] > 0)
		self.textField.stringValue = name;
	else
		self.textField.stringValue = @"-";
	
	if ([text length] > 0)
		_unreadField.stringValue = text;
	else
		_unreadField.stringValue = @"";
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
