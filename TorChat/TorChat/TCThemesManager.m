/*
 *  TCThemesManager.m
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

#import "TCThemesManager.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TCThemeIdentifierKey	@"Identifier"
#define TCThemeChatKey			@"Chat"



/*
** TCTheme
*/
#pragma mark - TCTheme

@interface TCTheme ()

@property (atomic) NSString *identifier;

@property (atomic) NSDictionary *chatTheme;

@end

@implementation TCTheme

@end



/*
** TCThemesManager
*/
#pragma mark - TCThemesManager

@implementation TCThemesManager
{
	NSMutableArray *_themes;
}


/*
** TCThemesManager - Instance
*/
#pragma mark - TCThemesManager - Instance

+ (TCThemesManager*)sharedManager
{
	static dispatch_once_t	onceToken;
	static TCThemesManager	*shr;
	
	dispatch_once(&onceToken, ^{
		shr = [TCThemesManager new];
	});
	
	return shr;
}

- (instancetype)init
{
	self = [super init];
	
	if (self)
	{
		_themes = [[NSMutableArray alloc] init];
		
		[self loadThemeAtPath:[[NSBundle mainBundle] pathForResource:@"ThemeFlat" ofType:@"plist"]];
		[self loadThemeAtPath:[[NSBundle mainBundle] pathForResource:@"ThemeAqua" ofType:@"plist"]];
	
		NSAssert(_themes.count > 0, @"can't load any theme");
	}
	
	return self;
}



/*
** TCThemesManager - Load
*/
#pragma mark - TCThemesManager - Load

- (void)loadThemeAtPath:(nullable NSString *)path
{
	if (!path)
		return;
	
	// Read data.
	NSData *data = [NSData dataWithContentsOfFile:(NSString *)path];
	
	if (!data)
		return;
	
	// Parse plist.
	id plist = [NSPropertyListSerialization propertyListWithData:data options:NSPropertyListImmutable format:NULL error:NULL];
	
	if (!plist || [plist isKindOfClass:[NSDictionary class]] == NO)
		return;
	
	// Parse theme.
	NSDictionary	*root = plist;
	TCTheme			*theme = [[TCTheme alloc] init];
	
	NSString		*identifier = root[TCThemeIdentifierKey];
	NSDictionary	*chatTheme = root[TCThemeChatKey];
	
	if (!identifier || !chatTheme)
		return;

	theme.identifier = identifier;
	theme.chatTheme = chatTheme;
	
	[_themes addObject:theme];
}



/*
** TCThemesManager - Themes
*/
#pragma mark - TCThemesManager - Themes

- (NSArray *)themes
{
	return _themes;
}

- (nullable TCTheme *)themeForIdentifier:(NSString *)identifier
{
	NSAssert(identifier, @"identifier is nil");
	
	for (TCTheme *theme in _themes)
	{
		if ([theme.identifier isEqualToString:identifier])
			return theme;
	}
	
	return nil;
}

@end


NS_ASSUME_NONNULL_END
