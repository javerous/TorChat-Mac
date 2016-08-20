/*
 *  TCMainController.h
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

#import <Cocoa/Cocoa.h>

#import "TCConfigAppEncryptable.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TCMainControllerErrorDomain @"TCMainControllerErrorDomain"



/*
** Forward
*/
#pragma mark - Forward

@class TCCoreManager;



/*
** TCMainController
*/
#pragma mark - TCMainController

@interface TCMainController : NSObject

// -- Instance --
+ (TCMainController *)sharedController;

// -- Life --
- (void)startWithCompletionHandler:(void (^)(id <TCConfigAppEncryptable> _Nullable configuration, TCCoreManager * _Nullable core, NSError * _Nullable error))handler;
- (void)startWithConfiguration:(id <TCConfigAppEncryptable>)configuration completionHandler:(void (^)(TCCoreManager * _Nullable core, NSError * _Nullable error))handler;

- (void)stopWithCompletionHandler:(dispatch_block_t)handler;

// -- Properties --
@property (strong, readonly, nonatomic) id <TCConfigAppEncryptable>	configuration;
@property (strong, readonly, nonatomic) TCCoreManager				*core;

@end


NS_ASSUME_NONNULL_END
