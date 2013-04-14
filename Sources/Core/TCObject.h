/*
 *  TCObject.h
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



#ifndef _TCOBJECT_H_
# define _TCOBJECT_H_

# include <stdio.h>
# include <dispatch/dispatch.h>



/*
** Globals
*/
#pragma mark -
#pragma mark Globals

extern dispatch_once_t	_pred;
extern dispatch_queue_t	_obj_ref_queue;



/*
** TCObject
*/
#pragma mark -
#pragma mark TCObject

// == Class ==
class TCObject
{
public:
	
	// -- Constructor & Destructor --
	
	// Init refcounting to 1, and build the global refcounting queue if not exist
	TCObject() : 
		_retCount(1)
	{
		dispatch_once(&_pred, ^{
			_obj_ref_queue = dispatch_queue_create("com.torchat.core.object.refcounting", NULL);
		});
	};
	
	// Make destructor virtual to use the child class destructors
	virtual ~TCObject() { };
	
	
	// -- Tools --
	
	// Retain the object (increment the ref counting)
	TCObject * retain()
	{
		dispatch_async(_obj_ref_queue, ^{
			_retCount++;			
		});
		
		return this;
	};
	
	// Release the object (decrement ref counting). Free when 0.
	void release()
	{
		dispatch_async(_obj_ref_queue, ^{
			_retCount--;

			if (_retCount == 0)
				delete this;
			else if (_retCount < 0)
			{
				fprintf(stderr, "*** RefCount < 0 -> Really bad karma ***\n");
			}
		});
	}
	
	
	// -- Property --

	// Get the current ref counting
	int retCount()
	{
		return _retCount;
	}
	
private:
	int _retCount;
};



/*
** Helpers
*/
#pragma mark -
#pragma mark Helpers

// -> Too bad, Block_copy and Block_release can't be customized, so we use custom function to manage retain/release on "this" (but not on included objects)
inline void dispatch_async_cpp(TCObject *obj, dispatch_queue_t queue, dispatch_block_t block)
{
	// Retain the class
	obj->retain();
	
	// Nest the block in a block that will release the class
	dispatch_block_t hat = ^{
		block();
		
		obj->release();
	};
	
	// Dispatch our hat
	dispatch_async(queue, hat);
}

inline void dispatch_sync_cpp(TCObject *obj, dispatch_queue_t queue, dispatch_block_t block)
{
	// Retain the class
	obj->retain();
	
	// Nest the block in a block that will release the class
	dispatch_block_t hat = ^{
		block();
		
		obj->release();
	};
	
	// Dispatch our hat
	dispatch_sync(queue, hat);
}

inline void dispatch_source_set_cancel_handler_cpp(TCObject *obj, dispatch_source_t source, dispatch_block_t cancel_handler)
{
	// Nest the block in a block that will release the class (retained in event handler)
	dispatch_block_t hat = ^{
		
		// Call the origin handler
		cancel_handler();
		
		// Release the class
		obj->release();
	};
	
	// Give our hat
	dispatch_source_set_cancel_handler(source, hat);
}

inline void dispatch_source_set_event_handler_cpp(TCObject *obj, dispatch_source_t source, dispatch_block_t handler)
{
	// Retain the class for the source mechanism
	obj->retain();
	
	// Give the block
	dispatch_source_set_event_handler(source, handler);
	
	// Give a default cancel handler
	dispatch_source_set_cancel_handler(source, ^{
		obj->release(); // Release the class
	});
}

inline void dispatch_after_cpp(TCObject *obj, dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block)
{
	// Retain the class
	obj->retain();
	
	// Nest the block in a block that will release the class
	dispatch_block_t hat = ^{
		block();
		
		obj->release();
	};
	
	dispatch_after(when, queue, hat);
}

#endif
