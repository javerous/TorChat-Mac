/*
 *  TCDropButton.m
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



#import "TCDropButton.h"



/*
** TCDropButton
*/
#pragma mark - TCDropButton

@implementation TCDropButton

- (void)awakeFromNib
{
	[self registerForDraggedTypes:[NSArray arrayWithObject:NSFilenamesPboardType]];
	[self registerForDraggedTypes:[NSImage imagePasteboardTypes]];
}

- (NSDragOperation)draggingEntered:(id < NSDraggingInfo >)sender
{
	NSPasteboard *pb = [sender draggingPasteboard];
	id <TCDropButtonDelegate> delegate = _delegate;

	if (!delegate)
		return NSDragOperationNone;
	
	if ([NSImage canInitWithPasteboard:pb])
		return NSDragOperationCopy;
	else
		return NSDragOperationNone;
}

- (BOOL)performDragOperation:(id < NSDraggingInfo >)sender
{
	NSPasteboard *pboard = [sender draggingPasteboard];
	id <TCDropButtonDelegate> delegate = _delegate;

	if ([[pboard types] containsObject:NSFilenamesPboardType])
	{
		NSArray *files = [pboard propertyListForType:NSFilenamesPboardType];

		if ([files count] != 1)
			return NO;
		
		NSImage *img = [[NSImage alloc] initWithPasteboard:pboard];
		
		if (!img)
			return NO;
		
		[delegate dropButton:self doppedImage:img];
				
		return YES;
	}
	else if ([NSImage canInitWithPasteboard:pboard])
	{
		NSImage *img = [[NSImage alloc] initWithPasteboard:pboard];
						
		[delegate dropButton:self doppedImage:img];
		
		return YES;
	}
	
	return NO;
}

@end
