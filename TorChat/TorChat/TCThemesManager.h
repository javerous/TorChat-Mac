/*
 *  TCThemesManager.h
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

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

// Chat keys.
#define TCThemeChatSnippetsKey				@"Snippets"
#define TCThemeChatSnippetLocalErrorKey		@"LocalMessageError"
#define TCThemeChatSnippetLocalMessageKey	@"LocalMessage"
#define TCThemeChatSnippetRemoteMessageKey	@"RemoteMessage"
#define TCThemeChatSnippetStatusKey			@"Status"
#define TCThemeChatSnippetCSSKey			@"CSS"

#define TCThemeChatPropertiesKey			@"Properties"
#define TCThemeChatPropertyMinHeightKey		@"Min-Height"

#define TCThemeChatResourcesKey				@"Resources"
#define TCThemeChatResourceDataKey			@"data"
#define TCThemeChatResourceMIMEKey			@"mime"



/*
** Forward
*/
#pragma mark - Forward

@class TCTheme;


/*
** TCThemesManager
*/
#pragma mark - TCThemesManager

@interface TCThemesManager : NSObject

// -- Instance --
+ (instancetype)sharedManager;

// -- Themes --
- (NSArray *)themes;
- (nullable TCTheme *)themeForIdentifier:(NSString *)identifier;

@end



/*
** TCTheme
*/
#pragma mark - TCTheme

@interface TCTheme : NSObject

@property (atomic, readonly) NSString *identifier;

@property (atomic, readonly) NSDictionary *chatTheme;

@end


NS_ASSUME_NONNULL_END
