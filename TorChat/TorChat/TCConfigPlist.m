/*
 *  TCConfigPlist.m
 *
<<<<<<< HEAD
 *  Copyright 2014 Avérous Julien-Pierre
=======
 *  Copyright 2016 Avérous Julien-Pierre
>>>>>>> javerous/master
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

<<<<<<< HEAD

=======
>>>>>>> javerous/master
#import "TCConfigPlist.h"

#import "NSString+TCPathExtension.h"

#import "TCImage.h"


/*
** Defines
*/
#pragma mark - Defines

// -- Version --
#define TCConfigVersion1			1
#define TCConfigVersion2			2

#define TCConfigVersionCurrent		TCConfigVersion2


// -- Config Keys --
// > Config
#define TCCONF_KEY_VERSION			@"version"

// > General
#define TCCONF_KEY_TOR_ADDRESS		@"tor_address"
#define TCCONF_KEY_TOR_PORT			@"tor_socks_port"

#define TCCONF_KEY_IM_ADDRESS		@"im_address"
#define TCCONF_KEY_IM_PORT			@"im_in_port"

#define TCCONF_KEY_MODE				@"mode"

#define TCCONF_KEY_PROFILE_NAME		@"profile_name"
#define TCCONF_KEY_PROFILE_TEXT		@"profile_text"
#define TCCONF_KEY_PROFILE_AVATAR	@"profile_avatar"

#define TCCONF_KEY_CLIENT_VERSION	@"client_version"
#define TCCONF_KEY_CLIENT_NAME		@"client_name"

#define TCCONF_KEY_BUDDIES			@"buddies"

#define TCCONF_KEY_BLOCKED			@"blocked"

// > UI
#define TCCONF_KEY_UI_TITLE			@"title"

// > Paths
#define TCCONF_KEY_PATHS					@"paths"

#define TCCONF_KEY_PATH_TOR_BIN				@"tor_bin"
#define TCCONF_KEY_PATH_TOR_DATA			@"tor_data"
#define TCCONF_KEY_PATH_TOR_IDENTITY		@"tor_identity"
#define TCCONF_KEY_PATH_DOWNLOADS			@"downloads"

<<<<<<< HEAD
#define TCCONF_KEY_PATH_PLACE				@"place"
#define TCCONF_VALUE_PATH_PLACE_REFERAL		@"<referal>"
#define TCCONF_VALUE_PATH_PLACE_STANDARD	@"<standard>"
#define TCCONF_VALUE_PATH_PLACE_ABSOLUTE	@"<absolute>"
=======
#define TCCONF_KEY_PATH_TYPE				@"type"
#define TCCONF_VALUE_PATH_TYPE_REFERAL		@"<referal>"
#define TCCONF_VALUE_PATH_TYPE_STANDARD		@"<standard>"
#define TCCONF_VALUE_PATH_TYPE_ABSOLUTE		@"<absolute>"
>>>>>>> javerous/master

#define TCCONF_KEY_PATH_SUBPATH				@"subpath"



/*
** TCConfigPlist - Private
*/
#pragma mark - TCConfigPlist - Private

@interface TCConfigPlist ()
{
<<<<<<< HEAD
	// Vars
	NSString			*_fpath;
	NSMutableDictionary	*_fcontent;
	
=======
	dispatch_queue_t	_localQueue;
	
	NSString			*_fpath;
	NSMutableDictionary	*_fcontent;
	
	NSMutableDictionary *_pathObservers;

	BOOL				_isDirty;
	dispatch_source_t	_timer;

>>>>>>> javerous/master
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	id <TCConfigProxy>	_proxy;
#endif
}

<<<<<<< HEAD
- (NSMutableDictionary *)loadConfig:(NSData *)data;
- (void)saveConfig;
=======
>>>>>>> javerous/master

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
		
<<<<<<< HEAD
		// Resolve path
=======
		// Resolve path.
>>>>>>> javerous/master
		npath = [filepath stringByCanonizingPath];
		
		if (npath)
			filepath = npath;
		
		if (!filepath)
			return nil;
		
<<<<<<< HEAD
		// Hold path
		_fpath = filepath;
		
		// Load file
=======
		// Hold path.
		_fpath = filepath;
		
		// Load file.
>>>>>>> javerous/master
		if ([mng fileExistsAtPath:_fpath])
		{
			// Load config data
			data = [NSData dataWithContentsOfFile:_fpath];
			
			if (!data)
				return nil;
		}
		
<<<<<<< HEAD
		// Load config
=======
		// Load config.
>>>>>>> javerous/master
		_fcontent = [self loadConfig:data];
		
		if (!_fcontent)
			return nil;
<<<<<<< HEAD
=======
		
		// Create queue.
		_localQueue = dispatch_queue_create("com.torchat.app.config-plist", DISPATCH_QUEUE_CONCURRENT);
		
		// Save timer.
		_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);

		dispatch_source_set_timer(_timer, DISPATCH_TIME_FOREVER, 0, 0);
		
		dispatch_source_set_event_handler(_timer, ^{
			dispatch_source_set_timer(_timer, DISPATCH_TIME_FOREVER, 0, 0);
			
			if (_isDirty == NO)
				return;
			
			dispatch_barrier_async(_localQueue, ^{
				if ([self saveConfig:_fcontent toFile:_fpath])
					_isDirty = NO;
			});
		});
		
		dispatch_resume(_timer);
>>>>>>> javerous/master
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
		
