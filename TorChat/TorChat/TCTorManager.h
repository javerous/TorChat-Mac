/*
 *  TCTorManager.h
 *
<<<<<<< HEAD
 *  Copyright 2014 Avérous Julien-Pierre
=======
 *  Copyright 2016 Avérous Julien-Pierre
>>>>>>> javerous/master
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

<<<<<<< HEAD


=======
>>>>>>> javerous/master
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
<<<<<<< HEAD
	TCTorManagerEventStartHostname,
=======
	TCTorManagerEventStartBootstrapping,	// context: @{ @"progress" : NSNumber, @"summary" : NSString }
	TCTorManagerEventStartHostname,
	TCTorManagerEventStartURLSession,		// context: NSURLSession
>>>>>>> javerous/master
	TCTorManagerEventStartDone,
} TCTorManagerEventStart;

typedef enum
{
<<<<<<< HEAD
	TCTorManagerErrorStartAlreadyRunning,
	
=======
	TCTorManagerWarningStartCanceled,
} TCTorManagerWarningStart;

typedef enum
{
	TCTorManagerErrorStartAlreadyRunning,
>>>>>>> javerous/master
	TCTorManagerErrorStartConfiguration,
	TCTorManagerErrorStartUnarchive,
	TCTorManagerErrorStartSignature,
	TCTorManagerErrorStartLaunch,
<<<<<<< HEAD
=======
	TCTorManagerErrorStartControlConnect,
	TCTorManagerErrorStartControlAuthenticate,
	TCTorManagerErrorStartControlMonitor,
>>>>>>> javerous/master
} TCTorManagerErrorStart;


// == TCTorManagerInfoCheckUpdateEvent ==
typedef enum
{
	TCTorManagerEventCheckUpdateAvailable,		// context: @{ @"old_version" : NSString, @"new_version" : NSString }
} TCTorManagerEventCheckUpdate;

typedef enum
{
	TCTorManagerErrorCheckUpdateTorNotRunning,
<<<<<<< HEAD
	TCTorManagerErrorCheckUpdateNetworkRequest,	// context: NSError
	TCTorManagerErrorCheckUpdateBadServerReply,
	TCTorManagerErrorCheckUpdateRemoteInfo,		// info: TCInfo (<operation error>)
=======
	TCTorManagerErrorRetrieveRemoteInfo,		// info: TCInfo (<operation error>)
>>>>>>> javerous/master
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
<<<<<<< HEAD
	TCTorManagerEventInfo,			// context: NSDictionary
	TCTorManagerEventDone,
=======
	TCTorManagerEventOperationInfo,			// context: NSDictionary
	TCTorManagerEventOperationDone,
>>>>>>> javerous/master
} TCTorManagerEventOperation;

typedef enum
{
<<<<<<< HEAD
	TCTorManagerErrorConfiguration,
	TCTorManagerErrorIO,
	TCTorManagerErrorNetwork,		// context
	TCTorManagerErrorExtract,		// context: NSNumber (<tar result>)
	TCTorManagerErrorSignature,		// context: NSString (<path to the problematic file>)
	TCTorManagerErrorTor,			// context: NSNumber (<tor result>)
=======
	TCTorManagerErrorOperationConfiguration,
	TCTorManagerErrorOperationIO,
	TCTorManagerErrorOperationNetwork,		// context
	TCTorManagerErrorOperationExtract,		// context: NSNumber (<tar result>)
	TCTorManagerErrorOperationSignature,	// context: NSString (<path to the problematic file>)
	TCTorManagerErrorOperationTor,			// context: NSNumber (<tor result>)
>>>>>>> javerous/master

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
<<<<<<< HEAD
- (void)stop;

- (BOOL)isRunning;

// -- Update --
- (void)checkForUpdateWithCompletionHandler:(void (^)(TCInfo *info))handler;
- (dispatch_block_t)updateWithEventHandler:(void (^)(TCInfo *info))handler;

// -- Property --
- (NSString *)hiddenHostname;

=======
- (void)stopWithCompletionHandler:(dispatch_block_t)handler;

// -- Update --
- (dispatch_block_t)checkForUpdateWithCompletionHandler:(void (^)(TCInfo *info))handler;
- (dispatch_block_t)updateWithEventHandler:(void (^)(TCInfo *info))handler;

>>>>>>> javerous/master
// -- Events --
@property (strong, atomic) void (^logHandler)(TCTorManagerLogKind kind, NSString *log);

@end
