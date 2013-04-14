/*
 *  TCCocoaConfig.h
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



#ifndef _TCCOCOACONFIG_H_
# define _TCCOCOACONFIG_H_

# import <Cocoa/Cocoa.h>

# include "TCConfig.h"



/*
** TCCocoaConfig
*/
#pragma mark -
#pragma mark TCCocoaConfig

class TCCocoaConfig : public TCConfig
{
public:
	// -- Constructor & Destructor
	TCCocoaConfig(NSString *filepath);
	~TCCocoaConfig();
	
	// -- Tor --
	std::string		get_tor_address() const;
	void			set_tor_address(const std::string &address);
	
	uint16_t		get_tor_port() const;
	void			set_tor_port(uint16_t port);
	
	std::string 	get_tor_path() const;
	void			set_tor_path(const std::string &path);
	
	std::string 	get_tor_data_path() const;
	void			set_tor_data_path(const std::string &path);
	
	// -- TorChat --
	std::string		get_self_address() const;
	void			set_self_address(const std::string &address);
	
	uint16_t		get_client_port() const;
	void			set_client_port(uint16_t port);
	
	std::string		get_download_folder() const;
	void			set_download_folder(const std::string & folder);
	
	// -- Mode --
	tc_config_mode	get_mode() const;
	void			set_mode(tc_config_mode mode);

	// -- Profile --
	std::string		get_profile_name();
	void			set_profile_name(const std::string & name);
	
	std::string		get_profile_text();
	void			set_profile_text(const std::string & text);
	
	TCImage *		get_profile_avatar();
	void			set_profile_avatar(const TCImage & picture);
	
	// -- Buddies --
	const tc_array	&buddies();
	void			add_buddy(const std::string &address, const std::string &alias, const std::string &notes);
	bool			remove_buddy(const std::string &address);
	void			set_buddy_alias(const std::string &address, const std::string &alias);
	void			set_buddy_notes(const std::string &address, const std::string &notes);
	std::string		get_buddy_alias(const std::string &address) const;
	std::string		get_buddy_notes(const std::string &address) const;
	
	// -- UI --
	tc_config_title	get_mode_title() const;
	void			set_mode_title(tc_config_title mode);
	
	// -- Client --
	std::string		get_client_version() const;
	std::string		get_client_name() const;
	
	// -- Tools --
	std::string		real_path(const std::string &path) const;
	
	// -- Localization --
	std::string		localized(const std::string &key) const;

private:
	void				_writeToFile();
	
	tc_array			_bcache;
	
	NSString			*fpath;
	NSMutableDictionary	*fcontent;
};

#endif