<<<<<<< HEAD
		// Hold proxy
		_proxy = proxy;
		
		// Load data
		data = [proxy configContent];
		
		// Load config
=======
		// Hold proxy.
		_proxy = proxy;
		
		// Load data.
		data = [proxy configContent];
		
		// Load config.
>>>>>>> javerous/master
		_fcontent = [self loadConfig:data];
		
		if (!_fcontent)
			return nil;
<<<<<<< HEAD
=======
		
		// Create queue.
		_localQueue = dispatch_queue_create("com.torchat.app.config-plist", DISPATCH_QUEUE_CONCURRENT);
>>>>>>> javerous/master
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
<<<<<<< HEAD
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_TOR_ADDRESS];
=======
	__block NSString *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_TOR_ADDRESS];
	});
>>>>>>> javerous/master
	
	if (value)
		return value;
	else
		return @"localhost";
}

- (void)setTorAddress:(NSString *)address
{
	if (!address)
		return;
	
<<<<<<< HEAD
	[_fcontent setObject:address forKey:TCCONF_KEY_TOR_ADDRESS];
		
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:address forKey:TCCONF_KEY_TOR_ADDRESS];
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (uint16_t)torPort
{
<<<<<<< HEAD
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_TOR_PORT];
=======
	__block NSNumber *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_TOR_PORT];
	});
>>>>>>> javerous/master
	
	if (value)
		return [value unsignedShortValue];
	else
		return 9050;
}

- (void)setTorPort:(uint16_t)port
{
<<<<<<< HEAD
	[_fcontent setObject:@(port) forKey:TCCONF_KEY_TOR_PORT];
	
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:@(port) forKey:TCCONF_KEY_TOR_PORT];
		[self _markDirty];
	});
>>>>>>> javerous/master
}



/*
** TCConfigPlist - TorChat
*/
#pragma mark - TCConfigPlist - TorChat

- (NSString *)selfAddress
{
<<<<<<< HEAD
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_IM_ADDRESS];
=======
	__block NSString *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_IM_ADDRESS];
	});
>>>>>>> javerous/master
	
	if (value)
		return value;
	else
		return @"xxx";
}

- (void)setSelfAddress:(NSString *)address
{
	if (!address)
		return;
	
<<<<<<< HEAD
	[_fcontent setObject:address forKey:TCCONF_KEY_IM_ADDRESS];
	
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:address forKey:TCCONF_KEY_IM_ADDRESS];
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (uint16_t)clientPort
{
<<<<<<< HEAD
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_IM_PORT];
=======
	__block NSNumber *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_IM_PORT];
	});
>>>>>>> javerous/master
	
	if (value)
		return [value unsignedShortValue];
	else
		return 11009;
}

- (void)setClientPort:(uint16_t)port
{
<<<<<<< HEAD
	[_fcontent setObject:@(port) forKey:TCCONF_KEY_IM_PORT];
	
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:@(port) forKey:TCCONF_KEY_IM_PORT];
		[self _markDirty];
	});
>>>>>>> javerous/master
}



/*
** TCConfigPlist - Mode
*/
#pragma mark - TCConfigPlist - Mode

- (TCConfigMode)mode
{
<<<<<<< HEAD
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_MODE];
=======
	__block NSNumber *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_MODE];
	});
>>>>>>> javerous/master
	
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
<<<<<<< HEAD
	[_fcontent setObject:@(mode) forKey:TCCONF_KEY_MODE];
	
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:@(mode) forKey:TCCONF_KEY_MODE];
		[self _markDirty];
	});
>>>>>>> javerous/master
}



/*
** TCConfigPlist - Profile
*/
#pragma mark - TCConfigPlist - Profile

- (NSString *)profileName
{
<<<<<<< HEAD
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_PROFILE_NAME];
=======
	__block NSString *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_PROFILE_NAME];
	});
>>>>>>> javerous/master
	
	if (value)
		return value;
	else
		return @"-";
}

- (void)setProfileName:(NSString *)name
{
	if (!name)
		return;
	
<<<<<<< HEAD
	[_fcontent setObject:name forKey:TCCONF_KEY_PROFILE_NAME];
		
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:name forKey:TCCONF_KEY_PROFILE_NAME];
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (NSString *)profileText
{
<<<<<<< HEAD
	NSString *value = [_fcontent objectForKey:TCCONF_KEY_PROFILE_TEXT];
=======
	__block NSString *value;
 
	dispatch_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_PROFILE_TEXT];
	});
>>>>>>> javerous/master
	
	if (value)
		return value;
	else
		return @"";
}

- (void)setProfileText:(NSString *)text
{
	if (!text)
		return;
	
<<<<<<< HEAD
	[_fcontent setObject:text forKey:TCCONF_KEY_PROFILE_TEXT];
		
	// Save
	[self saveConfig];

=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:text forKey:TCCONF_KEY_PROFILE_TEXT];
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (TCImage *)profileAvatar
{
<<<<<<< HEAD
	id avatar = [_fcontent objectForKey:TCCONF_KEY_PROFILE_AVATAR];
=======
	__block id avatar;
 
	dispatch_sync(_localQueue, ^{
		avatar = [_fcontent objectForKey:TCCONF_KEY_PROFILE_AVATAR];
	});
>>>>>>> javerous/master
	
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
<<<<<<< HEAD
		[_fcontent removeObjectForKey:TCCONF_KEY_PROFILE_AVATAR];
		
		// Save
		[self saveConfig];
		
=======
		dispatch_barrier_async(_localQueue, ^{
			[_fcontent removeObjectForKey:TCCONF_KEY_PROFILE_AVATAR];
			[self _markDirty];
		});

>>>>>>> javerous/master
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
	
<<<<<<< HEAD
	pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:nil];
