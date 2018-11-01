/*
 *  TCKVOHelper.h
 *
 *  Copyright 2018 Avérous Julien-Pierre
 *
 *  This file is part of TorChat.
 *
 *  TorProxifier is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  TorProxifier is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with TorProxifier.  If not, see <http://www.gnu.org/licenses/>.
 *
 */

#import <Foundation/Foundation.h>


NS_ASSUME_NONNULL_BEGIN


/*
** TCKVOHelper
*/
#pragma mark - TCKVOHelper

@interface TCKVOHelper : NSObject

// -- Instance --
+ (TCKVOHelper*)sharedHelper;

// -- Observers --
- (id)addObserverOnObject:(NSObject *)object forKeyPath:(NSString *)keyPath observationHandler:(void (^)(id <NSObject> object, id newContent))handler;
- (id)addObserverOnObject:(NSObject *)object forKeyPath:(NSString *)keyPath oneShot:(BOOL)oneShot observationQueue:(nullable dispatch_queue_t)queue observationHandler:(void (^)(id <NSObject> object, id newContent))handler;

- (void)removeObserver:(id)observer;

@end

NS_ASSUME_NONNULL_END
