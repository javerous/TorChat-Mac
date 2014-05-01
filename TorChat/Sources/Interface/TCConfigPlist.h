/*
 *  TCConfigPlist.h
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


#import "TCConfig.h"

#if defined(PROXY_ENABLED) && PROXY_ENABLED
# import "TCConfigProxy.h"
#endif



/*
** TCConfigPlist
*/
#pragma mark - TCConfigPlist

@interface TCConfigPlist : NSObject <TCConfig>

// -- Instance --
- (id)initWithFile:(NSString *)filepath;

#if defined(PROXY_ENABLED) && PROXY_ENABLED
- (id)initWithFileProxy:(id <TCConfigProxy>)proxy;
#endif

@end


#if 0
#ifndef _TCConfigPlist_H_
# define _TCConfigPlist_H_

# import <Cocoa/Cocoa.h>

# include "TCConfig.h"





/*
** TCConfigPlist
*/
#pragma mark - TCConfigPlist

class TCConfigPlist : public TCConfig
{
public:
	// -- Instance
	TCConfigPlist(NSString *filepath);
	
#if defined(PROXY_ENABLED) && PROXY_ENABLED
	TCConfigPlist(id <TCConfigProxy> proxy);
#endif
	
	~TCConfigPlist();
	
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
	void			set_profile_avatar(const TCImage * picture);
	
	// -- Buddies --
	const tc_darray	&buddies();
	void			add_buddy(const std::string &address, const std::string &alias, const std::string &notes);
	bool			remove_buddy(const std::string &address);
	
	void			set_buddy_alias(const std::string &address, const std::string &alias);
	void			set_buddy_notes(const std::string &address, const std::string &notes);
	void			set_buddy_last_profile_name(const std::string &address, const std::string &lname);

	std::string		get_buddy_alias(const std::string &address) const;
	std::string		get_buddy_notes(const std::string &address) const;
	std::string		get_buddy_last_profile_name(const std::string &address) const;
	
	// -- Blocked --
	const tc_sarray &blocked_buddies();
	bool			add_blocked_buddy(const std::string &address);
	bool			remove_blocked_buddy(const std::string &address);
	
	// -- UI --
	tc_config_title	get_mode_title() const;
	void			set_mode_title(tc_config_title mode);
	
	// -- Client --
	std::string		get_client_version(tc_config_get get = tc_config_get_real) const;
	void			set_client_version(const std::string &version);

	std::string		get_client_name(tc_config_get get = tc_config_get_real) const;
	void			set_client_name(const std::string &name);
	
	// -- Tools --
	std::string		real_path(const std::string &path) const;
	
	// -- Localization --
	std::string		localized(const std::string &key) const;

private:

};

#endif

#endif

