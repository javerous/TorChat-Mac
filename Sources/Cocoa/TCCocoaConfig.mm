/*
 *  TCCocoaConfig.mm
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



#include "TCCocoaConfig.h"



/*
** Config Keys
*/
#pragma mark -
#pragma mark Config Keys

#define TCCONF_KEY_TOR_ADDRESS		@"tor_address"
#define TCCONF_KEY_TOR_PORT			@"tor_socks_port"
#define TCCONF_KEY_TOR_PATH			@"tor_path"
#define TCCONF_KEY_TOR_DATA_PATH	@"tor_data_path"

#define TCCONF_KEY_IM_ADDRESS		@"im_address"
#define TCCONF_KEY_IM_PORT			@"im_in_port"

#define TCCONF_KEY_DOWN_FOLDER		@"download_path"

#define TCCONF_KEY_MODE				@"mode"

#define TCCONF_KEY_BUDDIES			@"buddies"



/*
** TCCocoaConfig - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCCocoaConfig - Constructor & Destructor

TCCocoaConfig::TCCocoaConfig(NSString *filepath)
{
	if (!filepath)
		throw "conf_err_no_name";
	
	NSFileManager *mng = [NSFileManager defaultManager];
	
	// Open or read file
	if ([mng fileExistsAtPath:filepath])
	{
		// Load data
		NSData *data = [NSData dataWithContentsOfFile:filepath];
		
		if (!data)
			throw "conf_err_cant_open";
		
		// Parse as plist
		NSMutableDictionary	*content = [NSPropertyListSerialization propertyListFromData:data mutabilityOption:NSPropertyListMutableContainersAndLeaves format:nil errorDescription:nil];
		
		if (!content)
			throw "conf_err_parse";
		
		if ([content isKindOfClass:[NSDictionary class]] == NO)
			throw "conf_err_content";
		
		// Hold content & path
		fcontent = [content retain];
		fpath = [filepath retain];
	}
	else
	{
		// Simply hold content & path
		fcontent = [[NSMutableDictionary dictionary] retain];
		fpath = [filepath retain];
		
		_writeToFile();
	}
	
	// Build buddies cache
	NSArray			*buddies = [fcontent objectForKey:TCCONF_KEY_BUDDIES];
	NSMutableArray	*nbuddies = [[NSMutableArray alloc] init];
	
	for (NSDictionary *buddy in buddies)
	{
		NSMutableDictionary *nbuddy = [[NSMutableDictionary alloc] initWithDictionary:buddy];
		NSString			*name = [nbuddy objectForKey:@TCConfigBuddyName];
		NSString			*address = [nbuddy objectForKey:@TCConfigBuddyAddress];
		NSString			*comment = [nbuddy objectForKey:@TCConfigBuddyComment];
		
		// Add it to NSMutableArray cache
		[nbuddies addObject:nbuddy];
		
		// Add it to tc_array cache
		tc_dictionary entry;
		
		entry[TCConfigBuddyName] = (name ? [name UTF8String] : "-");
		entry[TCConfigBuddyAddress] = (address ? [address UTF8String] : "-");
		entry[TCConfigBuddyComment] = (comment ? [comment UTF8String] : "-");
		
		_bcache.push_back(entry);
		
		// Release
		[nbuddy release];
	}
	
	[fcontent setObject:nbuddies forKey:TCCONF_KEY_BUDDIES];
	[nbuddies release];
}

TCCocoaConfig::~TCCocoaConfig()
{
	[fcontent release];
	[fpath release];
}



/*
** TCCocoaConfig - Tor
*/
#pragma mark -
#pragma mark TCCocoaConfig - Tor

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
		
		_writeToFile();
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
	
	_writeToFile();
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
		
		_writeToFile();
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
		
		_writeToFile();
	}
}



/*
** TCCocoaConfig - TorChat
*/
#pragma mark -
#pragma mark TCCocoaConfig - TorChat

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
		
		_writeToFile();
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
	
	_writeToFile();
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
		
		_writeToFile();
	}
}



/*
** TCCocoaConfig - Mode
*/
#pragma mark -
#pragma mark TCCocoaConfig - Mode

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
	
	_writeToFile();
}



/*
** TCCocoaConfig - Buddies
*/
#pragma mark -
#pragma mark TCCocoaConfig - Buddies

const tc_array & TCCocoaConfig::buddies()
{
	return _bcache;
}

