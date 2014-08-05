/*
 *  TCConfigPlist.m
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


#import "TCConfigPlist.h"

#import "NSString+TCExtension.h"

#import "TCImage.h"


/*
** Defines
*/
#pragma mark - Defines

// -- Config Keys --
#define TCCONF_KEY_TOR_ADDRESS		@"tor_address"
#define TCCONF_KEY_TOR_PORT			@"tor_socks_port"
#define TCCONF_KEY_TOR_PATH			@"tor_path"
#define TCCONF_KEY_TOR_DATA_PATH	@"tor_data_path"

#define TCCONF_KEY_IM_ADDRESS		@"im_address"
#define TCCONF_KEY_IM_PORT			@"im_in_port"

#define TCCONF_KEY_DOWN_FOLDER		@"download_path"

#define TCCONF_KEY_MODE				@"mode"

#define TCCONF_KEY_PROFILE_NAME		@"profile_name"
#define TCCONF_KEY_PROFILE_TEXT		@"profile_text"
#define TCCONF_KEY_PROFILE_AVATAR	@"profile_avatar"

#define TCCONF_KEY_CLIENT_VERSION	@"client_version"
#define TCCONF_KEY_CLIENT_NAME		@"client_name"

#define TCCONF_KEY_BUDDIES			@"buddies"

#define TCCONF_KEY_BLOCKED			@"blocked"

#define TCCONF_KEY_UI_TITLE			@"title"

// > Paths
#define TCCONF_KEY_PATHS					@"paths"

#define TCCONF_KEY_PATH_TOR_BIN				@"tor_bin"
#define TCCONF_KEY_PATH_TOR_DARA			@"tor_data"
#define TCCONF_KEY_PATH_TOR_IDENTITY		@"tor_identity"
#define TCCONF_KEY_PATH_TOR_DOWNLOAD		@"tor_download"

#define TCCONF_KEY_PATH_PLACE				@"place"
#define TCCONF_VALUE_PATH_PLACE_REFERAL		@"<referal>"
#define TCCONF_VALUE_PATH_PLACE_STANDARD	@"<standard>"
#define TCCONF_VALUE_PATH_PLACE_ABSOLUTE	@"<absolute>"

#define TCCONF_KEY_PATH_SUBPATH				@"subpath"



/*
** TCConfigPlist - Private
*/
#pragma mark - TCConfigPlist - Private

@interface TCConfigPlist ()
{
	// Vars
	NSString			*_fpath;
	NSMutableDictionary	*_fcontent;
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	id <TCConfigProxy>	_proxy;
#endif
}

- (NSMutableDictionary *)loadConfig:(NSData *)data;
- (void)saveConfig;

@end



/*
** TCConfigPlist
*/
#pragma mark - TCConfigPlist

@implementation TCConfigPlist


/*
** TCConfigPlist - Instance
*/
#pragma mark - TCConfigPlist - Instance

- (id)initWithFile:(NSString *)filepath
{
	self = [super init];
	
	if (self)
	{
		if (!filepath)
			return nil;
		
		NSFileManager	*mng = [NSFileManager defaultManager];
		NSString		*npath;
		NSData			*data = nil;
		
		// Resolve path
		npath = [filepath realPath];
		
		if (npath)
			filepath = npath;
		
		if (!filepath)
			return nil;
		
		// Hold path
		_fpath = filepath;
		
		// Load file
		if ([mng fileExistsAtPath:_fpath])
		{
			// Load config data
			data = [NSData dataWithContentsOfFile:_fpath];
			
			if (!data)
				return nil;
		}
		
		// Load config
		_fcontent = [self loadConfig:data];
		
		if (!_fcontent)
			return nil;
	}
	
	return self;
}

#if defined(PROXY_ENABLED) && PROXY_ENABLED

- (id)initWithFileProxy:(id <TCConfigProxy>)proxy
{
	self = [super init];
	
	if (self)
	{
		NSData *data = nil;
		
		// Hold proxy
		_proxy = proxy;
		
		// Load data
		data = [proxy configContent];
		
		// Load config
		_fcontent = [self loadConfig:data];
		
		if (!_fcontent)
			return nil;
	}
	
	return self;
}

#endif



/*
** TCConfigPlist - Tor
*/
#pragma mark - TCConfigPlist - Tor

- (NSString *)torAddress
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_TOR_ADDRESS];
	
	if (value)
		return value;
	else
		return @"localhost";
}

