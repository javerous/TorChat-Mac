/*
 *  TCKVOHelper.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

#import "TCKVOHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** GLobals
*/
#pragma mark - GLobals

const id gNoEntryToken = @"<no-entry>";



/*
** TCKVOHelperEntry - Interface
*/
#pragma mark TCKVOHelperEntry - Interface

@interface TCKVOHelperEntry : NSObject

@property (nullable, nonatomic) TCKVOHelperEntry *selfRetain;

@property (nonatomic) void (^handler)(id <NSObject> object, id newContent);
@property (nonatomic) dispatch_queue_t queue;


@property (nonatomic) NSObject *object;
@property (nonatomic) NSString *keyPath;

@property (nonatomic) BOOL oneShot;

@end



/*
** TCKVOHelper
*/
#pragma mark TCKVOHelper

@implementation TCKVOHelper


/*
** TCKVOHelper - Instance
*/
#pragma mark TCKVOHelper - Instance

+ (TCKVOHelper*)sharedHelper
{
	static dispatch_once_t	onceToken;
	static TCKVOHelper		*shr;
	
	dispatch_once(&onceToken, ^{
		shr = [[TCKVOHelper alloc] init];
	});
	
	return shr;
}


/*
** TCKVOHelper - Observers
*/
#pragma mark TCKVOHelper - Observers

- (id)addObserverOnObject:(NSObject *)object forKeyPath:(NSString *)keyPath observationHandler:(void (^)(id <NSObject> object, id newContent))handler
{
	return [self addObserverOnObject:object forKeyPath:keyPath oneShot:YES observationQueue:nil observationHandler:handler];
}

- (id)addObserverOnObject:(NSObject *)object forKeyPath:(NSString *)keyPath oneShot:(BOOL)oneShot observationQueue:(nullable dispatch_queue_t)queue observationHandler:(void (^)(id <NSObject> object, id newContent))handler
{
	NSAssert(object, @"object is nil");
	NSAssert(keyPath, @"keyPath is nil");
	NSAssert(handler, @"handler is nil");

	if (!queue)
		queue = dispatch_get_main_queue();
	
	// Check if there is a current value.
	id currentValue = [object valueForKeyPath:keyPath];
	
	if (currentValue)
	{
		dispatch_async(queue, ^{
			handler(object, currentValue);
		});
		
		if (oneShot)
			return gNoEntryToken;
	};
	
	// Prepare observation entry.
	TCKVOHelperEntry *entry = [[TCKVOHelperEntry alloc] init];
	
	entry.selfRetain = entry;
	entry.handler = handler;
	entry.object = object;
	entry.keyPath = keyPath;
	entry.oneShot = oneShot;
	entry.queue = queue;
	
	// Add observer.
	[object addObserver:entry forKeyPath:keyPath options:NSKeyValueObservingOptionNew context:NULL];
	
	// Return entry as opaque object.
	return entry;
}

- (void)removeObserver:(id)observer
{
	NSAssert(observer, @"observer is nil");
	
	if (observer == gNoEntryToken)
		return;
	
	// Get entry.
	TCKVOHelperEntry *entry = observer;
	
	if (!entry)
		return;
	
	entry.selfRetain = nil;
	
	// Remove observer of the original object.
	NSObject *object = entry.object;
	
	@try {
		[object removeObserver:entry forKeyPath:entry.keyPath];
	} @catch (NSException *exception) { }
}

@end




/*
** TCKVOHelperEntry
*/
#pragma mark TCKVOHelperEntry

@implementation TCKVOHelperEntry

- (void)observeValueForKeyPath:(nullable NSString *)keyPath ofObject:(nullable id)object change:(nullable NSDictionary<NSKeyValueChangeKey, id> *)change context:(nullable void *)context
{
	if ([keyPath isEqualToString:_keyPath] == NO)
		return;
	
	if (object != _object)
		return;
	
	NSNumber	*changeKind = change[NSKeyValueChangeKindKey];
	id			content = change[NSKeyValueChangeNewKey];
	
	if (!changeKind || !content)
		return;
	
	if (changeKind.integerValue != NSKeyValueChangeSetting || [content isKindOfClass:[NSNull class]])
		return;
	
	dispatch_async(_queue, ^{
		_handler(object, content);
	});
	
	if (_oneShot)
	{
		@try {
			[object removeObserver:self forKeyPath:_keyPath];
		} @catch (NSException *exception) { }
		
		_selfRetain = nil;
	}
}

@end


NS_ASSUME_NONNULL_END