=======
	pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:@{ }];
>>>>>>> javerous/master
	
	if (!pngData)
		return;

<<<<<<< HEAD
	[_fcontent setObject:pngData forKey:TCCONF_KEY_PROFILE_AVATAR];
	
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:pngData forKey:TCCONF_KEY_PROFILE_AVATAR];
		[self _markDirty];
	});
>>>>>>> javerous/master
}



/*
** TCConfigPlist - Buddies
*/
#pragma mark - TCConfigPlist - Buddies

- (NSArray *)buddies
{
<<<<<<< HEAD
	return [[_fcontent objectForKey:TCCONF_KEY_BUDDIES] copy];
=======
	__block NSArray *buddies;
	
	dispatch_sync(_localQueue, ^{
		buddies = [[_fcontent objectForKey:TCCONF_KEY_BUDDIES] copy];
	});
	
	return buddies;
>>>>>>> javerous/master
}

- (void)addBuddy:(NSString *)address alias:(NSString *)alias notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
	if (!notes)
		notes = @"";
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_async(_localQueue, ^{
		
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (BOOL)removeBuddy:(NSString *)address
{
<<<<<<< HEAD
	BOOL found = NO;
=======
	__block BOOL found = NO;
>>>>>>> javerous/master
	
	if (!address)
		return NO;
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_sync(_localQueue, ^{
		
		// Remove from Cocoa version.
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
	
	return found;
}

- (void)setBuddy:(NSString *)address alias:(NSString *)alias
{
	if (!address)
		return;
	
	if (!alias)
		alias = @"";
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_async(_localQueue, ^{
		
		// Change from Cocoa version.
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (void)setBuddy:(NSString *)address notes:(NSString *)notes
{
	if (!address)
		return;
	
	if (!notes)
		notes = @"";
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_async(_localQueue, ^{
	
		// Change from Cocoa version.
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (void)setBuddy:(NSString *)address lastProfileName:(NSString *)lastName
{
	if (!address)
		return;
	
	if (!lastName)
		lastName = @"";
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_async(_localQueue, ^{
		
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (void)setBuddy:(NSString *)address lastProfileText:(NSString *)lastText
{
	if (!address)
		return;
	
	if (!lastText)
		lastText = @"";
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_async(_localQueue, ^{
		
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
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
	
<<<<<<< HEAD
	pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:nil];
=======
	pngData = [[[NSBitmapImageRep alloc] initWithData:tiffData] representationUsingType:NSPNGFileType properties:@{ }];
>>>>>>> javerous/master
	
	if (!pngData)
		return;
	
	// Change item.
<<<<<<< HEAD
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
=======
	dispatch_barrier_async(_localQueue, ^{
		
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
		
		// Mark dirty.
		[self _markDirty];
	});
>>>>>>> javerous/master
}

- (NSString *)getBuddyAlias:(NSString *)address
{
	if (!address)
		return @"";
	
<<<<<<< HEAD
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];

	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyAlias];
	}
	
	return @"";
=======
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
		
		for (NSDictionary *buddy in buddies)
		{
			if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			{
				result = buddy[TCConfigBuddyAlias];
				return;
			}
		}
	});
	
	return result;
>>>>>>> javerous/master
}

- (NSString *)getBuddyNotes:(NSString *)address
{
	if (!address)
		return @"";
	
<<<<<<< HEAD
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyNotes];
	}
	
	return @"";
=======
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
		
		for (NSDictionary *buddy in buddies)
		{
			if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			{
				result = buddy[TCConfigBuddyNotes];
				return;
			}
		}
	});
	
	return result;
>>>>>>> javerous/master
}

- (NSString *)getBuddyLastProfileName:(NSString *)address
{
	if (!address)
		return @"";
	
<<<<<<< HEAD
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyLastName];
	}
	
	return @"";
=======
	__block NSString *result = @"";

	dispatch_sync(_localQueue, ^{
		
		NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
		
		for (NSDictionary *buddy in buddies)
		{
			if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			{
				result = buddy[TCConfigBuddyLastName];
				return;
			}
		}
	});
	
	return result;
>>>>>>> javerous/master
}

- (NSString *)getBuddyLastProfileText:(NSString *)address
{
	if (!address)
		return @"";
	
<<<<<<< HEAD
	NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
	
	for (NSDictionary *buddy in buddies)
	{
		if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			return buddy[TCConfigBuddyLastText];
	}
	
	return @"";
=======
	__block NSString *result = @"";
	
	dispatch_sync(_localQueue, ^{
		
		NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
		
		for (NSDictionary *buddy in buddies)
		{
			if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			{
				result = buddy[TCConfigBuddyLastText];
				return;
			}
		}
	});
	
	return result;
>>>>>>> javerous/master
}

- (TCImage *)getBuddyLastProfileAvatar:(NSString *)address
{
	if (!address)
		return nil;
	
<<<<<<< HEAD
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
=======
	__block NSData *result = nil;
	
	dispatch_sync(_localQueue, ^{
		NSArray	*buddies = [_fcontent objectForKey:TCCONF_KEY_BUDDIES];
		
		for (NSDictionary *buddy in buddies)
		{
			if ([buddy[TCConfigBuddyAddress] isEqualToString:address])
			{
				result = buddy[TCConfigBuddyLastAvatar];
				return;
			}
		}
	});
	
	
	if (result)
	{
		NSImage *image = [[NSImage alloc] initWithData:result];
		
		return [[TCImage alloc] initWithImage:image];
	}
	else
		return nil;
>>>>>>> javerous/master
}



/*
** TCConfigPlist - Blocked
*/
#pragma mark - TCConfigPlist - Blocked

- (NSArray *)blockedBuddies
{
<<<<<<< HEAD
	return [[_fcontent objectForKey:TCCONF_KEY_BLOCKED] copy];
=======
	__block NSArray *result;
	
	dispatch_sync(_localQueue, ^{
		result = [[_fcontent objectForKey:TCCONF_KEY_BLOCKED] copy];
	});
	
	return result;
>>>>>>> javerous/master
}

- (BOOL)addBlockedBuddy:(NSString *)address
{
<<<<<<< HEAD
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
=======
	__block BOOL result = NO;
	
	dispatch_barrier_sync(_localQueue, ^{
		
		// Add to cocoa version
		NSMutableArray *list = [_fcontent objectForKey:TCCONF_KEY_BLOCKED];
		
		if (list && [list indexOfObject:address] != NSNotFound)
			return;
		
		if (!list)
		{
			list = [[NSMutableArray alloc] init];
			[_fcontent setObject:list forKey:TCCONF_KEY_BLOCKED];
		}
		
		[list addObject:address];
		
		// Mark dirty.
		[self _markDirty];
		
		result = YES;
	});
	
	return result;
>>>>>>> javerous/master
}

- (BOOL)removeBlockedBuddy:(NSString *)address
{
<<<<<<< HEAD
	BOOL found = NO;
=======
	__block BOOL found = NO;
>>>>>>> javerous/master
	
	if (!address)
		return NO;
	
<<<<<<< HEAD
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
=======
	dispatch_barrier_sync(_localQueue, ^{
		
		// Remove from Cocoa version.
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

		// Mark dirty.
		[self _markDirty];
	});

>>>>>>> javerous/master
	
	return found;
}



/*
** TCConfigPlist - UI
*/
#pragma mark - TCConfigPlist - UI

- (TCConfigTitle)modeTitle
{
<<<<<<< HEAD
	NSNumber *value = [_fcontent objectForKey:TCCONF_KEY_UI_TITLE];
=======
	__block NSNumber *value;
 
	dispatch_barrier_sync(_localQueue, ^{
		value = [_fcontent objectForKey:TCCONF_KEY_UI_TITLE];
	});
>>>>>>> javerous/master
	
	if (!value)
		return TCConfigTitleAddress;
	
	return (TCConfigTitle)[value unsignedShortValue];
}

- (void)setModeTitle:(TCConfigTitle)mode
{
<<<<<<< HEAD
	[_fcontent setObject:@(mode) forKey:TCCONF_KEY_UI_TITLE];
	
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:@(mode) forKey:TCCONF_KEY_UI_TITLE];
		[self _markDirty];
	});
>>>>>>> javerous/master
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
<<<<<<< HEAD
			NSString *value = [_fcontent objectForKey:TCCONF_KEY_CLIENT_VERSION];
=======
			__block NSString *value;
			
			dispatch_sync(_localQueue, ^{
				value = [_fcontent objectForKey:TCCONF_KEY_CLIENT_VERSION];
			});
>>>>>>> javerous/master
			
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

<<<<<<< HEAD
	[_fcontent setObject:version forKey:TCCONF_KEY_CLIENT_VERSION];
		
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:version forKey:TCCONF_KEY_CLIENT_VERSION];
		[self _markDirty];
	});