- (void)setTorAddress:(NSString *)address
{
	if (!address)
		return;
	
	[_fcontent setObject:address forKey:TCCONF_KEY_TOR_ADDRESS];
		
	// Save
	[self saveConfig];
}

- (uint16_t)torPort
{
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_TOR_PORT];
	
	if (value)
		return [value unsignedShortValue];
	else
		return 9050;
}

- (void)setTorPort:(uint16_t)port
{
	[_fcontent setObject:@(port) forKey:TCCONF_KEY_TOR_PORT];
	
	// Save
	[self saveConfig];
}

- (NSString *)torPath
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_TOR_PATH];
	
	if (value)
		return value;
	else
		return @"<tor>";
}

- (void)setTorPath:(NSString *)path
{
	if (!path)
		return;
	
	[_fcontent setObject:path forKey:TCCONF_KEY_TOR_PATH];
		
	// Save
	[self saveConfig];
}

- (NSString *)torDataPath
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_TOR_DATA_PATH];
	
	if (value)
		return value;
	else
		return @"tordata";
	
	return @"";
}

- (void)setTorDataPath:(NSString *)path
{
	if (!path)
		return;
	
	[_fcontent setObject:path forKey:TCCONF_KEY_TOR_DATA_PATH];
		
	// Save
	[self saveConfig];
}



/*
** TCConfigPlist - TorChat
*/
#pragma mark - TCConfigPlist - TorChat

- (NSString *)selfAddress
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_IM_ADDRESS];
	
	if (value)
		return value;
	else
		return @"xxx";
}

- (void)setSelfAddress:(NSString *)address
{
	if (!address)
		return;
	
	[_fcontent setObject:address forKey:TCCONF_KEY_IM_ADDRESS];
	
	// Save
	[self saveConfig];
}

- (uint16_t)clientPort
{
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_IM_PORT];
	
	if (value)
		return [value unsignedShortValue];
	else
		return 11009;
}

- (void)setClientPort:(uint16_t)port
{
	[_fcontent setObject:@(port) forKey:TCCONF_KEY_IM_PORT];
	
	// Save
	[self saveConfig];
}

- (NSString *)downloadFolder
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_DOWN_FOLDER];
	
	if (value)
		return value;
	else
		return [self localized:@"conf_download"];
}

- (void)setDownloadFolder:(NSString *)folder
{
		if (!folder)
			return;

	[_fcontent setObject:folder forKey:TCCONF_KEY_DOWN_FOLDER];
		
	// Save
	[self saveConfig];
}



/*
** TCConfigPlist - Mode
*/
#pragma mark - TCConfigPlist - Mode

- (TCConfigMode)mode
{
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_MODE];
	
	if (value)
	{
		int mode = [value unsignedShortValue];
		
		if (mode == TCConfigModeAdvanced)
			return TCConfigModeAdvanced;
		else if (mode == TCConfigModeBasic)
			return TCConfigModeBasic;
		
		return TCConfigModeAdvanced;
	}
	else
		return TCConfigModeAdvanced;
}

- (void)setMode:(TCConfigMode)mode
{
	[_fcontent setObject:@(mode) forKey:TCCONF_KEY_MODE];
	
	// Save
	[self saveConfig];
}



/*
** TCConfigPlist - Profile
*/
#pragma mark - TCConfigPlist - Profile

- (NSString *)profileName
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_PROFILE_NAME];
	
	if (value)
		return value;
	else
		return @"-";
}

- (void)setProfileName:(NSString *)name
{
	if (!name)
		return;
	
	[_fcontent setObject:name forKey:TCCONF_KEY_PROFILE_NAME];
		
	// Save
	[self saveConfig];
}

- (NSString *)profileText
{
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_PROFILE_TEXT];
	
	if (value)
		return value;
	else
		return @"";
}

- (void)setProfileText:(NSString *)text
{
	if (!text)
		return;
	
	[_fcontent setObject:text forKey:TCCONF_KEY_PROFILE_TEXT];
		
	// Save
	[self saveConfig];

}

