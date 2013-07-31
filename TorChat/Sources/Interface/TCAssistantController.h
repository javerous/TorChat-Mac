/*
 *  TCAssistantController.h
 *
 *  Copyright 2013 Avérous Julien-Pierre
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
** Types
*/
#pragma mark - Types

typedef void (^TCAssistantCallback)(id context);



/*
** TCAssistantController
*/
#pragma mark - TCAssistantController

@interface TCAssistantController : NSObject

// > Assistant
@property (strong, nonatomic)	IBOutlet NSWindow			*mainWindow;
@property (strong, nonatomic)	IBOutlet NSTextField		*mainTitle;
@property (strong, nonatomic)	IBOutlet NSView				*mainView;
@property (strong, nonatomic)	IBOutlet NSButton			*cancelButton;
@property (strong, nonatomic)	IBOutlet NSButton			*nextButton;

// -- Constructor --
+ (TCAssistantController *)startAssistantWithPanels:(NSArray *)panels andCallback:(TCAssistantCallback)callback;

// -- IBAction --
- (IBAction)doCancel:(id)sender;
- (IBAction)doNext:(id)sender;

@end