>>>>>>> javerous/master
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
<<<<<<< HEAD
			NSString *value = [_fcontent objectForKey:TCCONF_KEY_CLIENT_NAME];
=======
			__block NSString *value;
			
			dispatch_sync(_localQueue, ^{
				value = [_fcontent objectForKey:TCCONF_KEY_CLIENT_NAME];
			});
>>>>>>> javerous/master
			
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
	
<<<<<<< HEAD
	[_fcontent setObject:name forKey:TCCONF_KEY_CLIENT_NAME];
		
	// Save
	[self saveConfig];
=======
	dispatch_barrier_async(_localQueue, ^{
		[_fcontent setObject:name forKey:TCCONF_KEY_CLIENT_NAME];
		[self _markDirty];
	});
>>>>>>> javerous/master
}



/*
** TCConfigPlist - Paths
*/
#pragma mark - TCConfigPlist - Paths

<<<<<<< HEAD
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
			referalSubPath = @"tor/bin/";
			break;
		}
		
		case TConfigPathDomainTorData:
		{
			pathKey = TCCONF_KEY_PATH_TOR_DATA;
			standardPathDirectory = NSApplicationSupportDirectory;
			standardSubPath = @"TorChat/TorData/";
			referalSubPath = @"tor/data/";
			break;
		}
		
		case TConfigPathDomainTorIdentity:
		{
			pathKey = TCCONF_KEY_PATH_TOR_IDENTITY;
			standardPathDirectory = NSApplicationSupportDirectory;
			standardSubPath = @"TorChat/TorIdentity/";
			referalSubPath = @"tor/identity/";
			break;
		}
		
		case TConfigPathDomainDownloads:
		{
			pathKey = TCCONF_KEY_PATH_DOWNLOADS;
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
			// Check parameter.
			BOOL isDirectory = NO;
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:subpath isDirectory:&isDirectory] && isDirectory == NO)
				return NO;
			
			// Prepare move.
			NSString *configFileName = [_fpath lastPathComponent];
			NSString *newPath = [subpath stringByAppendingPathComponent:configFileName];
			
			// Move.
			if ([[NSFileManager defaultManager] moveItemAtPath:_fpath toPath:newPath error:nil] == NO)
				return NO;
			
			// Hold new path.
			_fpath = newPath;
			
			return YES;
		}
			
		case TConfigPathDomainTorBinary:
		{
			pathKey = TCCONF_KEY_PATH_TOR_BIN;
			break;
		}
			
		case TConfigPathDomainTorData:
		{
			pathKey = TCCONF_KEY_PATH_TOR_DATA;
			break;
		}
			
		case TConfigPathDomainTorIdentity:
		{
			pathKey = TCCONF_KEY_PATH_TOR_IDENTITY;
			break;
		}
			
		case TConfigPathDomainDownloads:
		{
			pathKey = TCCONF_KEY_PATH_DOWNLOADS;
=======
#pragma mark > Set

- (BOOL)setPathForComponent:(TCConfigPathComponent)component pathType:(TCConfigPathType)pathType path:(NSString *)path
{
	// Handle special referal component.
	if (component == TCConfigPathComponentReferal)
	{
		__block BOOL result = NO;
		
		dispatch_barrier_sync(_localQueue, ^{

			// Check parameter.
			BOOL isDirectory = NO;
			
			if ([[NSFileManager defaultManager] fileExistsAtPath:path isDirectory:&isDirectory] && isDirectory == NO)
				return;
			
			// Prepare move.
			NSString *configFileName = [_fpath lastPathComponent];
			NSString *newPath = [path stringByAppendingPathComponent:configFileName];
			
			// Move.
			if ([[NSFileManager defaultManager] moveItemAtPath:_fpath toPath:newPath error:nil] == NO)
				return;
			
			// Hold new path.
			_fpath = newPath;
			
			// Notify this component.
			[self _notifyPathChangeForComponent:TCConfigPathComponentReferal];
			
			// Notify components using this component.
			[self componentsEnumerateWithBlock:^(TCConfigPathComponent aComponent) {
				if ([self _pathTypeForComponent:aComponent] == TCConfigPathTypeReferal)
					[self _notifyPathChangeForComponent:aComponent];
			}];
			
			// Flag success.
			result = YES;
		});
		
		return result;
	}
	
	// Handle common components.
	dispatch_barrier_async(_localQueue, ^{
		
		// Handle paths.
		NSMutableDictionary *paths = _fcontent[TCCONF_KEY_PATHS];
		
		if (!paths)
		{
			paths = [[NSMutableDictionary alloc] init];
			
			_fcontent[TCCONF_KEY_PATHS] = paths;
		}
		
		// Handle components.
		NSString			*componentKey = [self componentKeyForComponent:component];
		NSMutableDictionary	*componentConfig = paths[componentKey];
		
		// > Create component if not exist.
		if (!componentConfig)
		{
			componentConfig = [[NSMutableDictionary alloc] init];
			
			paths[componentKey] = componentConfig;
		}
		
		// > Store / remove component subpath.
		if (path)
			componentConfig[TCCONF_KEY_PATH_SUBPATH] = path;
		else
			[componentConfig removeObjectForKey:TCCONF_KEY_PATH_SUBPATH];
		
		// > Store component path type.
		componentConfig[TCCONF_KEY_PATH_TYPE] = [self pathTypeValueForPathType:pathType];

		// > Mark dirty.
		[self _markDirty];
		
		// Notify.
		[self _notifyPathChangeForComponent:component];
	});
	
	return YES;
}


#pragma mark > Get

- (NSString *)pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath
{
	__block NSString *result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _pathForComponent:component fullPath:fullPath];
	});
	
	return result;
}

