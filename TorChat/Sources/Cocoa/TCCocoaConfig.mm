/*
 *  TCCocoaConfig.mm
 *
 *  Copyright 2012 Avérous Julien-Pierre
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



#import "TCStringExtension.h"

#include "TCCocoaConfig.h"



/*
** Config Keys
*/
#pragma mark - Config Keys

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



/*
** TCCocoaConfig - Instance
*/
#pragma mark - TCCocoaConfig - Instance

TCCocoaConfig::TCCocoaConfig(NSString *filepath)
{
	if (!filepath)
		throw "conf_err_no_name";
	
	NSFileManager	*mng = [NSFileManager defaultManager];
	NSString		*npath;
	NSData			*data = nil;
	
	// Resolve path
	npath = [filepath realPath];
	
	if (npath)
		filepath = npath;
		
	if (!filepath)
	{
		throw "conf_err_cant_open";
		return;
	}
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	proxy = NULL;
#endif
	
	// Hold path
	fpath = filepath;
	
	// Load file
	if ([mng fileExistsAtPath:fpath])
	{
		// Load config data
		data = [NSData dataWithContentsOfFile:fpath];
		
		if (!data)
			throw "conf_err_cant_open";
	}
	
	// Load config
	_loadConfig(data);
}

#if defined(PROXY_ENABLED) && PROXY_ENABLED

TCCocoaConfig::TCCocoaConfig(id <TCConfigProxy> _proxy)
{
	NSData *data = nil;

	// Set path
	fpath = NULL;
	
	// Hold proxy
	proxy = [_proxy retain];
	
	// Load data
	data = [proxy configContent];
	
	// Load config
	_loadConfig(data);
}

#endif

TCCocoaConfig::~TCCocoaConfig()
{
	fcontent = nil;
	fpath = nil;

#if defined(PROXY_ENABLED) && PROXY_ENABLED
	proxy = nil;
#endif
}



/*
** TCCocoaConfig - Tor
*/
#pragma mark - TCCocoaConfig - Tor

std::string TCCocoaConfig::get_tor_address() const
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_TOR_ADDRESS];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "localhost";
}

void TCCocoaConfig::set_tor_address(const std::string &address)
{
	NSString *value = [NSString stringWithUTF8String:address.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_TOR_ADDRESS];
		
		// Save
		_saveConfig();
	}
}

uint16_t TCCocoaConfig::get_tor_port() const
{
	NSNumber *value = [fcontent objectForKey:TCCONF_KEY_TOR_PORT];
	
	if (value)
		return [value unsignedShortValue];
	else
		return 9050;
}

void TCCocoaConfig::set_tor_port(uint16_t port)
{
	NSNumber *value = [NSNumber numberWithUnsignedShort:port];
	
	[fcontent setObject:value forKey:TCCONF_KEY_TOR_PORT];
	
	// Save
	_saveConfig();
}

std::string TCCocoaConfig::get_tor_path() const
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_TOR_PATH];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "<tor>";
}

void TCCocoaConfig::set_tor_path(const std::string &path)
{
	NSString *value = [NSString stringWithUTF8String:path.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_TOR_PATH];
		
		// Save
		_saveConfig();
	}
}

std::string TCCocoaConfig::get_tor_data_path() const
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_TOR_DATA_PATH];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "tordata";
	
	return "";
}

void TCCocoaConfig::set_tor_data_path(const std::string &path)
{
	NSString *value = [NSString stringWithUTF8String:path.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_TOR_DATA_PATH];
		
		// Save
		_saveConfig();
	}
}



/*
** TCCocoaConfig - TorChat
*/
#pragma mark - TCCocoaConfig - TorChat

std::string TCCocoaConfig::get_self_address() const
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_IM_ADDRESS];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "xxx";
}

void TCCocoaConfig::set_self_address(const std::string &address)
{
	NSString *value = [NSString stringWithUTF8String:address.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_IM_ADDRESS];
		
		// Save
		_saveConfig();
	}
}