- (TCImage *)profileAvatar
{
	id avatar = [_fcontent objectForKey:TCCONF_KEY_PROFILE_AVATAR];
	
	if ([avatar isKindOfClass:[NSDictionary class]])
	{
		NSDictionary *describe = avatar;
		
		NSNumber		*width = [describe objectForKey:@"width"];
		NSNumber		*height = [describe objectForKey:@"width"];
		NSData			*bitmap = [describe objectForKey:@"bitmap"];
		NSData			*bitmapAlpha = [describe objectForKey:@"bitmap_alpha"];
		
		if ([width unsignedIntValue] == 0 || [height unsignedIntValue] == 0)
			return NULL;
		
		// Build TorChat core image
		TCImage *image = [[TCImage alloc] initWithWidth:[width unsignedIntValue] andHeight:[height unsignedIntValue]];
		
		[image setBitmap:bitmap];
		[image setBitmapAlpha:bitmapAlpha];
				
		if (image)
			[self setProfileAvatar:image]; // Replace by the new format.
		
		return image;
	}
	else if ([avatar isKindOfClass:[NSData class]])
	{
		NSImage *image = [[NSImage alloc] initWithData:avatar];
		TCImage *result = [[TCImage alloc] initWithImage:image];
		
		return result;
	}

	return nil;
}

- (void)setProfileAvatar:(TCImage *)picture
{
	// Remove avatar.
	if (!picture)
	{
		[_fcontent removeObjectForKey:TCCONF_KEY_PROFILE_AVATAR];
		
		// Save
		[self saveConfig];
		
		return;
	}
	
	// Get Cocoa image.
	NSImage *image = [picture imageRepresentation];
	
	if (!image)
		return;
	
	// Create PNG representation.
	NSData *tiffData = [image TIFFRepresentation];
	NSData *pngData;
	
	if (!tiffData)
		return;
	
	pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:nil];
	
	if (!pngData)
		return;

	[_fcontent setObject:pngData forKey:TCCONF_KEY_PROFILE_AVATAR];
	
	// Save
	[self saveConfig];
}



/*
** TCConfigPlist - Buddies
*/
#pragma mark - TCConfigPlist - Buddies

- (NSArray *)buddies
{
	return [[_fcontent objectForKey:TCCONF_KEY_BUDDIES] copy];
}

- (void)addBuddy:(NSString *)address alias:(NSString *)alias notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	if (!notes)
		notes = @"";
	
	// Get buddies list.
	NSMutableArray *buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	if (!buddies)
	{
		buddies = [[NSMutableArray alloc] init];
		[_fcontent setObject:buddies forKey:TCCONF_KEY_BUDDIES];
	}
	
	// Create buddy entry.
	NSMutableDictionary *buddy = [[NSMutableDictionary alloc] init];
	
	[buddy setObject:address forKey:TCConfigBuddyAddress];
	[buddy setObject:alias forKey:TCConfigBuddyAlias];
	[buddy setObject:notes forKey:TCConfigBuddyNotes];
	[buddy setObject:@"" forKey:TCConfigBuddyLastName];
	
	[buddies addObject:buddy];
		
	// Save & Release
	[self saveConfig];
}

- (BOOL)removeBuddy:(NSString *)address
{
	BOOL found = NO;
	
	if (!address)
		return NO;
	
	// Remove from Cocoa version
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:TCConfigBuddyAddress] isEqualToString:address])
		{
			[array removeObjectAtIndex:i];
			found = YES;
			break;
		}
	}
	
	// Save
	[self saveConfig];
	
	return found;
}

- (void)setBuddy:(NSString *)address alias:(NSString *)alias
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	// Change from Cocoa version
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:TCConfigBuddyAddress] isEqualToString:address])
		{
			[buddy setObject:alias forKey:TCConfigBuddyAlias];
			break;
		}
	}
	
	// Save
	[self saveConfig];
}

- (void)setBuddy:(NSString *)address notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!notes)
		notes = @"";
	
	// Change from Cocoa version
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:TCConfigBuddyAddress] isEqualToString:address])
		{
			[buddy setObject:notes forKey:TCConfigBuddyNotes];
			break;
		}
	}
	
	// Save
	[self saveConfig];
}

- (void)setBuddy:(NSString *)address lastProfileName:(NSString *)lastName
{
	if (!address)
		return;
	
	if (!lastName)
		lastName = @"";
	
	// Change from Cocoa version
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:TCConfigBuddyAddress] isEqualToString:address])
		{
			[buddy setObject:lastName forKey:TCConfigBuddyLastName];
			break;
		}
	}
	
	// Save
	[self saveConfig];
}

- (void)setBuddy:(NSString *)address lastProfileText:(NSString *)lastText
{
	if (!address)
		return;
	
	if (!lastText)
		lastText = @"";
	
	// Change from Cocoa version
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:TCConfigBuddyAddress] isEqualToString:address])
		{
			[buddy setObject:lastText forKey:TCConfigBuddyLastText];
			break;
		}
	}
	
	// Save
	[self saveConfig];
}

