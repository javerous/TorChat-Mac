/*
 *  TCSpeedHelper.m
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

#import "TCSpeedHelper.h"

#import "TCTimeHelper.h"


/*
** TCSpeedHelper
*/
#pragma mark - TCSpeedHelper

@implementation TCSpeedHelper
{
	dispatch_queue_t _localQueue;
	
	NSUInteger	_currentAmount;
	NSUInteger	_completeAmount;
	
	double			_lastSet;
	NSMutableArray	*_amounts;
	NSMutableArray	*_timestamps;

	dispatch_source_t	_timer;
	BOOL				_isTimer;
}


/*
** TCSpeedHelper - Instance
*/
#pragma mark - TCSpeedHelper - Instance

- (instancetype)initWithCompleteAmount:(NSUInteger)amount
{
	self = [super init];
	
	if (self)
	{
		_localQueue = dispatch_queue_create("com.torchat.app.speed-helper.local", DISPATCH_QUEUE_SERIAL);
		_completeAmount = amount;
		
		_amounts = [[NSMutableArray alloc] init];
		_timestamps = [[NSMutableArray alloc] init];
	}
	
	return self;
}



/*
** TCSpeedHelper - Update
*/
#pragma mark - TCSpeedHelper - Update

- (void)setCurrentAmount:(NSUInteger)currentAmout
{
	double ts = TCTimeStamp();
	
	dispatch_async(_localQueue, ^{
		[self _setCurrentAmount:currentAmout timestamp:ts];
	});
}

- (void)addAmount:(NSUInteger)amount
{
	double ts = TCTimeStamp();

	dispatch_async(_localQueue, ^{
		
		NSUInteger newAmount = _currentAmount + amount;
		
		[self _setCurrentAmount:newAmount timestamp:ts];
	});
}


- (void)_setCurrentAmount:(NSUInteger)currentAmout timestamp:(double)ts
{
	if (currentAmout == 0 || currentAmout > _completeAmount || currentAmout < _currentAmount)
		return;
	
	if (ts - _lastSet < 1.0)
		return;
	
	// Update stats.
	_lastSet = ts;
	
	_currentAmount = currentAmout;
	
	[_amounts addObject:@(currentAmout)];
	[_timestamps addObject:@(ts)];
	
	if (_amounts.count > 5)
		[_amounts removeObjectAtIndex:0];
	
	if (_timestamps.count > 5)
		[_timestamps removeObjectAtIndex:0];
	
	// Start timer if necessary.
	if (_isTimer == NO && _amounts.count >= 2)
	{
		void (^updateHandler)(NSTimeInterval remainingTime) = self.updateHandler;
		
		if (updateHandler)
		{
			__weak TCSpeedHelper *weakSelf = self;
			
			_timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, _localQueue);
			
			dispatch_source_set_timer(_timer, DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC, 0);
			
			dispatch_source_set_event_handler(_timer, ^{
				
				TCSpeedHelper *strongSelf = weakSelf;
				
				if (!strongSelf)
					return;
				
				updateHandler([strongSelf _remainingTime]);
			});
			
			dispatch_resume(_timer);
			
			_isTimer = YES;
		}
	}
}



/*
** TCSpeedHelper - Compute
*/
#pragma mark - TCSpeedHelper - Compute

- (double)averageSpeed
{
	__block double result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _averageSpeed];
	});
	
	return result;
}

- (double)_averageSpeed
{
	// > localQueue <
	
	if (_timestamps.count < 2 || _amounts.count < 2)
		return -2.0;
	
	double ts1 = [[_timestamps firstObject] doubleValue];
	double ts2 = [[_timestamps lastObject] doubleValue];
	
	NSUInteger am1 = [[_amounts firstObject] unsignedIntegerValue];
	NSUInteger am2 = [[_amounts lastObject] unsignedIntegerValue];
	
	double delta = (ts2 - ts1);
	
	if (delta == 0)
		return 0;
	
	return (double)(am2 - am1) / delta;
}

- (NSTimeInterval)remainingTime
{
	__block NSTimeInterval result;
	
	dispatch_sync(_localQueue, ^{
		result = [self _remainingTime];
	});
	
	return result;
}

- (NSTimeInterval)_remainingTime
{
	// > localQueue <

	double speed = [self _averageSpeed];
	
	if (speed == -2.0)
		return -2.0;
	
	if (speed == 0.0)
		return -1.0;
	
	NSUInteger remainingAmount = _completeAmount - _currentAmount;
	
	return (double)remainingAmount / speed;
}


@end
