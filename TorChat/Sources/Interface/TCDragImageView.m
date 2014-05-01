/*
 *  TCDragImageView.m
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


#import "TCDragImageView.h"

#import "TCDragImage.h"


/*
** TCDragImageView - Private
*/
#pragma mark - TCDragImageView - Private

@interface TCDragImageView () <NSDraggingSource>

@end



/*
** TCDragImageView
*/
#pragma mark - TCDragImageView

@implementation TCDragImageView



/*
** TCDragImageView - Drag
*/
#pragma mark - TCDragImageView - Drag

- (void)mouseDown:(NSEvent *)event
{
	NSSize size = self.frame.size;
	NSRect dragFrame = NSMakeRect(0, 0, size.width, size.height);
		
	// Create drag image.
	TCDragImage *dragImage = [[TCDragImage alloc] initWithImage:self.image andName:self.name];
	
	if (!dragImage)
		return;
	
	// Create dragging item.
	NSDraggingItem *dragItem = [[NSDraggingItem alloc] initWithPasteboardWriter:dragImage];
	
	dragItem.imageComponentsProvider = ^ NSArray * (void) {
		
		NSDraggingImageComponent *component = [NSDraggingImageComponent draggingImageComponentWithKey:NSDraggingImageComponentIconKey];
		
		component.frame = dragFrame;
		component.contents = [self image];
				
		return @[ component ];
	};
	
	dragItem.draggingFrame = dragFrame;
	
	// Create dragging session.
	NSDraggingSession *draggingSession  = [self beginDraggingSessionWithItems:@[ dragItem ] event:event source:self];
	
	draggingSession.animatesToStartingPositionsOnCancelOrFail = YES;
	draggingSession.draggingFormation = NSDraggingFormationNone;
}

- (NSDragOperation)draggingSession:(NSDraggingSession *)session sourceOperationMaskForDraggingContext:(NSDraggingContext)context
{
	return NSDragOperationCopy;

}

@end
