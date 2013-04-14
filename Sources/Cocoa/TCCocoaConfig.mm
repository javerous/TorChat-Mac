/*
 *  TCCocoaConfig.mm
 *
 *  Copyright 2011 Avérous Julien-Pierre
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

#define TCCONF_KEY_PROFILE_NAME		@"profile_name"
#define TCCONF_KEY_PROFILE_TEXT		@"profile_text"
#define TCCONF_KEY_PROFILE_AVATAR	@"profile_avatar"

#define TCCONF_KEY_CLIENT_VERSION	@"client_version"
#define TCCONF_KEY_CLIENT_NAME		@"client_name"


#define TCCONF_KEY_BUDDIES			@"buddies"

#define TCCONF_KEY_UI_TITLE			@"title"



/*
** TCCocoaConfig - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCCocoaConfig - Constructor & Destructor

TCCocoaConfig::TCCocoaConfig(NSString *filepath)
{
	if (!filepath)
		throw "conf_err_no_name";
	
	NSFileManager	*mng = [NSFileManager defaultManager];
	NSString		*npath;
	
	// Resolve path
	npath = [filepath realPath];
	
	if (npath)
		filepath = npath;
		
	if (!filepath)
	{
		throw "conf_err_cant_open";
		return;
	}
	
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
		NSString			*alias = [nbuddy objectForKey:@TCConfigBuddyAlias];
		NSString			*address = [nbuddy objectForKey:@TCConfigBuddyAddress];
		NSString			*notes = [nbuddy objectForKey:@TCConfigBuddyNotes];
		
		// Add it to NSMutableArray cache
		[nbuddies addObject:nbuddy];
		
		// Add it to tc_array cache
		tc_dictionary entry;
		
		entry[TCConfigBuddyAlias] = (alias ? [alias UTF8String] : "-");
		entry[TCConfigBuddyAddress] = (address ? [address UTF8String] : "-");
		entry[TCConfigBuddyNotes] = (notes ? [notes UTF8String] : "-");
		
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
** TCCocoaConfig - Profile
*/
#pragma mark -
#pragma mark TCCocoaConfig - Profile

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
		
		_writeToFile();
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
		
		_writeToFile();
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
	image = new TCImage([width unsignedIntValue], [height unsignedIntValue]);
	
	image->setBitmap([bitmap bytes], [bitmap length]);
	image->setAlphaBitmap([bitmapAlpha bytes], [bitmapAlpha length]);
	
	return image;
}

void TCCocoaConfig::set_profile_avatar(const TCImage & picture)
{
	if (picture.getWidth() == 0 || picture.getHeight() == 0 || picture.getBitmap() == NULL)
	{
		[fcontent removeObjectForKey:TCCONF_KEY_PROFILE_AVATAR];
		_writeToFile();
		
		return;
	}
	
	NSMutableDictionary *avatar = [[NSMutableDictionary alloc] initWithCapacity:4];
	NSNumber			*width = [[NSNumber alloc] initWithUnsignedInt:picture.getWidth()];
	NSNumber			*height = [[NSNumber alloc] initWithUnsignedInt:picture.getHeight()];
	NSData				*bitmap = nil;
	NSData				*bitmapAlpha = nil;
	
	[avatar setObject:width forKey:@"width"];
	[avatar setObject:height forKey:@"height"];
	
	if (picture.getBitmap())
	{
		bitmap = [[NSData alloc] initWithBytesNoCopy:(void *)picture.getBitmap() length:picture.getBitmapSize() freeWhenDone:NO];
				
		[avatar setObject:bitmap forKey:@"bitmap"];
	}
	
	if (picture.getBitmapAlpha())
	{
		bitmapAlpha = [[NSData alloc] initWithBytesNoCopy:(void *)picture.getBitmapAlpha() length:picture.getBitmapAlphaSize() freeWhenDone:NO];
		
		[avatar setObject:bitmapAlpha forKey:@"bitmap_alpha"];
	}
	
	[fcontent setObject:avatar forKey:TCCONF_KEY_PROFILE_AVATAR];
	
	[avatar release];
	[width release];
	[height release];
	[bitmap release];
	[bitmapAlpha release];

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
	
	[[fcontent objectForKey:TCCONF_KEY_BUDDIES] addObject:obuddy];
	
	
	// Buil C++ version
	tc_dictionary entry;
	
	entry[TCConfigBuddyAlias] = alias;
	entry[TCConfigBuddyAddress] = address;
	entry[TCConfigBuddyNotes] = notes;
	
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
	
	// Write
	_writeToFile();
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
	
	// Write
	_writeToFile();
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
** TCCocoaConfig - UI
*/
#pragma mark -
#pragma mark TCCocoaConfig - UI

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
	
	_writeToFile();
}


std::string TCCocoaConfig::get_client_version() const
{
	// Give the ability to the user to customize the version for anonymity
	
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_CLIENT_VERSION];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
	{
		NSBundle	*bundle = [NSBundle mainBundle];
		NSString	*version = [bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
		const char	*cversion = [version UTF8String];
		
		if (cversion)
			return cversion;
		
		return "";
	}
}

std::string TCCocoaConfig::get_client_name() const
{
	// Give the ability to the user to customize the name for anonymity
	
	NSString	*value = [fcontent objectForKey:TCCONF_KEY_CLIENT_NAME];
	const char	*c_value = [value UTF8String];
	
	if (c_value)
		return c_value;
	else
		return "TorChat for Mac";
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