void TCCocoaConfig::add_buddy(const std::string &address, const std::string &name, const std::string &comment)
{
	// Build cocoa version
	NSString			*oaddress = [NSString stringWithUTF8String:address.c_str()];
	NSString			*oname = [NSString stringWithUTF8String:name.c_str()];
	NSString			*ocomment = [NSString stringWithUTF8String:comment.c_str()];
	NSMutableDictionary	*obuddy = [[NSMutableDictionary alloc] init];
	
	[obuddy setObject:oname forKey:@TCConfigBuddyName];
	[obuddy setObject:oaddress forKey:@TCConfigBuddyAddress];
	[obuddy setObject:ocomment forKey:@TCConfigBuddyComment];
	
	[[fcontent objectForKey:TCCONF_KEY_BUDDIES] addObject:obuddy];
	
	
	// Buil C++ version
	tc_dictionary entry;
	
	entry[TCConfigBuddyName] = name;
	entry[TCConfigBuddyAddress] = address;
	entry[TCConfigBuddyComment] = comment;
	
	_bcache.push_back(entry);
	
	
	// Write & Release
	_writeToFile();
	[obuddy release];
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
			_bcache.erase(_bcache.begin() + i);
			cpp_found = YES;
			break;
		}
	}
	
	
	// Write
	_writeToFile();

	return oc_found && cpp_found;
}

void TCCocoaConfig::set_buddy_name(const std::string &address, const std::string &name)
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
			[buddy setObject:[NSString stringWithUTF8String:name.c_str()] forKey:@TCConfigBuddyName];
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
			buddy[TCConfigBuddyName] = name;
			break;
		}
	}
	
	
	// Write
	_writeToFile();
}

void TCCocoaConfig::set_buddy_comment(const std::string &address, const std::string &comment)
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
			[buddy setObject:[NSString stringWithUTF8String:comment.c_str()] forKey:@TCConfigBuddyComment];
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
			buddy[TCConfigBuddyComment] = comment;
			break;
		}
	}
	
	
	// Write
	_writeToFile();
}

std::string TCCocoaConfig::get_buddy_name(const std::string &address) const
{
	size_t i, cnt = _bcache.size();

	for (i = 0; i < cnt; i++)
	{
		const tc_dictionary &buddy = _bcache.at(i);
		
		if (buddy.at(TCConfigBuddyAddress).compare(address) == 0)
			return buddy.at(TCConfigBuddyName);
	}

	return "";
}

std::string TCCocoaConfig::get_buddy_comment(const std::string &address) const
{
	size_t i, cnt = _bcache.size();
	
	for (i = 0; i < cnt; i++)
	{
		const tc_dictionary &buddy = _bcache.at(i);
		
		if (buddy.at(TCConfigBuddyAddress).compare(address) == 0)
			return buddy.at(TCConfigBuddyComment);
	}
	
	return "";
}



/*
** TCCocoaConfig - Tools
*/
#pragma mark -
#pragma mark TCCocoaConfig - Tools

std::string TCCocoaConfig::real_path(const std::string &path) const
{
	if (path.size() == 0)
		return "";
	
	if (path.compare("<tor>") == 0)
	{
		NSBundle	*bundle = [NSBundle mainBundle];
		NSString	*path = [bundle pathForResource:@"tor" ofType:@""];
		const char	*cpath = [path UTF8String];
		
		if (cpath)
			return cpath;
		else
			return "cant_find_tor";
	}
	else if (path[0] != '/')
	{
		NSString	*component = [NSString stringWithUTF8String:path.c_str()];
		NSString	*path = [[fpath stringByDeletingLastPathComponent] stringByAppendingPathComponent:component];

		return [path UTF8String];
	}
	else
		return path;
}



/*
** TCCocoaConfig - Localization
*/
#pragma mark -
#pragma mark TCCocoaConfig - Localization

std::string TCCocoaConfig::localized(const std::string &key) const
{
	const char	*ckey = key.c_str();
	NSString	*okey = [[NSString alloc] initWithUTF8String:ckey];
	std::string	result;
	NSString	*local = nil;
	const char	*clocal = NULL;
	
	if (!okey)
		goto bail;
	
	local = NSLocalizedString(okey, @"");
	
	if (!local)
		goto bail;
		
	clocal = [local UTF8String];
	
	if (!clocal)
		goto bail;
	
	result = clocal;
	
bail:
	[okey release];
	return result;
}



/*
** TCCocoaConfig - Private
*/
#pragma mark -
#pragma mark TCCocoaConfig - Private

void TCCocoaConfig::_writeToFile()
{
	NSData *data = [NSPropertyListSerialization dataWithPropertyList:fcontent format:NSPropertyListXMLFormat_v1_0 options:0 error:nil];
	
	if (data)
		[data writeToFile:fpath atomically:YES];
}
