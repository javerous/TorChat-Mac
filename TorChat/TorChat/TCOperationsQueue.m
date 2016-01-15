/*
 *  TCOperationsQueue.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
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

@property (strong, nonatomic) TCOperationsCancelableBlock	block;
@property (strong, nonatomic) dispatch_queue_t				queue;

@end



/*
** TCOperationsQueue - Private
*/
#pragma mark - TCOperationsQueue - Private

@interface TCOperationsQueue ()
{
	dispatch_queue_t _localQueue;
	dispatch_queue_t _userQueue;

	NSMutableArray	*_pending;
	BOOL			_isExecuting;
	BOOL			_isStarted;
	
	NSMutableArray	*_cancelBlocks;
	BOOL			_isCanceled;
	
	BOOL			_isFinished;
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
		
		_localQueue = dispatch_queue_create("com.torchat.app.operation-queue.local", DISPATCH_QUEUE_SERIAL);
		_userQueue = dispatch_queue_create("com.torchat.app.operation-queue.user", DISPATCH_QUEUE_SERIAL);
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
	[self scheduleCancelableBlock:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
		block(ctrl);
	}];
}

- (void)scheduleOnQueue:(dispatch_queue_t)queue block:(TCOperationsBlock)block
{
	[self scheduleCancelableOnQueue:queue block:^(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock) {
		block(ctrl);
	}];
}

- (void)scheduleCancelableBlock:(TCOperationsCancelableBlock)block
{
	dispatch_queue_t queue = _defaultQueue;
	
	if (!queue)
		queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
	
	[self scheduleCancelableOnQueue:queue block:block];
}

- (void)scheduleCancelableOnQueue:(dispatch_queue_t)queue block:(TCOperationsCancelableBlock)block
{
	if (!queue || !block)
		return;
	
	BSTOperationsItem *item = [[BSTOperationsItem alloc] init];
	
	item.operations = self;
	item.queue = queue;
	item.block = block;
	
	dispatch_async(_localQueue, ^{
		
		if (_isCanceled)
			return;
		
		if (_isExecuting == NO && _isStarted == YES)
			[self _executeItem:item];
		else
			[_pending addObject:item];
	});
}

- (void)cancel
{
	dispatch_async(_localQueue, ^{
		
		if (_isCanceled)
			return;
		
		_isCanceled = YES;
		
		// Nothing cancelable.
		if (_isFinished)
			return;
		
		// Call current cancel blocks.
		for (dispatch_block_t block in _cancelBlocks)
			dispatch_async(_userQueue, block);
		
		[_cancelBlocks removeAllObjects];
		
		// Call cancel handler.
		void (^tHandler)(BOOL canceled) = self.finishHandler;
		
		if (tHandler)
			dispatch_async(_userQueue, ^{ tHandler(YES); });
		
		// Remove pending.
		[_pending removeAllObjects];
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
	_isFinished = NO;
	
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
				_cancelBlocks = nil;
				
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
		
		// > Cancelation.
		TCOperationsAddCancelBlock addCancelBlock = ^(dispatch_block_t cancelBlock) {
			
			if (!cancelBlock)
				return;
			
			dispatch_async(_localQueue, ^{
				
				// Can't add cancel block after the operation is fully executed.
				if (executed)
					return;
				
				// If already canceled, cancel right now.
				if (_isCanceled)
				{
					dispatch_async(_userQueue, ^{
						cancelBlock();
					});
					return;
				}
				
				// Store cancel block.
				if (!_cancelBlocks)
					_cancelBlocks = [[NSMutableArray alloc] init];
				
				[_cancelBlocks addObject:cancelBlock];
			});
		};
		
		// > Call block.
		item.block(ctrl, addCancelBlock);
	});
}



/*
** TCOperationsQueue - Control
*/
#pragma mark - TCOperationsQueue - Control

- (void)_continue
{
	// > localQueue <

	if (_isCanceled)
		return;
	
	void (^tHandler)(BOOL canceled) = self.finishHandler;

	if ([_pending count] > 0)
	{
		[self _scheduleNextItem];
	}
	else
	{
		_isFinished = YES;
		
		if (tHandler)
			dispatch_async(_userQueue, ^{ tHandler(NO); });
	}
}

- (void)_stop
{
	// > localQueue <

	if (_isCanceled)
		return;
	
	_isFinished = YES;
	
	[_pending removeAllObjects];
	
	void (^tHandler)(BOOL canceled) = self.finishHandler;

	if (tHandler)
		dispatch_async(_userQueue, ^{ tHandler(NO); });
}

@end



/*
** BSTOperationsItem
*/
#pragma mark - BSTOperationsItem

@implementation BSTOperationsItem

@end
