/*
 *  TCDropZoneView.h
 *
 *  Copyright 2019 Avérous Julien-Pierre
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


NS_ASSUME_NONNULL_BEGIN


/*
** TCDropZoneView
*/
#pragma mark - TCDropZoneView

@interface TCDropZoneView : NSView

// Properties.
@property (strong, nonatomic) NSImage				*dropImage;
@property (strong, nonatomic) NSAttributedString	*dropString;

@property (strong, nonatomic) NSColor *dashColor;

// Handler.
@property (strong, nonatomic) void (^droppedFilesHandler)(NSArray * _Nonnull files);

// Tools.
- (NSSize)computeSizeForSymmetricalDashesWithMinWidth:(CGFloat)minWidth minHeight:(CGFloat)minHeight;

@end


NS_ASSUME_NONNULL_END
