/*
 *  TCTorManager.h
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



#import <Cocoa/Cocoa.h>

#import "TCConfig.h"


/*
** Globals
*/
#pragma mark - Globals

#define TCTorManagerInfoDomain	@"TCTorManagerInfoDomain"



/*
** Forward
*/
#pragma mark - Forward

@class TCInfo;



/*
** Types
*/
#pragma mark - Types

typedef enum
{
	TCTorManagerEventRunning,	// context = nil
	TCTorManagerEventStopped,	// context = nil
	TCTorManagerEventError,		// context = NSError
	
	TCTorManagerEventHostname	// context = NSString(hostname)
} TCTorManagerEvent;

typedef enum
{
	xyz_fixme
} TCTorManagerError;



/*
** TCTorManager
*/
#pragma mark - TCTorManager

@interface TCTorManager : NSObject

// -- Instance --
- (id)initWithConfiguration:(id <TCConfig>)configuration;

// -- Life --
- (void)start;
- (void)stop;

- (BOOL)isRunning;

// -- Update --
- (void)checkForUpdateWithResultHandler:(void (^)(NSString *newVersion, TCInfo *error))handler;

// -- Property --
- (NSString *)hiddenHostname;

// -- Events --
@property (strong, atomic) void (^eventHandler)(TCTorManagerEvent event, id context);

@end
