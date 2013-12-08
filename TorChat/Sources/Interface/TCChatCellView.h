//
//  TCChatCellView.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 09/08/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import <Cocoa/Cocoa.h>


/*
** Defines
*/
#pragma mark - Defines

#define TCChatCellAvatarKey		@"avatar"
#define TCChatCellNameKey		@"name"
#define TCChatCellChatTextKey	@"chat_text"



/*
** TCChatCellView
*/
#pragma mark - TCChatCellView

@interface TCChatCellView : NSTableCellView

// -- Content --
- (void)setContent:(NSDictionary *)content;

@end
