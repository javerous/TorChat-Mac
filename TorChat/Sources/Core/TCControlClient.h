/*
 *  TCControlClient.h
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



#ifndef _TCCONTROLCLIENT_H_
# define _TCCONTROLCLIENT_H_

# include <vector>
# include <string>

# include <dispatch/dispatch.h>

# include "TCBuffer.h"
# include "TCController.h"
# import "TCSocket.h"
# include "TCObject.h"

#import "TCParser.h"

#import "TCConfig.h"


/*
** Forward
*/
#pragma mark - Forward

class TCBuddy;



/*
** TCControlClient
*/
#pragma mark - TCControlClient

// == Class ==
class TCControlClient : public TCObject
{
public:
	// -- Instance --
	TCControlClient(id <TCConfig> conf, int sock);
	~TCControlClient();
	
	// -- Running --
	void start(TCController *controller);
	void stop();
	
private:
	// -- TCParser Command --
	virtual void	doPing(const std::string &address, const std::string &random);
	virtual void	doPong(const std::string &random);
	
	virtual void	parserError(tcrec_error err, const std::string &info);
	
	// -- Socket delegate --
	virtual void socketOperationAvailable(TCSocket *socket, tcsocket_operation operation, int tag, void *content, size_t size);
	virtual void socketError(TCSocket *socket, TCInfo *err);
	
	// -- Helper --
	void	_error(tcctrl_info code, const std::string &info, bool fatal);
	void	_error(tcctrl_info code, const std::string &info, TCObject *ctx, bool fatal);
	void	_error(tcctrl_info code, const std::string &info, TCInfo *serr, bool fatal);
	
	void	_notify(tcctrl_info notice, const std::string &info);
	
	bool	_isBlocked(const std::string &address);

	
	// -- Vars --
	// > Running
	bool					running;
    
	// > Socket
	int						sockd;
	TCSocket				*sock;
	
	// > Controller
	__weak TCController		*_ctrl;
	
	// > Config
	id <TCConfig>			config;
	
	// > Queue
	dispatch_queue_t		mainQueue;
	
	std::string				last_ping_address;
	
};

#endif
