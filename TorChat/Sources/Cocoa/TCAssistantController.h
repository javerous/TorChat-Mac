/*
 *  TCAssistantController.h
 *
 *  Copyright 2012 Avérous Julien-Pierre
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
#pragma mark - Forward

@class TCPanel_Welcome;
@class TCPanel_Mode;
@class TCPanel_Advanced;
@class TCPanel_Basic;

class TCCocoaConfig;



/*
** TCAssistantProxy
*/
#pragma mark - TCAssistantProxy

@protocol TCAssistantProxy <NSObject>

- (void)setNextPanelID:(NSString *)panelID;
- (void)setIsLastPanel:(BOOL)last;
- (void)setDisableContinue:(BOOL)disabled;

@end



/*
** TCAssistantPanel
*/
#pragma mark - TCAssistantController

@protocol TCAssistantPanel <NSObject>

- (void)showWithProxy:(id <TCAssistantProxy>)proxy;

- (NSString *)panelID;
- (NSString *)panelTitle;
- (NSView *)panelView;

- (void *)content;

@end



/*
** TCAssistantController
*/
#pragma mark - TCAssistantController

@interface TCAssistantController : NSObject

// -- Property --
// > Pannels
@property (strong, nonatomic)	IBOutlet TCPanel_Welcome	*welcomePanel;
@property (strong, nonatomic)	IBOutlet TCPanel_Mode		*modePanel;
@property (strong, nonatomic)	IBOutlet TCPanel_Advanced	*advancedPanel;
@property (strong, nonatomic)	IBOutlet TCPanel_Basic		*basicPanel;
	
// > Assistant
@property (strong, nonatomic)	IBOutlet NSWindow			*mainWindow;
@property (strong, nonatomic)	IBOutlet NSTextField		*mainTitle;
@property (strong, nonatomic)	IBOutlet NSView				*mainView;
@property (strong, nonatomic)	IBOutlet NSButton			*cancelButton;
@property (strong, nonatomic)	IBOutlet NSButton			*nextButton;

// -- Constructor --
+ (TCAssistantController *)sharedController;

// -- Run --
- (void)startWithCallback:(SEL)selector onObject:(id)obj;

// -- IBAction --
- (IBAction)doCancel:(id)sender;
- (IBAction)doNext:(id)sender;

@end



/*
** Pannels
*/
#pragma mark - Pannels

@interface TCPanel_Welcome : NSView <TCAssistantPanel>

@property (strong, nonatomic)	IBOutlet NSTextField *confPathField;

- (IBAction)selectChange:(id)sender;
- (IBAction)selectFile:(id)sender;

@end


@interface TCPanel_Mode : NSView <TCAssistantPanel>

- (IBAction)selectChange:(id)sender;

@end


@interface TCPanel_Advanced : NSView <TCAssistantPanel>

@property (strong, nonatomic)	IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*imInPortField;
@property (strong, nonatomic)	IBOutlet NSTextField	*imDownloadField;
	
@property (strong, nonatomic)	IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField	*torPortField;

- (IBAction)selectFolder:(id)sender;

@end


@interface TCPanel_Basic : NSView <TCAssistantPanel>

@property (strong, nonatomic)	IBOutlet NSTextField			*imAddressField;
@property (strong, nonatomic)	IBOutlet NSTextField			*imDownloadField;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator	*loadingIndicator;

- (IBAction)selectFolder:(id)sender;

@end