uint16_t TCCocoaConfig::get_client_port() const
{
	NSNumber *value = [fcontent objectForKey:TCCONF_KEY_IM_PORT];
	
	if (value)
		return [value unsignedShortValue];
	else
		return 11009;
}

void TCCocoaConfig::set_client_port(uint16_t port)
{
	NSNumber *value = [NSNumber numberWithUnsignedShort:port];
	
	[fcontent setObject:value forKey:TCCONF_KEY_IM_PORT];
	
	// Save
	_saveConfig();
}


std::string TCCocoaConfig::get_download_folder() const
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_DOWN_FOLDER];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return localized("conf_download");
}

void TCCocoaConfig::set_download_folder(const std::string & folder)
{
	NSString *value = [NSString stringWithUTF8String:folder.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_DOWN_FOLDER];
		
		// Save
		_saveConfig();
	}
}



/*
** TCCocoaConfig - Mode
*/
#pragma mark - TCCocoaConfig - Mode

tc_config_mode TCCocoaConfig::get_mode() const
{
	NSNumber *value = [fcontent objectForKey:TCCONF_KEY_MODE];
	
	if (value)
	{
		int mode = [value unsignedShortValue];
		
		if (mode == tc_config_advanced)
			return tc_config_advanced;
		else if (mode == tc_config_basic)
			return tc_config_basic;
		
		return tc_config_advanced;
	}
	else
		return tc_config_advanced;
}

void TCCocoaConfig::set_mode(tc_config_mode mode)
{
	NSNumber *value = [NSNumber numberWithUnsignedShort:mode];
	
	[fcontent setObject:value forKey:TCCONF_KEY_MODE];
	
	// Save
	_saveConfig();
}



/*
** TCCocoaConfig - Profile
*/
#pragma mark - TCCocoaConfig - Profile

std::string TCCocoaConfig::get_profile_name()
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_PROFILE_NAME];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "-";
}

void TCCocoaConfig::set_profile_name(const std::string & name)
{
	NSString *value = [NSString stringWithUTF8String:name.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_PROFILE_NAME];
		
		// Save
		_saveConfig();
	}
}

std::string TCCocoaConfig::get_profile_text()
{
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_PROFILE_TEXT];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "";
}

void TCCocoaConfig::set_profile_text(const std::string & text)
{
	NSString *value = [NSString stringWithUTF8String:text.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_PROFILE_TEXT];
		
		// Save
		_saveConfig();
	}
}

TCImage * TCCocoaConfig::get_profile_avatar()
{
	NSDictionary	*avatar = [fcontent objectForKey:TCCONF_KEY_PROFILE_AVATAR];
	NSNumber		*width = [avatar objectForKey:@"width"];
	NSNumber		*height = [avatar objectForKey:@"width"];
	NSData			*bitmap = [avatar objectForKey:@"bitmap"];
	NSData			*bitmapAlpha = [avatar objectForKey:@"bitmap_alpha"];
	TCImage			*image;
	
	if ([width unsignedIntValue] == 0 || [height unsignedIntValue] == 0)
		return NULL;
	
	// Build TorChat core image
	image = [[TCImage alloc] initWithWidth:[width unsignedIntValue] andHeight:[height unsignedIntValue]];
	
	[image setBitmap:bitmap];
	[image setBitmapAlpha:bitmapAlpha];

	return image;
}

void TCCocoaConfig::set_profile_avatar(const TCImage *picture)
{
	if ([picture width] == 0 || [picture height] == 0 || [picture bitmap] == nil)
	{
		[fcontent removeObjectForKey:TCCONF_KEY_PROFILE_AVATAR];
		
		// Save
		_saveConfig();
		
		return;
	}
	
	NSMutableDictionary *avatar = [[NSMutableDictionary alloc] initWithCapacity:4];

	[avatar setObject:@([picture width]) forKey:@"width"];
	[avatar setObject:@([picture height]) forKey:@"height"];
	
	if ([picture bitmap])
		[avatar setObject:[picture bitmap] forKey:@"bitmap"];
	
	if ([picture bitmapAlpha])
		[avatar setObject:[picture bitmapAlpha] forKey:@"bitmap_alpha"];
	
	[fcontent setObject:avatar forKey:TCCONF_KEY_PROFILE_AVATAR];

	// Save
	_saveConfig();
}



