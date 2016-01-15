/*
 *  TCTorManager.h
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

#import "TCConfig.h"


/*
** Globals
*/
#pragma mark - Globals

#define TCTorManagerInfoStartDomain			@"TCTorManagerInfoStartDomain"

#define TCTorManagerInfoCheckUpdateDomain	@"TCTorManagerInfoCheckUpdateDomain"
#define TCTorManagerInfoUpdateDomain		@"TCTorManagerInfoUpdateDomain"

#define TCTorManagerInfoOperationDomain		@"TCTorManagerInfoOperationDomain"




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

// == TCTorManagerStart ==
typedef enum
{
	TCTorManagerEventStartBootstrapping,	// context: @{ @"progress" : NSNumber, @"summary" : NSString }
	TCTorManagerEventStartHostname,
	TCTorManagerEventStartURLSession,		// context: NSURLSession
	TCTorManagerEventStartDone,
} TCTorManagerEventStart;

typedef enum
{
	TCTorManagerWarningStartCanceled,
} TCTorManagerWarningStart;

typedef enum
{
	TCTorManagerErrorStartAlreadyRunning,
	TCTorManagerErrorStartConfiguration,
	TCTorManagerErrorStartUnarchive,
	TCTorManagerErrorStartSignature,
	TCTorManagerErrorStartLaunch,
	TCTorManagerErrorStartControlConnect,
	TCTorManagerErrorStartControlAuthenticate,
	TCTorManagerErrorStartControlMonitor,
} TCTorManagerErrorStart;


// == TCTorManagerInfoCheckUpdateEvent ==
typedef enum
{
	TCTorManagerEventCheckUpdateAvailable,		// context: @{ @"old_version" : NSString, @"new_version" : NSString }
} TCTorManagerEventCheckUpdate;

typedef enum
{
	TCTorManagerErrorCheckUpdateTorNotRunning,
	TCTorManagerErrorRetrieveRemoteInfo,		// info: TCInfo (<operation error>)
	TCTorManagerErrorCheckUpdateLocalSignature,	// info: TCInfo (<operation error>)

	TCTorManagerErrorCheckUpdateNothingNew,
} TCTorManagerErrorCheckUpdate;


// == TCTorManagerUpdate ==
typedef enum
{
	TCTorManagerEventUpdateArchiveInfoRetrieving,
	TCTorManagerEventUpdateArchiveSize,			// context: NSNumber (<archive size>)
	TCTorManagerEventUpdateArchiveDownloading,	// context: NSNumber (<archive bytes downloaded>)
	TCTorManagerEventUpdateArchiveStage,
	TCTorManagerEventUpdateSignatureCheck,
	TCTorManagerEventUpdateRelaunch,
	TCTorManagerEventUpdateDone,
} TCTorManagerEventUpdate;

typedef enum
{
	TCTorManagerErrorUpdateTorNotRunning,
	TCTorManagerErrorUpdateConfiguration,
	TCTorManagerErrorUpdateInternal,
	TCTorManagerErrorUpdateArchiveInfo,		// info: TCInfo (<operation error>)
	TCTorManagerErrorUpdateArchiveDownload,	// context: NSError
	TCTorManagerErrorUpdateArchiveStage,	// info: TCInfo (<operation error>)
	TCTorManagerErrorUpdateRelaunch,		// info: TCInfo (<operation error>)
} TCTorManagerErrorUpdate;


// == TCTorManagerOperation ==
typedef enum
{
	TCTorManagerEventOperationInfo,			// context: NSDictionary
	TCTorManagerEventOperationDone,
} TCTorManagerEventOperation;

typedef enum
{
	TCTorManagerErrorOperationConfiguration,
	TCTorManagerErrorOperationIO,
	TCTorManagerErrorOperationNetwork,		// context
	TCTorManagerErrorOperationExtract,		// context: NSNumber (<tar result>)
	TCTorManagerErrorOperationSignature,	// context: NSString (<path to the problematic file>)
	TCTorManagerErrorOperationTor,			// context: NSNumber (<tor result>)

	TCTorManagerErrorInternal
} TCTorManagerErrorOperation;



/*
** TCTorManager
*/
#pragma mark - TCTorManager

@interface TCTorManager : NSObject

// -- Instance --
- (id)initWithConfiguration:(id <TCConfig>)configuration;

// -- Life --
- (void)startWithHandler:(void (^)(TCInfo *info))handler;
- (void)stopWithCompletionHandler:(dispatch_block_t)handler;

// -- Update --
- (dispatch_block_t)checkForUpdateWithCompletionHandler:(void (^)(TCInfo *info))handler;
- (dispatch_block_t)updateWithEventHandler:(void (^)(TCInfo *info))handler;

// -- Events --
@property (strong, atomic) void (^logHandler)(TCTorManagerLogKind kind, NSString *log);

@end
