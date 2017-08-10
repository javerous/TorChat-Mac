/*
 *  TCChatContentController.h
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

#import <Cocoa/Cocoa.h>

#import "TCConfigApp.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TCChatContentControllerTypeKey		@"type"
#define TCChatContentControllerContentKey	@"content"	// NSString (path) or NSData (raw) - path to file, or data directely.
#define TCChatContentControllerNameKey		@"name"		// NSString - [type raw only] Proposed name when raw data.
#define TCChatContentControllerSaveKey		@"save"		// NSNumber (BOOL) - [type raw only] YES to indicate the user want the data to be saved localy, NO if not.


#define TCChatContentControllerTypeFileKey	@"file"
#define TCChatContentControllerTypeRawKey	@"raw"



/*
** TCChatContentController
*/
#pragma mark - TCChatContentController

@interface TCChatContentController : NSViewController

// -- Instance --
- (instancetype)initWithConfiguration:(id <TCConfigApp>)configuration NS_DESIGNATED_INITIALIZER;

- (instancetype)initWithCoder:(NSCoder *)coder NS_UNAVAILABLE;
- (instancetype)initWithNibName:(nullable NSString *)nibNameOrNil bundle:(nullable NSBundle *)nibBundleOrNil NS_UNAVAILABLE;

// -- Propertie --
@property (nullable, atomic) void (^contentHandler)(NSArray <NSDictionary *> *contents);
@property (nullable, atomic) void (^resizeHandler)(NSSize newSize);

@end


NS_ASSUME_NONNULL_END
