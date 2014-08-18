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

#define TCTorManagerInfoStartDomain		@"TCTorManagerInfoStartDomain"
#define TCTorManagerInfoUpdateDomain	@"TCTorManagerInfoUpdateDomain"

#define TCTorManagerInfoOperationDomain	@"TCTorManagerInfoOperationDomain"




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
	TCTorManagerLogStandard,
	TCTorManagerLogError
} TCTorManagerLogKind;

typedef enum
{
	// -- Event --
	TCTorManagerEventStartHostname,
	TCTorManagerEventStartDone,
	
	// -- Error --
	TCTorManagerErrorStartAlreadyRunning,
	
	TCTorManagerErrorStartConfiguration,
	TCTorManagerErrorStartUnarchive,
	TCTorManagerErrorStartSignature,
	TCTorManagerErrorStartLaunch,
} TCTorManagerInfoStart;


typedef enum
{
	// -- Event --
	TCTorManagerEventUpdateAvailable,		// context: @{ @"old_version" : NSString, @"new_version" : NSString }
	
	// -- Error --
	TCTorManagerErrorUpdateNetworkRequest,	// context: NSError
	TCTorManagerErrorUpdateBadServerReply,
	TCTorManagerErrorUpdateRemoteInfo,		// info: TCInfo (<operation error>)
	TCTorManagerErrorUpdateLocalSignature,	// info: TCInfo (<operation error>)

	TCTorManagerErrorUpdateNothingNew,
	
} TCTorManagerInfoUpdate;

typedef enum
{
	// -- Event --
	TCTorManagerEventInfo,			// context: NSDictionary
	TCTorManagerEventDone,

	// -- Error --
	TCTorManagerErrorConfiguration,
	TCTorManagerErrorIO,
	TCTorManagerErrorNetwork,		// context
	TCTorManagerErrorExtract,		// context: NSNumber (<tar result>)
	TCTorManagerErrorSignature,		// context: NSString (<path to the problematic file>)
	TCTorManagerErrorTor,			// context: NSNumber (<tor result>)

	TCTorManagerErrorInternal

} TCTorManagerInfoOperation;



/*
** TCTorManager
*/
#pragma mark - TCTorManager

@interface TCTorManager : NSObject

// -- Instance --
- (id)initWithConfiguration:(id <TCConfig>)configuration;

// -- Life --
- (void)startWithHandler:(void (^)(TCInfo *info))handler;
- (void)stop;

- (BOOL)isRunning;

// -- Update --
- (void)checkForUpdateWithCompletionHandler:(void (^)(TCInfo *info))handler;
- (void)updateWithHandler:(void (^)())handler;


// -- Property --
- (NSString *)hiddenHostname;

// -- Events --
@property (strong, atomic) void (^logHandler)(TCTorManagerLogKind kind, NSString *log);

@end
