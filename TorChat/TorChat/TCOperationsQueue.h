/*
 *  TCOperationsQueue.h
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

#import <Foundation/Foundation.h>


/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCOperationsControlContinue,
	TCOperationsControlFinish
} TCOperationsControlType;

typedef void (^TCOperationsControl)(TCOperationsControlType type);
typedef void (^TCOperationsBlock)(TCOperationsControl ctrl);

typedef void (^TCOperationsAddCancelBlock)(dispatch_block_t block);
typedef void (^TCOperationsCancelableBlock)(TCOperationsControl ctrl, TCOperationsAddCancelBlock addCancelBlock);


/*
** TCOperationsQueue
*/
#pragma mark - TCOperationsQueue

@interface TCOperationsQueue : NSObject

// -- Properties --
@property (strong, atomic) dispatch_queue_t defaultQueue;

// -- Instance --
- (id)init;
- (id)initStarted;

// -- Schedule --
- (void)scheduleBlock:(TCOperationsBlock)block;
- (void)scheduleOnQueue:(dispatch_queue_t)queue block:(TCOperationsBlock)block;

- (void)scheduleCancelableBlock:(TCOperationsCancelableBlock)block;
- (void)scheduleCancelableOnQueue:(dispatch_queue_t)queue block:(TCOperationsCancelableBlock)block;


// -- Life --
- (void)start;

- (void)cancel;


// -- Handler --
@property (strong, atomic) void (^finishHandler)(BOOL canceled); // Called each time the operation queue become empty or queue was canceled.

@end
