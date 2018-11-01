/*
 *  TCConfigurationHelperController.h
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCConfigAppEncryptable.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Defines
*/
#pragma mark - Defines

#define TCConfigurationHelperErrorDomain @"TCConfigurationHelperErrorDomain"



/*
** Types
*/
#pragma mark - Types

typedef NS_ENUM(unsigned int, TCConfigurationHelperResult) {
	TCConfigurationHelperResultDone,		// result = <TCConfigAppEncryptable>
	TCConfigurationHelperResultCanceled,	// result = nil
	TCConfigurationHelperResultErrored,		// result = NSError
};

typedef void (^TCConfigurationHelperCompletionHandler)(TCConfigurationHelperResult result, id _Nullable context);



/*
** TCConfigurationHelperController
*/
#pragma mark - TCConfigurationHelperController

@interface TCConfigurationHelperController : NSObject

+ (void)openConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler;

@end


NS_ASSUME_NONNULL_END