- (NSString *)_pathForComponent:(TCConfigPathComponent)component fullPath:(BOOL)fullPath
{
	// > localQueue <
	
	// Get default subpath.
	NSString	*standardSubPath = nil;
	NSString	*referalSubPath = nil;
	
	switch (component)
	{
		case TCConfigPathComponentReferal:
		{
			if (fullPath)
				return [_fpath stringByDeletingLastPathComponent];
			else
				return nil;
		}
			
		case TCConfigPathComponentTorBinary:
		{
			standardSubPath = @"/TorChat/Tor/";
			referalSubPath = @"/tor/bin/";
			break;
		}
			
		case TCConfigPathComponentTorData:
		{
			standardSubPath = @"/TorChat/TorData/";
			referalSubPath = @"/tor/data/";
			break;
		}
			
		case TCConfigPathComponentTorIdentity:
		{
			standardSubPath = @"/TorChat/TorIdentity/";
			referalSubPath = @"/tor/identity/";
			break;
		}
			
		case TCConfigPathComponentDownloads:
		{
			standardSubPath = @"/TorChat/";
			referalSubPath = @"/Downloads/";
>>>>>>> javerous/master
			break;
		}
	}
	
<<<<<<< HEAD
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
		[paths removeObjectForKey:pathKey];
	else
		domainConfig[TCCONF_KEY_PATH_SUBPATH] = subpath;
	
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
=======
	// Get component key.
	NSString *componentKey = [self componentKeyForComponent:component];
	
	if (!componentKey)
		return nil;
	
	// Get component config.
	NSDictionary	*componentConfig = _fcontent[TCCONF_KEY_PATHS][componentKey];
	TCConfigPathType	componentPathType = [self _pathTypeForComponent:component];
	NSString		*componentPath = componentConfig[TCCONF_KEY_PATH_SUBPATH];
 
	// Compose path according to path type.
	switch (componentPathType)
	{
		case TCConfigPathTypeReferal:
		{
			// > Get subpath.
			NSString *subPath;
			
			if (componentPath)
				subPath = componentPath;
			else
				subPath = referalSubPath;
			
			// > Compose path.
			if (fullPath)
			{
				NSString *path = [self _pathForComponent:TCConfigPathComponentReferal fullPath:YES];
				
				return [[path stringByAppendingPathComponent:subPath] stringByStandardizingPath];
			}
			else
				return subPath;
		}
			
		case TCConfigPathTypeStandard:
		{
			// > Compose path.
			if (fullPath)
			{
				// >> Get standard path directory.
				NSSearchPathDirectory standardPathDirectory;
				
				switch (component)
				{
					case TCConfigPathComponentReferal	: return nil; // never called.
					case TCConfigPathComponentTorBinary	: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentTorData	: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentTorIdentity: standardPathDirectory = NSApplicationSupportDirectory; break;
					case TCConfigPathComponentDownloads	: standardPathDirectory = NSDownloadsDirectory;	break;
				}
				
				// >> Get URL of the standard path directory.
				NSURL *url = [[NSFileManager defaultManager] URLForDirectory:standardPathDirectory inDomain:NSUserDomainMask appropriateForURL:nil create:YES error:nil];
				
				if (!url)
					return nil;
				
				// >> Create full path.
				url = [url URLByAppendingPathComponent:standardSubPath isDirectory:YES];
				
				if (!url)
					return nil;
				
				return [[url path] stringByStandardizingPath];
			}
			else
				return standardSubPath;
		}
			
		case TCConfigPathTypeAbsolute:
		{
			if (fullPath)
				return [componentPath stringByStandardizingPath];
			else
				return componentPath;
		}
	}
	
	return nil;
}