/*
** TCCocoaConfig - Buddies
*/
#pragma mark - TCCocoaConfig - Buddies

const tc_darray & TCCocoaConfig::buddies()
{
	return _bcache;
}

void TCCocoaConfig::add_buddy(const std::string &address, const std::string &alias, const std::string &notes)
{
	// Build cocoa version
	NSString			*oaddress = [NSString stringWithUTF8String:address.c_str()];
	NSString			*oalias = [NSString stringWithUTF8String:alias.c_str()];
	NSString			*onotes = [NSString stringWithUTF8String:notes.c_str()];
	NSMutableDictionary	*obuddy = [[NSMutableDictionary alloc] init];
	
	[obuddy setObject:oalias forKey:@TCConfigBuddyAlias];
	[obuddy setObject:oaddress forKey:@TCConfigBuddyAddress];
	[obuddy setObject:onotes forKey:@TCConfigBuddyNotes];
	[obuddy setObject:@"" forKey:@TCConfigBuddyLastName];
	
	[[fcontent objectForKey:TCCONF_KEY_BUDDIES] addObject:obuddy];
	
	
	// Buil C++ version
	tc_dictionary entry;
	
	entry[TCConfigBuddyAlias] = alias;
	entry[TCConfigBuddyAddress] = address;
	entry[TCConfigBuddyNotes] = notes;
	entry[TCConfigBuddyLastName] = "";
	
	_bcache.push_back(entry);
	
	
	// Save & Release
	_saveConfig();
}

bool TCCocoaConfig::remove_buddy(const std::string &address)
{
	BOOL oc_found = NO;
	BOOL cpp_found = NO;
	
	// Remove from Cocoa version
	NSMutableArray	*array = [fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	NSString		*oaddress = [NSString stringWithUTF8String:address.c_str()];
	
	for (i = 0; i < cnt; i++)
	{
		NSDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:@TCConfigBuddyAddress] isEqualToString:oaddress])
		{
			[array removeObjectAtIndex:i];
			oc_found = YES;
			break;
		}
	}
	
	
	// Remove from C++ version
	cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		tc_dictionary &buddy = _bcache[i];
		
		if (buddy[TCConfigBuddyAddress].compare(address) == 0)
		{
			_bcache.erase(_bcache.begin() + (ptrdiff_t)i);
			cpp_found = YES;
			break;
		}
	}
	
	
	// Save
	_saveConfig();

	return oc_found && cpp_found;
}

void TCCocoaConfig::set_buddy_alias(const std::string &address, const std::string &alias)
{
	// Change from Cocoa version
	NSMutableArray	*array = [fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	NSString		*oaddress = [NSString stringWithUTF8String:address.c_str()];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:@TCConfigBuddyAddress] isEqualToString:oaddress])
		{
			[buddy setObject:[NSString stringWithUTF8String:alias.c_str()] forKey:@TCConfigBuddyAlias];
			break;
		}
	}
	
	
	// Change from C++ version
	cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		tc_dictionary &buddy = _bcache[i];
		
		if (buddy[TCConfigBuddyAddress].compare(address) == 0)
		{
			buddy[TCConfigBuddyAlias] = alias;
			break;
		}
	}
	
	// Save
	_saveConfig();
}

void TCCocoaConfig::set_buddy_notes(const std::string &address, const std::string &notes)
{
	// Change from Cocoa version
	NSMutableArray	*array = [fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	NSString		*oaddress = [NSString stringWithUTF8String:address.c_str()];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:@TCConfigBuddyAddress] isEqualToString:oaddress])
		{
			[buddy setObject:[NSString stringWithUTF8String:notes.c_str()] forKey:@TCConfigBuddyNotes];
			break;
		}
	}
	
	
	// Change from C++ version
	cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		tc_dictionary &buddy = _bcache[i];
		
		if (buddy[TCConfigBuddyAddress].compare(address) == 0)
		{
			buddy[TCConfigBuddyNotes] = notes;
			break;
		}
	}
	
	// Save
	_saveConfig();
}

