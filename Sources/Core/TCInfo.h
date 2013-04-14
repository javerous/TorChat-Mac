/*
 *  TCInfo.h
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

#ifndef _TCINFO_H_
# define _TCINFO_H_

# include <string>

# include "TCObject.h"



/*
** Types
*/
#pragma mark -
#pragma mark Types

typedef enum
{
	tcinfo_error,
	tcinfo_warning,
	tcinfo_info
} tcinfo_kind;



/*
** TCInfo
*/
#pragma mark -
#pragma mark TCInfo

class TCInfo;

// == Class ==
class TCInfo : public TCObject
{
public:
	// -- Constructors & Destructor --
	TCInfo(tcinfo_kind kind, int infocode) :
		_kind(kind),
		_infocode(infocode),
		_info(""),
		_ctx(NULL),
		_serr(NULL)
	{
		_time = time(NULL);
	};
	
	TCInfo(tcinfo_kind kind, int infocode, const std::string &info) :
		_kind(kind),
		_infocode(infocode),
		_info(info),
		_ctx(NULL),
		_serr(NULL)
	{
		_time = time(NULL);
	};
	
	
	TCInfo(tcinfo_kind kind, int infocode, const std::string &info, TCObject *ctx) :
		_kind(kind),
		_infocode(infocode),
		_info(info),
		_serr(NULL)
	{
		_time = time(NULL);
		
		if (ctx)
			ctx->retain();
		
		_ctx = ctx;
	};
	
	TCInfo(tcinfo_kind kind, int infocode, const std::string &info, TCInfo *err) :
		_kind(kind),
		_infocode(infocode),
		_info(info),
		_ctx(NULL)
	{
		_time = time(NULL);
		
		if (err)
			err->retain();
		
		_serr = err;
	};
	
	TCInfo(tcinfo_kind kind, int infocode, const std::string &info, TCObject *ctx, TCInfo *err) :
		_kind(kind),
		_infocode(infocode),
		_info(info)
	{
		_time = time(NULL);
		
		if (ctx)
			ctx->retain();
		_ctx = ctx;
		
		if (err)
			err->retain();
		_serr = err;
	}
	
	~TCInfo()
	{
		if (_ctx)
		{
			_ctx->release();
			_ctx = NULL;
		}
		
		if (_serr)
		{
			_serr->release();
			_serr = NULL;
		}
	}
	
	// -- Property --
	tcinfo_kind	kind()	const						{ return _kind; };
	int			infoCode()	const					{ return _infocode; };
	std::string	info()		const					{ return _info; };
	TCObject	*context()	const					{ return _ctx; }
	
	void		setInfo(const std::string &info)	{ _info = info; };
	
	// -- Tools --
	std::string render() const
	{
		char		buffer[15];
		char		*str; 
		std::string	result;
		
		// Add the log time
		str = ctime(&_time);
		if (str)
		{
			size_t len = strlen(str);
			
			if (len > 1)
			{
				if (str[len - 1] == '\n')
					str[len - 1] = '\0';
			}
			
			result += str;
		}
		
		// Add the errcode
		snprintf(buffer, sizeof(buffer), " - [%i]: ", _infocode);
		result += std::string(buffer);
		
		// Add the info string
		result += _info;
		
		// Ad the suberrors
		if (_serr)
			result += " " + _serr->_render();
		
		return result;
	}
	
private:
	tcinfo_kind		_kind;
	int				_infocode;
	std::string		_info;
	TCObject		*_ctx;
	time_t			_time;
	TCInfo			*_serr;
	
	
	std::string _render() const
	{
		char		buffer[15];
		std::string	result;
		
		// Add the errcode and the info
		snprintf(buffer, sizeof(buffer), "{%i - ", _infocode);
		
		result = buffer + _info;
		
		// Add the suberror
		if (_serr)
			result += " " + _serr->_render();
		
		result += "}";
		
		return result;
	}
};

#endif