#pragma mark > Type

- (NSString *)pathTypeValueForPathType:(TCConfigPathType)pathType
{
	switch (pathType)
	{
		case TCConfigPathTypeReferal:
			return TCCONF_VALUE_PATH_TYPE_REFERAL;
			
		case TCConfigPathTypeStandard:
			return TCCONF_VALUE_PATH_TYPE_STANDARD;
			
		case TCConfigPathTypeAbsolute:
			return TCCONF_VALUE_PATH_TYPE_ABSOLUTE;
	}
	
	return nil;
}

- (TCConfigPathType)pathTypeForComponent:(TCConfigPathComponent)component
{
	__block TCConfigPathType result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _pathTypeForComponent:component];
	});
	
	return result;
}

- (TCConfigPathType)_pathTypeForComponent:(TCConfigPathComponent)component
{
	// > localQueue <
	
	NSString *componentKey = [self componentKeyForComponent:component];
	
	if (!componentKey)
		return TCConfigPathTypeReferal;
	
	NSDictionary	*componentConfig = _fcontent[TCCONF_KEY_PATHS][componentKey];
	NSString		*componentPathType = componentConfig[TCCONF_KEY_PATH_TYPE];
	
	if ([componentPathType isEqualToString:TCCONF_VALUE_PATH_TYPE_REFERAL])
		return TCConfigPathTypeReferal;
	else if ([componentPathType isEqualToString:TCCONF_VALUE_PATH_TYPE_STANDARD])
		return TCConfigPathTypeStandard;
	else if ([componentPathType isEqualToString:TCCONF_VALUE_PATH_TYPE_ABSOLUTE])
		return TCConfigPathTypeAbsolute;
	
	return TCConfigPathTypeReferal;
}


#pragma mark > Component

- (NSString *)componentKeyForComponent:(TCConfigPathComponent)component
{
	switch (component)
	{
		case TCConfigPathComponentReferal:
			return nil;
			
		case TCConfigPathComponentTorBinary:
			return TCCONF_KEY_PATH_TOR_BIN;
			
		case TCConfigPathComponentTorData:
			return TCCONF_KEY_PATH_TOR_DATA;
			
		case TCConfigPathComponentTorIdentity:
			return TCCONF_KEY_PATH_TOR_IDENTITY;
			
		case TCConfigPathComponentDownloads:
			return TCCONF_KEY_PATH_DOWNLOADS;
	}
	
	return nil;
}

- (void)componentsEnumerateWithBlock:(void (^)(TCConfigPathComponent component))block
{
	block(TCConfigPathComponentTorBinary);
	block(TCConfigPathComponentTorData);
	block(TCConfigPathComponentTorIdentity);
	block(TCConfigPathComponentDownloads);
}


#pragma mark > Observers

