/*
 *  TCButton.h
 *
 *  Copyright 2010 Avérous Julien-Pierre
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



/*
** Forward
*/
#pragma mark -
#pragma mark Forward

@class TCButton;



/*
** TCButton Delegate
*/
#pragma mark -
#pragma mark TCButton Delegate

@protocol TCButtonDelegate <NSObject>

@optional
	- (void)button:(TCButton *)button isRollOver:(BOOL)rollOver;
@end



/*
** TCButton
*/
#pragma mark -
#pragma mark TCButton

@interface TCButton : NSButton
{
@private
    NSImage					*image;
	NSImage					*rollOverImage;
	
	BOOL					isOver;
	
	id <TCButtonDelegate>	delegate;
	
	NSTrackingRectTag		tracking;
}

@property (assign, nonatomic) id <TCButtonDelegate> delegate;

- (void)setImage:(NSImage *)img;
- (void)setPushImage:(NSImage *)img;
- (void)setRollOverImage:(NSImage *)img;

@end
