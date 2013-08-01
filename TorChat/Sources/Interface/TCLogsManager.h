//
//  TCLogsManager.h
//  TorChat
//
//  Created by Julien-Pierre Avérous on 01/08/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import <Foundation/Foundation.h>



/*
** Defines
*/
#pragma mark - Defines

#define TCLogsGlobalKey		@"_global_"



/*
** Forward
*/
#pragma mark - Forward

@class TCLogsManager;



/*
** TCLogsObserver
*/
@protocol TCLogsObserver <NSObject>

- (void)logManager:(TCLogsManager *)manager updateForKey:(NSString *)key withContent:(id)content;

@end



/*
** TCLogsManager
*/
#pragma mark - TCLogsManager

@interface TCLogsManager : NSObject

// -- Instance --
+ (TCLogsManager *)sharedManager;

// -- Logs --
- (void)addBuddyLogEntryFromAddress:(NSString *)address alias:(NSString *)alias andText:(NSString *)log, ...;
- (void)addGlobalLogEntry:(NSString *)log, ...;
- (void)addGlobalAlertLog:(NSString *)log, ...;



// -- Properties --
- (NSString *)aliasForKey:(NSString *)key;

// -- Observer --
- (void)addObserver:(id <TCLogsObserver>)observer forKey:(NSString *)key; // observer is weak referenced.
- (void)removeObserverForKey:(NSString *)key;

@end