- (id)addPathObserverForComponent:(TCConfigPathComponent)component queue:(dispatch_queue_t)queue usingBlock:(dispatch_block_t)block
{
	// Check parameters.
	if (!block)
		return nil;
	
	if (!queue)
		queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	// Create result object.
	NSDictionary *result = @{ @"component" : @(component), @"queue" : queue, @"block" : block };
	
	// Add to observers.
	dispatch_barrier_async(_localQueue, ^{
		
		// > Create master observers.
		if (!_pathObservers)
			_pathObservers = [[NSMutableDictionary alloc] init];
		
		// > Get observers for this component.
		NSMutableArray *observers = _pathObservers[@(component)];
		
		if (!observers)
		{
			observers = [[NSMutableArray alloc] init];
			_pathObservers[@(component)] = observers;
		}
		
		// > Add this observer to the list.
		[observers addObject:result];
	});

	return result;
}

- (void)removePathObserver:(id)observer
{
	if (!observer)
		return;
	
	NSDictionary	*info = observer;
	NSNumber		*component = info[@"component"];
	
	dispatch_barrier_async(_localQueue, ^{

		NSMutableArray *array = _pathObservers[component];
		
		[array removeObjectIdenticalTo:info];
	});
}

- (void)_notifyPathChangeForComponent:(TCConfigPathComponent)component
{
	// > localQueue <
	
	// Get observers for this component.
	NSArray *observers = _pathObservers[@(component)];
	
	if (!observers)
		return;
	
	// Notify each observers.
	for (NSDictionary *observer in observers)
	{
		dispatch_block_t block = observer[@"block"];
		dispatch_queue_t queue = observer[@"queue"];
		
		dispatch_async(queue, ^{
			block();
		});
	}
>>>>>>> javerous/master
}



/*
** TCConfigPlist - Strings
*/
#pragma mark - TCConfigPlist - Strings

- (NSString *)localizedString:(TCConfigStringItem)stringItem
{
	switch (stringItem)
	{
		case TCConfigStringItemMyselfBuddy:
			return NSLocalizedString(@"core_mng_myself", @"");
	}
	
	return nil;
}



/*
<<<<<<< HEAD
=======
** TCConfigPlist - synchronize
*/
#pragma mark - TCConfigPlist - synchronize

- (void)synchronize
{
	dispatch_barrier_sync(_localQueue, ^{
		
		if (_isDirty)
		{
			[self saveConfig:_fcontent toFile:_fpath];
			_isDirty = NO;
		}
	});
}



/*
>>>>>>> javerous/master
** TCConfigPlist - Helpers
*/
#pragma mark - TCConfigPlist - Helpers

<<<<<<< HEAD
=======
- (void)_markDirty
{
	// > /localQueue <

	_isDirty = YES;
	dispatch_source_set_timer(_timer, dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), 0, 1 * NSEC_PER_SEC);
}