void TCCocoaConfig::set_buddy_last_profile_name(const std::string &address, const std::string &lname)
{
	// Change from Cocoa version
	NSMutableArray	*array = [fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSUInteger		i, cnt = [array count];
	NSString		*oaddress = [NSString stringWithUTF8String:address.c_str()];
	
	for (i = 0; i < cnt; i++)
	{
		NSMutableDictionary *buddy = [array objectAtIndex:i];
		
		if ([[buddy objectForKey:@TCConfigBuddyAddress] isEqualToString:oaddress])
		{
			[buddy setObject:[NSString stringWithUTF8String:lname.c_str()] forKey:@TCConfigBuddyLastName];
			break;
		}
	}
	
	
	// Change from C++ version
	cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		tc_dictionary &buddy = _bcache[i];
		
		if (buddy[TCConfigBuddyAddress].compare(address) == 0)
		{
			buddy[TCConfigBuddyLastName] = lname;
			break;
		}
	}
	
	// Save
	_saveConfig();
}

std::string TCCocoaConfig::get_buddy_alias(const std::string &address) const
{
	size_t i, cnt = _bcache.size();

	for (i = 0; i < cnt; i++)
	{
		const tc_dictionary &buddy = _bcache.at(i);
		
		if (buddy.at(TCConfigBuddyAddress).compare(address) == 0)
			return buddy.at(TCConfigBuddyAlias);
	}

	return "";
}

std::string TCCocoaConfig::get_buddy_notes(const std::string &address) const
{
	size_t i, cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		const tc_dictionary &buddy = _bcache.at(i);
		
		if (buddy.at(TCConfigBuddyAddress).compare(address) == 0)
			return buddy.at(TCConfigBuddyNotes);
	}
	
	return "";
}

std::string TCCocoaConfig::get_buddy_last_profile_name(const std::string &address) const
{
	size_t i, cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		const tc_dictionary &buddy = _bcache.at(i);
		
		if (buddy.at(TCConfigBuddyAddress).compare(address) == 0)
			return buddy.at(TCConfigBuddyLastName);
	}
	
	return "";
}



/*
** TCCocoaConfig - Blocked
*/
#pragma mark - TCCocoaConfig - Blocked

const tc_sarray & TCCocoaConfig::blocked_buddies()
{
	return _bbcache;
}

bool TCCocoaConfig::add_blocked_buddy(const std::string &address)
{
	// Add to cocoa version
	NSString		*oaddress = [NSString stringWithUTF8String:address.c_str()];
	NSMutableArray	*list = [fcontent objectForKey:TCCONF_KEY_BLOCKED];
	
	if ([list indexOfObject:oaddress] != NSNotFound)
		return false;
	
	[list addObject:oaddress];
	
	// Add to C++ version	
	_bbcache.push_back(address);
	
	// Save & Release
	_saveConfig();
	
	return true;
}

bool TCCocoaConfig::remove_blocked_buddy(const std::string &address)
{
	BOOL oc_found = NO;
	BOOL cpp_found = NO;
	
	// Remove from Cocoa version
	NSMutableArray	*array = [fcontent objectForKey:TCCONF_KEY_BLOCKED];
	NSUInteger		i, cnt = [array count];
	NSString		*oaddress = [NSString stringWithUTF8String:address.c_str()];
	
	for (i = 0; i < cnt; i++)
	{
		NSString *buddy = [array objectAtIndex:i];
		
		if ([buddy isEqualToString:oaddress])
		{
			[array removeObjectAtIndex:i];
			oc_found = YES;
			break;
		}
	}
	
	
	// Remove from C++ version
	cnt = _bbcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		std::string &buddy = _bbcache[i];
		
		if (buddy.compare(address) == 0)
		{
			_bbcache.erase(_bbcache.begin() + (ptrdiff_t)i);
			cpp_found = YES;
			break;
		}
	}
	
	
	// Save
	_saveConfig();
	
	return oc_found && cpp_found;
}



