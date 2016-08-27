/*
 *  TCButton.h
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


NS_ASSUME_NONNULL_BEGIN


/*
** Forward
*/
#pragma mark - Forward

@class TCButtonContext;


/*
** TCButton
*/
#pragma mark - TCButton

@interface TCButton : NSView

// Context
+ (TCButtonContext *)createEmptyContext;

@property (strong, nonatomic) TCButtonContext *context;

// Content.
@property (strong, nonatomic) NSImage *image;
@property (strong, nonatomic) NSImage *overImage;
@property (strong, nonatomic) NSImage *pushImage;

// Action.
@property (nullable, strong, nonatomic) void (^actionHandler)(TCButton *button);

@end


NS_ASSUME_NONNULL_END
