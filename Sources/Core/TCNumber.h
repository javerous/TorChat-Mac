/*
 *  TCNumber.h
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



#ifndef _TCNUMBER_H_
# define _TCNUMBER_H_

# include "TCObject.h"



/*
** Macros
*/
#pragma Macros

#define ReturnCasted(TargetType)				\
do	{											\
	switch (_type)								\
	{											\
		case tcnumber_uint8:					\
			return (TargetType)(_content.u8);	\
		case tcnumber_uint16:					\
			return (TargetType)(_content.u16);	\
		case tcnumber_float:					\
			return (TargetType)(_content.f);	\
	}											\
} while (0)


/*
** Types
*/
#pragma mark -
#pragma mark Types

typedef enum
{
	tcnumber_uint8,
	tcnumber_uint16,
	tcnumber_float,
} tcnumber_type;



/*
** TCNumber
*/
#pragma mark -
#pragma mark TCNumber

class TCNumber: public TCObject
{
public:
	TCNumber(uint8_t value)
	{
		_type = tcnumber_uint8;
		_content.u8 = value;
	}
	
	TCNumber(uint16_t value)
	{
		_type = tcnumber_uint16;
		_content.u16 = value;
	}
	
	TCNumber(float value)
	{
		_type = tcnumber_float;
		_content.f = value;
	}
	
	tcnumber_type type() { return _type; }
	
	uint8_t		uint8Value() { ReturnCasted(uint8_t); return 0; }
	uint16_t	uint16Value() { ReturnCasted(uint16_t); return 0; }
	float		floatValue() { ReturnCasted(float); return 0.0; }
	
private:
	tcnumber_type	_type;
	
	union
	{
		uint8_t		u8;
		uint16_t	u16;
		float		f;
	} _content;
};

#endif