/*
** TCCocoaConfig - Tools
*/
#pragma mark - TCCocoaConfig - Tools

std::string TCCocoaConfig::real_path(const std::string &path) const
{
	if (path.size() == 0)
		return "";
	
	if (path.compare("<tor>") == 0)
	{
		NSBundle	*bundle = [NSBundle mainBundle];
		NSString	*opath = [bundle pathForResource:@"tor" ofType:@""];
		const char	*cpath = [opath UTF8String];
		
		if (cpath)
			return cpath;
		else
			return "cant_find_tor";
	}
	else if (path[0] == '~')
	{
		NSString *pth = [[NSString stringWithUTF8String:path.c_str()] stringByExpandingTildeInPath];
		
		return [pth UTF8String];
	}
	else if (path[0] == '/')
	{
		return path;
	}
	else
	{
		NSString	*component = [NSString stringWithUTF8String:path.c_str()];
		NSString	*opath = nil;
		
#if defined(PROXY_ENABLED) && PROXY_ENABLED

		// Build path relative to desktop directory
		if (!opath)
			opath = [[@"~/Desktop" stringByExpandingTildeInPath] stringByAppendingPathComponent:component];
#endif
		
		// Build path relative to configuration directory
		if (!opath)
			opath = [[fpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:component];
		
		// Build path relative to temporary directory
		if (!opath)
			opath = [@"/tmp" stringByAppendingPathComponent:component];

		return [opath UTF8String];
	}
}



/*
** TCCocoaConfig - Localization
*/
#pragma mark - TCCocoaConfig - Localization

std::string TCCocoaConfig::localized(const std::string &key) const
{
	const char	*ckey = key.c_str();
	NSString	*okey = [[NSString alloc] initWithUTF8String:ckey];
	std::string	result;
	NSString	*local = nil;
	const char	*clocal = NULL;
	
	if (!okey)
		return result;
	
	local = NSLocalizedString(okey, @"");
	
	if (!local)
		return result;
		
	clocal = [local UTF8String];
	
	if (!clocal)
		return result;
	
	result = clocal;
	
	return result;
}



/*
** TCCocoaConfig - UI
*/
#pragma mark - TCCocoaConfig - UI

tc_config_title TCCocoaConfig::get_mode_title() const
{
	NSNumber *value = [fcontent objectForKey:TCCONF_KEY_UI_TITLE];
	
	if (!value)
		return tc_config_title_address;
	
	return (tc_config_title)[value unsignedShortValue];
}

void TCCocoaConfig::set_mode_title(tc_config_title mode)
{
	NSNumber *value = [NSNumber numberWithUnsignedShort:mode];
	
	[fcontent setObject:value forKey:TCCONF_KEY_UI_TITLE];
	
	// Save
	_saveConfig();
}


std::string TCCocoaConfig::get_client_version(tc_config_get get) const
{	
	switch (get)
	{
		case tc_config_get_default:
		{
			NSBundle	*bundle = [NSBundle mainBundle];
			NSString	*version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
			const char	*cversion = [version UTF8String];
			
			if (cversion)
				return cversion;
			
			return "";
		}
			
		case tc_config_get_defined:
		{
			NSString	*value = [fcontent objectForKey:TCCONF_KEY_CLIENT_VERSION];
			const char	*c_value = [value UTF8String];
			
			if (c_value)
				return c_value;

			return "";
		}
			
		case tc_config_get_real:
		{
			std::string value = get_client_version(tc_config_get_defined);
			
			if (value.size() == 0)
				value = get_client_version(tc_config_get_default);
			
			return value;
		}
	}

	return "";
}

void TCCocoaConfig::set_client_version(const std::string &version)
{
	NSString *value = [NSString stringWithUTF8String:version.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_CLIENT_VERSION];
		
		// Save
		_saveConfig();
	}
}

