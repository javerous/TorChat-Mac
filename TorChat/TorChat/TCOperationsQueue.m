/*
 *  TCOperationsQueue.m
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


#import "TCOperationsQueue.h"



/*
** BSTOperationsItem - Interface
*/
#pragma mark - BSTOperationsItem - Interface

@interface BSTOperationsItem : NSObject

@property (strong, nonatomic) TCOperationsQueue	*operations;

@property (strong, nonatomic) TCOperationsBlock	block;
@property (strong, nonatomic) dispatch_queue_t		queue;

@end



/*
** TCOperationsQueue - Private
*/
#pragma mark - TCOperationsQueue - Private

@interface TCOperationsQueue ()
{
	dispatch_queue_t _localQueue;

	NSMutableArray	*_pending;
	BOOL			_isExecuting;
	BOOL			_isStarted;
}

@end



/*
** TCOperationsQueue
*/
#pragma mark - TCOperationsQueue

@implementation TCOperationsQueue


/*
** TCOperationsQueue - Instance
*/
#pragma mark - TCOperationsQueue - Instance

- (id)init
{
    self = [super init];
	
    if (self)
	{
        _pending = [[NSMutableArray alloc] init];
		
		_localQueue = dispatch_queue_create("com.sourcemac.torchat.operation_queue.local", DISPATCH_QUEUE_SERIAL);
    }
	
    return self;
}

- (id)initStarted
{
	self = [self init];
	
	if (self)
	{
		_isStarted = YES;
	}
	
	return self;
}



/*
** TCOperationsQueue - Life
*/
#pragma mark - TCOperationsQueue - Life

- (void)start
{
	dispatch_async(_localQueue, ^{
		
		if (_isStarted)
			return;
		
		_isStarted = YES;
		
		[self _continue];
	});
}



/*
** TCOperationsQueue - Schedule
*/
#pragma mark - TCOperationsQueue - Schedule

- (void)scheduleBlock:(TCOperationsBlock)block
{
	dispatch_queue_t queue = _defaultQueue;
	
	if (!queue)
		queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	[self scheduleOnQueue:queue block:block];
}

- (void)scheduleOnQueue:(dispatch_queue_t)queue block:(TCOperationsBlock)block
{
	if (!queue || !block)
		return;
	
	BSTOperationsItem *item = [[BSTOperationsItem alloc] init];
	
	item.operations = self;
	item.queue = queue;
	item.block = block;
	
	dispatch_async(_localQueue, ^{
		if (_isExecuting == NO && _isStarted == YES)
			[self _executeItem:item];
		else
			[_pending addObject:item];
	});
}



/*
** TCOperationsQueue - Helpers
*/
#pragma mark - TCOperationsQueue - Helpers

- (void)_scheduleNextItem
{
	// > localQueue <
	
	if ([_pending count] == 0)
		return;
	
	BSTOperationsItem *item = _pending[0];
	
	[_pending removeObjectAtIndex:0];
	
	[self _executeItem:item];
}

- (void)_executeItem:(BSTOperationsItem *)item
{
	// > localQueue <
	
	if (!item)
		return;
	
	// Mark as executing.
	_isExecuting = YES;
	
	// Execute block.
	dispatch_async(item.queue, ^{
		
		// > Controller.
		__block BOOL executed = NO;
		
		TCOperationsControl ctrl = ^(TCOperationsControlType type) {
			
			dispatch_async(_localQueue, ^{
				
				if (executed)
					return;
				
				executed = YES;
				_isExecuting = NO;
				
				switch (type)
				{
					case TCOperationsControlContinue:
					{
						[self _continue];
						break;
					}
						
					case TCOperationsControlFinish:
					{
						[self _stop];
						break;
					}
				}
			});
		};
		
		// > Call block.
		item.block(ctrl);
	});
}



/*
** TCOperationsQueue - Control
*/
#pragma mark - TCOperationsQueue - Control

- (void)_continue
{
	// > localQueue <

	dispatch_block_t tHandler = self.finishHandler;

	if ([_pending count] > 0)
		[self _scheduleNextItem];
	else if (tHandler)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ tHandler(); });
}

- (void)_stop
{
	// > localQueue <

	[_pending removeAllObjects];
	
	dispatch_block_t tHandler = self.finishHandler;

	if (tHandler)
		dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{ tHandler(); });
}

@end



/*
** BSTOperationsItem
*/
#pragma mark - BSTOperationsItem

@implementation BSTOperationsItem

@end