>>>>>>> javerous/master
- (NSMutableDictionary *)loadConfig:(NSData *)data
{
	NSMutableDictionary	*content = nil;
	
	// Parse plist.
	if (data)
	{
		// > Parse.
		content = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:nil errorDescription:nil];
		
		if ([content isKindOfClass:[NSDictionary class]] == NO)
			return nil;
		
		// > Check & update version.
		NSNumber *fileVersion = content[TCCONF_KEY_VERSION];
		
		if (!fileVersion)
			fileVersion = @(TCConfigVersion1);
		
		switch ([fileVersion intValue])
		{
			case TCConfigVersion1:
			{
				// Remove tor path.
				[content removeObjectForKey:@"tor_path"]; // TCCONF_KEY_TOR_PATH
				
				// Create paths container.
				NSMutableDictionary *paths = [[NSMutableDictionary alloc] init];
				
				// > Tor data path.
				NSString *oldTorData = content[@"tor_data_path"];
				
				if (oldTorData)
				{
<<<<<<< HEAD
					NSMutableDictionary *domainConfig = [[NSMutableDictionary alloc] init];
					
					domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_ABSOLUTE;
					domainConfig[TCCONF_KEY_PATH_SUBPATH] = [oldTorData stringByExpandingTildeInPath];

					paths[TCCONF_KEY_PATH_TOR_DATA] = domainConfig;
=======
					NSMutableDictionary *componentConfig = [[NSMutableDictionary alloc] init];
					
					componentConfig[TCCONF_KEY_PATH_TYPE] = TCCONF_VALUE_PATH_TYPE_ABSOLUTE;
					componentConfig[TCCONF_KEY_PATH_SUBPATH] = [oldTorData stringByExpandingTildeInPath];

					paths[TCCONF_KEY_PATH_TOR_DATA] = componentConfig;
>>>>>>> javerous/master
					
					[content removeObjectForKey:@"tor_data_path"];
				}
				else
				{
<<<<<<< HEAD
					NSMutableDictionary *domainConfig = [[NSMutableDictionary alloc] init];

					domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_REFERAL;
					domainConfig[TCCONF_KEY_PATH_SUBPATH] = @"tordata/";
					
					paths[TCCONF_KEY_PATH_TOR_DATA] = domainConfig;
=======
					NSMutableDictionary *componentConfig = [[NSMutableDictionary alloc] init];

					componentConfig[TCCONF_KEY_PATH_TYPE] = TCCONF_VALUE_PATH_TYPE_REFERAL;
					componentConfig[TCCONF_KEY_PATH_SUBPATH] = @"tordata/";
					
					paths[TCCONF_KEY_PATH_TOR_DATA] = componentConfig;
>>>>>>> javerous/master
				}
				
				// > Tor hidden path.
				NSString *oldTorHidden = [oldTorData stringByAppendingPathComponent:@"hidden"];
				
				if (oldTorHidden)
				{
<<<<<<< HEAD
					NSMutableDictionary *domainConfig = [[NSMutableDictionary alloc] init];
					
					domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_ABSOLUTE;
					domainConfig[TCCONF_KEY_PATH_SUBPATH] = [oldTorHidden stringByExpandingTildeInPath];
					
					paths[TCCONF_KEY_PATH_TOR_IDENTITY] = domainConfig;
				}
				else
				{
					NSMutableDictionary *domainConfig = [[NSMutableDictionary alloc] init];
					
					domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_REFERAL;
					domainConfig[TCCONF_KEY_PATH_SUBPATH] = @"tordata/hidden/";
					
					paths[TCCONF_KEY_PATH_TOR_IDENTITY] = domainConfig;
=======
					NSMutableDictionary *componentConfig = [[NSMutableDictionary alloc] init];
					
					componentConfig[TCCONF_KEY_PATH_TYPE] = TCCONF_VALUE_PATH_TYPE_ABSOLUTE;
					componentConfig[TCCONF_KEY_PATH_SUBPATH] = [oldTorHidden stringByExpandingTildeInPath];
					
					paths[TCCONF_KEY_PATH_TOR_IDENTITY] = componentConfig;
				}
				else
				{
					NSMutableDictionary *componentConfig = [[NSMutableDictionary alloc] init];
					
					componentConfig[TCCONF_KEY_PATH_TYPE] = TCCONF_VALUE_PATH_TYPE_REFERAL;
					componentConfig[TCCONF_KEY_PATH_SUBPATH] = @"tordata/hidden/";
					
					paths[TCCONF_KEY_PATH_TOR_IDENTITY] = componentConfig;
>>>>>>> javerous/master
				}
				
				// > Download path.
				NSString *oldDownload = [oldTorData stringByAppendingPathComponent:@"download_path"];

				if (oldDownload)
				{
<<<<<<< HEAD
					NSMutableDictionary *domainConfig = [[NSMutableDictionary alloc] init];
					
					domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_ABSOLUTE;
					domainConfig[TCCONF_KEY_PATH_SUBPATH] = [oldDownload stringByExpandingTildeInPath];
					
					paths[TCCONF_KEY_PATH_DOWNLOADS] = domainConfig;
=======
					NSMutableDictionary *componentConfig = [[NSMutableDictionary alloc] init];
					
					componentConfig[TCCONF_KEY_PATH_TYPE] = TCCONF_VALUE_PATH_TYPE_ABSOLUTE;
					componentConfig[TCCONF_KEY_PATH_SUBPATH] = [oldDownload stringByExpandingTildeInPath];
					
					paths[TCCONF_KEY_PATH_DOWNLOADS] = componentConfig;
>>>>>>> javerous/master
					
					[content removeObjectForKey:@"download_path"];
				}
				else
				{
<<<<<<< HEAD
					NSMutableDictionary *domainConfig = [[NSMutableDictionary alloc] init];
					
					domainConfig[TCCONF_KEY_PATH_PLACE] = TCCONF_VALUE_PATH_PLACE_REFERAL;
					domainConfig[TCCONF_KEY_PATH_SUBPATH] = @"Downloads/";
					
					paths[TCCONF_KEY_PATH_DOWNLOADS] = domainConfig;
=======
					NSMutableDictionary *componentConfig = [[NSMutableDictionary alloc] init];
					
					componentConfig[TCCONF_KEY_PATH_TYPE] = TCCONF_VALUE_PATH_TYPE_REFERAL;
					componentConfig[TCCONF_KEY_PATH_SUBPATH] = @"Downloads/";
					
					paths[TCCONF_KEY_PATH_DOWNLOADS] = componentConfig;
>>>>>>> javerous/master
				}

				content[TCCONF_KEY_PATHS] = paths;
				
				// Update version.
				content[TCCONF_KEY_VERSION] = @(TCConfigVersion2);
				
				// No break: continue update path.
			}
			
			case TCConfigVersion2:
			{
				// Current version. Nothing to update.
			}
		}
	}

	// Create empty sctucture.
	if (!content)
	{
		content = [NSMutableDictionary dictionary];
		
		content[TCCONF_KEY_VERSION] = @(TCConfigVersionCurrent);
	}
	
	return content;
}

<<<<<<< HEAD
- (void)saveConfig
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:_fcontent format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
	
	if (!data)
		return;
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	
	// Save by using proxy
=======
- (BOOL)saveConfig:(NSDictionary *)config toFile:(NSString *)path
{
	if (!config)
		return NO;
	
	// Serialize data.
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:config format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
	
	if (!data)
		return NO;
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	
	// Save by using proxy.
>>>>>>> javerous/master
	if (_proxy)
	{
		@try
		{
			[_proxy setConfigContent:data];
<<<<<<< HEAD
=======
			return YES;
>>>>>>> javerous/master
		}
		@catch (NSException *exception)
		{
			_proxy = nil;
			
			NSLog(@"Configuration proxy unavailable");
<<<<<<< HEAD
=======
			
			return NO;
>>>>>>> javerous/master
		}
	}
	
#endif
	
<<<<<<< HEAD
	// Save by using file
	if (_fpath)
		[data writeToFile:_fpath atomically:YES];
=======
	// Save by using file.
	if (path)
		return [data writeToFile:path atomically:YES];
	
	return NO;
>>>>>>> javerous/master
}

@end
