/*
 *  TCConfigApp.h
 *
 *  Copyright 2019 Avérous Julien-Pierre
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


NS_ASSUME_NONNULL_BEGIN


/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, TCConfigTitle) {
	TCConfigTitleIdentifier	= 0,
	TCConfigTitleName		= 1
};

typedef NS_ENUM(unsigned int, TCConfigMode) {
	TCConfigModeCustom,
	TCConfigModeBundled
};


/*
** TCConfigApp
*/
#pragma mark - TCConfigApp

@protocol TCConfigApp <TCConfigCore>

// -- Mode --
@property TCConfigMode mode;

// -- Title --
@property (assign, atomic) TCConfigTitle modeTitle;

// -- Theme --
@property (nullable, atomic) NSString *themeIdentifier;

// -- Transcript --
@property (assign, atomic) BOOL saveTranscript;

- (void)addTranscriptForBuddyIdentifier:(NSString *)identifier message:(TCChatMessage *)message completionHandler:(void (^)(int64_t msgID))handler;

- (void)transcriptBuddiesIdentifiersWithCompletionHandler:(void (^)(NSArray * _Nullable buddiesIdentifiers))handler;
- (void)transcriptMessagesForBuddyIdentifier:(NSString *)identifier beforeMessageID:(NSNumber *)msgId limit:(NSUInteger)limit completionHandler:(void (^)(NSArray * _Nullable messages))handler;

- (void)transcriptRemoveMessagesForBuddyIdentifier:(NSString *)identifier;
- (void)transcriptRemoveMessageForID:(int64_t)msgID;

- (BOOL)transcriptMessagesIDBoundariesForBuddyIdentifier:(NSString *)identifier firstMessageID:(int64_t *)firstID lastMessageID:(int64_t *)lastID;

// -- General --
- (void)setGeneralSettingValue:(id)value forKey:(NSString *)key;
- (nullable id)generalSettingValueForKey:(NSString *)key;

@end


NS_ASSUME_NONNULL_END
