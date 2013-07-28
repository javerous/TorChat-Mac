/*
 *  TCConfig.h
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



#ifndef _TCCONFIG_H_
# define _TCCONFIG_H_

# include <string>
# include <map>
# include <vector>

# include "TCObject.h"
# import "TCImage.h"


/*
** Defines
*/
#pragma mark - Defines

# define TCConfigBuddyAddress	"address"
# define TCConfigBuddyAlias		"alias"
# define TCConfigBuddyNotes		"notes"
# define TCConfigBuddyLastName	"lname"




/*
** Types
*/
#pragma mark - Types

typedef std::map<std::string, std::string>	tc_dictionary;
typedef std::vector< tc_dictionary >		tc_darray;
typedef std::vector< std::string >			tc_sarray;

typedef enum
{
	tc_config_get_default,	// Value used when the item was never set
	tc_config_get_defined,	// Value used when the item was set
	tc_config_get_real		// Value to use in standard case (eg. defined / default automatic choise)
} tc_config_get; // FIXME: use in all get_* functions

typedef enum
{
	tc_config_advanced,
	tc_config_basic
} tc_config_mode;

typedef enum
{
	tc_config_title_address = 0,
	tc_config_title_name	= 1
} tc_config_title;



/*
** TCConfig
*/
#pragma mark - TCConfig

class TCConfig: public TCObject
{
public:
	
	// -- Tor --
	virtual std::string 	get_tor_address() const = 0;
	virtual void			set_tor_address(const std::string &address) = 0;
	
	virtual uint16_t		get_tor_port() const = 0;
	virtual void			set_tor_port(uint16_t port) = 0;
	
	virtual	std::string 	get_tor_path() const = 0;
	virtual void			set_tor_path(const std::string &path) = 0;
	
	virtual	std::string 	get_tor_data_path() const = 0;
	virtual void			set_tor_data_path(const std::string &path) = 0;
	
	// -- TorChat --
	virtual	std::string 	get_self_address() const = 0;
	virtual void			set_self_address(const std::string &address) = 0;
	
	virtual	uint16_t		get_client_port() const = 0;
	virtual void			set_client_port(uint16_t port) = 0;
	
	virtual	std::string 	get_download_folder() const = 0;
	virtual void			set_download_folder(const std::string & folder) = 0;
	
	// -- Mode --
	virtual	tc_config_mode	get_mode() const = 0;
	virtual void			set_mode(tc_config_mode mode) = 0;
	
	// -- Profile --
	virtual	std::string		get_profile_name() = 0;
	virtual void			set_profile_name(const std::string & name) = 0;
	
	virtual	std::string		get_profile_text() = 0;
	virtual void			set_profile_text(const std::string & text) = 0;
	
	virtual	TCImage *		get_profile_avatar() = 0;
	virtual void			set_profile_avatar(const TCImage * picture) = 0;
	
	// -- Buddies --
	virtual const tc_darray &buddies() = 0;
	virtual void			add_buddy(const std::string &address, const std::string &alias, const std::string &notes) = 0;
	virtual bool			remove_buddy(const std::string &address) = 0;
	
	virtual void			set_buddy_alias(const std::string &address, const std::string &alias) = 0;
	virtual void			set_buddy_notes(const std::string &address, const std::string &notes) = 0;
	virtual void			set_buddy_last_profile_name(const std::string &address, const std::string &lname) = 0;
	
	virtual std::string		get_buddy_alias(const std::string &address) const = 0;
	virtual std::string		get_buddy_notes(const std::string &address) const = 0;
	virtual std::string		get_buddy_last_profile_name(const std::string &address) const = 0;
	
	// -- Blocked --
	virtual const tc_sarray &blocked_buddies() = 0;
	virtual bool			add_blocked_buddy(const std::string &address) = 0;
	virtual bool			remove_blocked_buddy(const std::string &address) = 0;
	
	// -- UI --
	virtual tc_config_title	get_mode_title() const = 0;
	virtual void			set_mode_title(tc_config_title mode) = 0;
	
	// -- Client --
	virtual  std::string	get_client_version(tc_config_get get = tc_config_get_real) const = 0;
	virtual  void			set_client_version(const std::string &version) = 0;
	
	virtual  std::string	get_client_name(tc_config_get get = tc_config_get_real) const = 0;
	virtual  void			set_client_name(const std::string &name) = 0;

	// -- Tools --
	virtual std::string		real_path(const std::string &path) const = 0;
	
	// -- Localization --
	virtual std::string		localized(const std::string &key) const = 0;
};

#endif