- (void)setBuddy:(NSString *)address lastProfileAvatar:(TCImage *)lastAvatar
{
	if (!address || !lastAvatar)
		return;
	
	// Create PNG representation.
	NSImage *image = [lastAvatar imageRepresentation];
	NSData	*tiffData = [image TIFFRepresentation];
	NSData	*pngData;
	
	if (!tiffData)
		return;
	
	pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:nil];
	
	if (!pngData)
		return;
	
	// Change item.
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:TCConfigBuddyAddress] isEqualToString:address])
		{
			[buddy setObject:pngData forKey:TCConfigBuddyLastAvatar];
			break;
		}
	}
	
	// Save
	[self saveConfig];
}

- (NSString *)getBuddyAlias:(NSString *)address
{
	if (!address)
		return @"";
	
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];

	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyAlias];
	}
	
	return @"";
}

- (NSString *)getBuddyNotes:(NSString *)address
{
	if (!address)
		return @"";
	
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyNotes];
	}
	
	return @"";
}

- (NSString *)getBuddyLastProfileName:(NSString *)address
{
	if (!address)
		return @"";
	
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyLastName];
	}
	
	return @"";
}

- (NSString *)getBuddyLastProfileText:(NSString *)address
{
	if (!address)
		return @"";
	
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyLastText];
	}
	
	return @"";
}

- (TCImage *)getBuddyLastProfileAvatar:(NSString *)address
{
	if (!address)
		return nil;
	
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
		{
			NSData *data = buddy[TCConfigBuddyLastAvatar];
			
			if (data)
			{
				NSImage *image = [[NSImage alloc] initWithData:data];
				
				return [[TCImage alloc] initWithImage:image];
			}
			else
				return nil;
		}
	}
	
	return nil;
}



/*
** TCConfigPlist - Blocked
*/
#pragma mark - TCConfigPlist - Blocked

- (NSArray *)blockedBuddies
{
	return [[_fcontent objectForKey:TCCONF_KEY_BLOCKED] copy];
}

- (BOOL)addBlockedBuddy:(NSString *)address
{
	// Add to cocoa version
	NSMutableArray *list = [_fcontent objectForKey:TCCONF_KEY_BLOCKED];
	
	if (list && [list indexOfObject:address] != NSNotFound)
		return NO;
	
	if (!list)
	{
		list = [[NSMutableArray alloc] init];
		[_fcontent setObject:list forKey:TCCONF_KEY_BLOCKED];
	}
	
	[list addObject:address];
	
	// Save & Release
	[self saveConfig];
	
	return YES;
}

- (BOOL)removeBlockedBuddy:(NSString *)address
{
	BOOL found = NO;
	
	if (!address)
		return NO;
	
	// Remove from Cocoa version
	NSMutableArray	*array = [_fcontent objectForKey:TCCONF_KEY_BLOCKED];
	NSUInteger		i, cnt = [array count];
	
	for (i = 0; i < cnt; i++)
	{
		NSString *buddy = [array objectAtIndex:i];
		
		if ([buddy isEqualToString:address])
		{
			[array removeObjectAtIndex:i];
			found = YES;
			break;
		}
	}

	// Save
	[self saveConfig];
	
	return found;
}



/*
** TCConfigPlist - UI
*/
#pragma mark - TCConfigPlist - UI

- (TCConfigTitle)modeTitle
{
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_UI_TITLE];
	
	if (!value)
		return TCConfigTitleAddress;
	
	return (TCConfigTitle)[value unsignedShortValue];
}

- (void)setModeTitle:(TCConfigTitle)mode
{
	[_fcontent setObject:@(mode) forKey:TCCONF_KEY_UI_TITLE];
	
	// Save
	[self saveConfig];
}



/*
** TCConfigPlist - Client
*/
#pragma mark - TCConfigPlist - Client

- (NSString *)clientVersion:(TCConfigGet)get
{
	switch (get)
	{
		case TCConfigGetDefault:
		{
			NSString *version = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			
			if (version)
				return version;
			
			return @"";
		}
			
		case TCConfigGetDefined:
		{
			NSString *value = [_fcontent objectForKey:TCCONF_KEY_CLIENT_VERSION];
			
			if (value)
				return value;
			
			return @"";
		}
			
		case TCConfigGetReal:
		{
			NSString *value = [self clientVersion:TCConfigGetDefined];
			
			if ([value length] == 0)
				value = [self clientVersion:TCConfigGetDefault];
			
			return value;
		}
	}
	
	return @"";
}