std::string TCCocoaConfig::get_client_name(tc_config_get get) const
{
	switch (get)
	{
		case tc_config_get_default:
		{
			return "TorChat for Mac";
		}
			
		case tc_config_get_defined:
		{
			NSString	*value = [fcontent objectForKey:TCCONF_KEY_CLIENT_NAME];
			const char	*c_value = [value UTF8String];
			
			if (c_value)
				return c_value;
			
			return "";
		}
			
		case tc_config_get_real:
		{
			std::string value = get_client_name(tc_config_get_defined);
			
			if (value.size() == 0)
				value = get_client_name(tc_config_get_default);
			
			return value;
		}
	}
	
	return "";
}

void TCCocoaConfig::set_client_name(const std::string &name)
{
	NSString *value = [NSString stringWithUTF8String:name.c_str()];
	
	if (value)
	{
		[fcontent setObject:value forKey:TCCONF_KEY_CLIENT_NAME];
		
		// Save
		_saveConfig();
	}
}



/*
** TCCocoaConfig - Private
*/
#pragma mark - TCCocoaConfig - Private

void TCCocoaConfig::_loadConfig(NSData *data)
{
	NSMutableDictionary	*content;
	
	// Parse plist
	if (data)
		content = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:nil errorDescription:nil];
	else
		content = [NSMutableDictionary dictionary];
	
	// Check content
	if (!content)
		throw "conf_err_parse";
	
	if ([content isKindOfClass:[NSDictionary class]] == NO)
		throw "conf_err_content";
	
	// Hold content
	fcontent = content;
	
	// Build buddies cache
	NSArray			*buddies = [fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSMutableArray	*nbuddies = [[NSMutableArray alloc] init];
	
	for (NSDictionary *buddy in buddies)
	{
		NSMutableDictionary *nbuddy = [[NSMutableDictionary alloc] initWithDictionary:buddy];
		NSString			*alias = [nbuddy objectForKey:@TCConfigBuddyAlias];
		NSString			*address = [nbuddy objectForKey:@TCConfigBuddyAddress];
		NSString			*notes = [nbuddy objectForKey:@TCConfigBuddyNotes];
		NSString			*lname = [nbuddy objectForKey:@TCConfigBuddyLastName];
		
		// Add it to NSMutableArray cache
		[nbuddies addObject:nbuddy];
		
		// Add it to tc_array cache
		tc_dictionary entry;
		
		entry[TCConfigBuddyAlias] = (alias ? [alias UTF8String] : "-");
		entry[TCConfigBuddyAddress] = (address ? [address UTF8String] : "-");
		entry[TCConfigBuddyNotes] = (notes ? [notes UTF8String] : "-");
		entry[TCConfigBuddyLastName] = (lname ? [lname UTF8String] : "");

		_bcache.push_back(entry);
	}
	
	[fcontent setObject:nbuddies forKey:TCCONF_KEY_BUDDIES];
	
	
	// Build blocked cache
	NSArray			*blocked = [fcontent objectForKey:TCCONF_KEY_BLOCKED];
	NSMutableArray	*nblocked = [[NSMutableArray alloc] init];
	
	for (NSString *buddy in blocked)
	{
		const char *cbuddy = [buddy UTF8String];
		
		if (!cbuddy)
			continue;
		
		// Add it to NSMutableArray cache
		[nblocked addObject:buddy];
		
		// Add it to tc_array cache
		_bbcache.push_back(cbuddy);
	}
	
	[fcontent setObject:nblocked forKey:TCCONF_KEY_BLOCKED];
}

void TCCocoaConfig::_saveConfig()
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:fcontent format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
	
	if (!data)
		return;
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	
	// Save by using proxy
	if (proxy)
	{
		@try
		{
			[proxy setConfigContent:data];
		}
		@catch (NSException *exception)
		{
			[proxy release];
			proxy = nil;
			
			NSLog(@"Configuration proxy unavailable");
		}
	}
	
#endif
	
	// Save by using file
	if (fpath)
		[data writeToFile:fpath atomically:YES];
}
