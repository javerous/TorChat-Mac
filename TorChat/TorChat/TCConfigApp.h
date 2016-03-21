/*
 *  TCConfigApp.h
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

#import "TCConfigCore.h"

#import "TCChatMessage.h"


/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCConfigTitleIdentifier	= 0,
	TCConfigTitleName		= 1
} TCConfigTitle;



/*
** TCConfigApp
*/
#pragma mark - TCConfigApp

@protocol TCConfigApp <TCConfigCore>

// -- Title --
@property (assign, atomic) TCConfigTitle modeTitle;

// -- Transcript --
@property (assign, atomic) BOOL saveTranscript;

- (void)addTranscriptForBuddyIdentifier:(NSString *)identifier message:(TCChatMessage *)message completionHandler:(void (^)(int64_t msgID))handler;

- (void)transcriptBuddiesIdentifiersWithCompletionHandler:(void (^)(NSArray *buddiesIdentifiers))handler;
- (void)transcriptMessagesForBuddyIdentifier:(NSString *)identifier beforeMessageID:(NSNumber *)msgId limit:(NSUInteger)limit completionHandler:(void (^)(NSArray *messages))handler;

- (void)transcriptRemoveMessagesForBuddyIdentifier:(NSString *)identifier;
- (void)transcriptRemoveMessageForID:(int64_t)msgID;

- (int64_t)transcriptLastMessageIDForBuddyIdentifier:(NSString *)identifier;

@end