- (void)setClientVersion:(NSString *)version
{
	if (!version)
		return;

	[_fcontent setObject:version forKey:TCCONF_KEY_CLIENT_VERSION];
		
	// Save
	[self saveConfig];
}

- (NSString *)clientName:(TCConfigGet)get
{
	switch (get)
	{
		case TCConfigGetDefault:
		{
			return @"TorChat for Mac";
		}
			
		case TCConfigGetDefined:
		{
			NSString *value = [_fcontent objectForKey:TCCONF_KEY_CLIENT_NAME];
			
			if (value)
				return value;
			
			return @"";
		}
			
		case TCConfigGetReal:
		{
			NSString *value = [self clientName:TCConfigGetDefined];
			
			if ([value length] == 0)
				value = [self clientName:TCConfigGetDefault];
			
			return value;
		}
	}
	
	return @"";
}

- (void)setClientName:(NSString *)name
{
	if (!name)
		return;
	
	[_fcontent setObject:name forKey:TCCONF_KEY_CLIENT_NAME];
		
	// Save
	[self saveConfig];
}



/*
** TCConfigPlist - Paths
*/
#pragma mark - TCConfigPlist - Paths

- (NSString *)pathForDomain:(TConfigPathDomain)domain
{
	NSString *pathKey = nil;
	
	NSSearchPathDirectory	standardPathDirectory;
	NSString				*standardSubPath = nil;
	NSString				*referalSubPath = nil;

	// Handle domain.
	switch (domain)
	{
		case TConfigPathDomainReferal:
		{
			// Referal = configuration path file directory.
			return [_fpath stringByDeletingLastPathComponent];
		}
		
		case TConfigPathDomainTorBinary:
		{
			pathKey = TCCONF_KEY_PATH_TOR_BIN;
			standardPathDirectory = NSApplicationSupportDirectory;
			standardSubPath = @"TorChat/Tor/";
			referalSubPath = @"tordata/bin/";
			break;
		}
		
		case TConfigPathDomainTorData:
		{
			pathKey = TCCONF_KEY_PATH_TOR_DARA;
			standardPathDirectory = NSApplicationSupportDirectory;
			standardSubPath = @"TorChat/TorData/";
			referalSubPath = @"tordata/";
			break;
		}
		
		case TConfigPathDomainTorIdentity:
		{
			pathKey = TCCONF_KEY_PATH_TOR_IDENTITY;
			standardPathDirectory = NSApplicationSupportDirectory;
			standardSubPath = @"TorChat/TorIdentity/";
			referalSubPath = @"tordata/hidden/";
			break;
		}
		
		case TConfigPathDomainDownload:
		{
			pathKey = TCCONF_KEY_PATH_TOR_DOWNLOAD;
			standardPathDirectory = NSDownloadsDirectory;
			standardSubPath = @"TorChat/";
			referalSubPath = @"Downloads/";
			break;
		}
	}
	
	if (!pathKey)
		return nil;
	
	// Handle places.
	NSMutableDictionary *domainConfig = _fcontent[TCCONF_KEY_PATHS][pathKey];
	NSString			*domainPlace = domainConfig[TCCONF_KEY_PATH_PLACE];
	NSString			*domainSubpath = domainConfig[TCCONF_KEY_PATH_SUBPATH];

	if (!domainPlace)
		domainPlace = TCCONF_VALUE_PATH_PLACE_REFERAL;
	
	if ([domainPlace isEqualToString:TCCONF_VALUE_PATH_PLACE_REFERAL])
	{
		NSString *path = [self pathForDomain:TConfigPathDomainReferal];
		
		if (domainSubpath)
			return [path stringByAppendingPathComponent:domainSubpath];
		else
			return [path stringByAppendingPathComponent:referalSubPath];
	}
	else if ([domainPlace isEqualToString:TCCONF_VALUE_PATH_PLACE_STANDARD])
	{
		NSURL *url = [[NSFileManager defaultManager] URLForDirectory:standardPathDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
		
		if (!url)
			return nil;
		
		url = [url URLByAppendingPathComponent:standardSubPath isDirectory:YES];
		
		if (!url)
			return nil;
		
		return [url path];
	}
	else if ([domainPlace isEqualToString:TCCONF_VALUE_PATH_PLACE_ABSOLUTE])
	{
		return domainSubpath;
	}
	
	return nil;
}

- (BOOL)setDomain:(TConfigPathDomain)domain place:(TConfigPathPlace)place subpath:(NSString *)subpath
{
	// Handle domain.
	NSString *pathKey = nil;

	switch (domain)
	{
		case TConfigPathDomainReferal:
		{
			NSString *newPath = @"";
#warning FIXME Deplace configuration file
			
			return NO;
		}
			
		case TConfigPathDomainTorBinary:
		{
			pathKey = TCCONF_KEY_PATH_TOR_BIN;
			break;
		}
			
		case TConfigPathDomainTorData:
		{
			pathKey = TCCONF_KEY_PATH_TOR_DARA;
			break;
		}
			
		case TConfigPathDomainTorIdentity:
		{
			pathKey = TCCONF_KEY_PATH_TOR_IDENTITY;
			break;
		}
			
		case TConfigPathDomainDownload:
		{
			pathKey = TCCONF_KEY_PATH_TOR_DOWNLOAD;
			break;
		}
	}
	
	// Handle paths.
	NSMutableDictionary *paths = _fcontent[TCCONF_KEY_PATHS];
	
	if (!paths)
	{
		paths = [[NSMutableDictionary alloc] init];
		
		_fcontent[TCCONF_KEY_PATHS] = paths;
	}
	
	// Handle places.
	NSMutableDictionary *domainConfig = paths[pathKey];
	
	if (!domainConfig)
	{
		domainConfig = [[NSMutableDictionary alloc] init];
		
		paths[pathKey] = domainConfig;
	}
	
	if (!subpath)
		[domainConfig removeObjectForKey:pathKey];
	
	switch (place)
	{
		case TConfigPathPlaceReferal:
			domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_REFERAL;
			break;
			
		case TConfigPathPlaceStandard:
			domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_STANDARD;
			break;
			
		case TConfigPathPlaceAbsolute:
			domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_ABSOLUTE;
			break;
	}
	
	// Save
	[self saveConfig];
	
	return YES;
}



/*
** TCConfigPlist - Tools
*/
#pragma mark - TCConfigPlist - Tools

- (NSString *)realPath:(NSString *)path
{
	if ([path length] == 0)
		return @"";
	
	if ([path isEqualToString:@"<tor>"])
	{
		NSString *rpath = [[NSBundle mainBundle] pathForResource:@"tor" ofType:@""];
		
		if (rpath)
			return rpath;
		else
			return @"cant_find_tor";
	}
	else if ([path characterAtIndex:0] == '~')
	{
		return [path stringByExpandingTildeInPath];
	}
	else if ([path characterAtIndex:0] == '/')
	{
		return path;
	}
	else
	{
		NSString *rpath = nil;
		
#if defined(PROXY_ENABLED) && PROXY_ENABLED
		
		// Build path relative to desktop directory
		if (!rpath)
			rpath = [[@"~/Desktop" stringByExpandingTildeInPath] stringByAppendingPathComponent:path];
#endif
		
		// Build path relative to configuration directory
		if (!rpath)
			rpath = [[_fpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:path];
		
		// Build path relative to temporary directory
		if (!rpath)
			rpath = [@"/tmp" stringByAppendingPathComponent:path];
		
		return rpath;
	}
}



/*
** TCConfigPlist - Localization
*/
#pragma mark - TCConfigPlist - Localization

- (NSString *)localized:(NSString *)key
{
	NSString *local = nil;
	
	if (!key)
		return @"";
	
	local = NSLocalizedString(key, @"");
	
	if ([local length] == 0)
		return key;
	
	return local;
}



/*
** TCConfigPlist - Helpers
*/
#pragma mark - TCConfigPlist - Helpers

- (NSMutableDictionary *)loadConfig:(NSData *)data
{
	NSMutableDictionary	*content;
	
	// Parse plist
	if (data)
		content = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:nil errorDescription:nil];
	else
		content = [NSMutableDictionary dictionary];
	
	// Check content
	if (!content)
		return nil;
	
	if ([content isKindOfClass:[NSDictionary class]] == NO)
		return nil;

	return content;
}

- (void)saveConfig
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:_fcontent format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
	
	if (!data)
		return;
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	
	// Save by using proxy
	if (_proxy)
	{
		@try
		{
			[_proxy setConfigContent:data];
		}
		@catch (NSException *exception)
		{
			_proxy = nil;
			
			NSLog(@"Configuration proxy unavailable");
		}
	}
	
#endif
	
	// Save by using file
	if (_fpath)
		[data writeToFile:_fpath atomically:YES];
}

@end
