/*
 *  TCAssistantController.h
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
@class TCPanel_Welcome;
@class TCPanel_Mode;
@class TCPanel_Advanced;
@class TCPanel_Basic;

class TCCocoaConfig;



/*
** TCAssistantProxy
*/
#pragma mark -
#pragma mark TCAssistantProxy

@protocol TCAssistantProxy <NSObject>

- (void)setNextPanelID:(NSString *)panelID;
- (void)setIsLastPanel:(BOOL)last;
- (void)setDisableContinue:(BOOL)disabled;

@end



/*
** TCAssistantPanel
*/
#pragma mark -
#pragma mark TCAssistantController

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
#pragma mark -
#pragma mark TCAssistantController

@interface TCAssistantController : NSObject
{
@public
	// -- Pannels --
	IBOutlet TCPanel_Welcome	*welcomePanel;
	IBOutlet TCPanel_Mode		*modePanel;
	IBOutlet TCPanel_Advanced	*advancedPanel;
	IBOutlet TCPanel_Basic		*basicPanel;
	
	// -- Assistant --
	IBOutlet NSWindow			*mainWindow;
	IBOutlet NSTextField		*mainTitle;
	IBOutlet NSView				*mainView;
	IBOutlet NSButton			*cancelButton;
	IBOutlet NSButton			*nextButton;
	
@private
	NSMutableDictionary			*pannels;
	
	id <TCAssistantPanel>		currentPanel;
		
	NSString					*nextID;
	BOOL						isLast;
	BOOL						fDisable;
	
	id							respObj;
	SEL							respSel;
}

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
#pragma mark -
#pragma mark Pannels

@interface TCPanel_Welcome : NSView <TCAssistantPanel>
{
@public
	IBOutlet NSTextField *confPathField;
@private
	id <TCAssistantProxy>	proxy;
	
	BOOL					pathSet;
	
	TCCocoaConfig			*config;
}

- (IBAction)selectChange:(id)sender;
- (IBAction)selectFile:(id)sender;

@end


@interface TCPanel_Mode : NSView <TCAssistantPanel>
{
@private
    id <TCAssistantProxy> proxy;
}

- (IBAction)selectChange:(id)sender;

@end


@interface TCPanel_Advanced : NSView <TCAssistantPanel>
{
	IBOutlet NSTextField	*imAddressField;
	IBOutlet NSTextField	*imInPortField;
	IBOutlet NSTextField	*imDownloadField;
	
	IBOutlet NSTextField	*torAddressField;
	IBOutlet NSTextField	*torPortField;
@private
    
}

- (IBAction)selectFolder:(id)sender;

@end


@interface TCPanel_Basic : NSView <TCAssistantPanel>
{
	IBOutlet NSTextField			*imAddressField;
	IBOutlet NSTextField			*imDownloadField;
	IBOutlet NSProgressIndicator	*loadingIndicator;
	
@private
	
	TCCocoaConfig					*cconfig;
	id <TCAssistantProxy>			aproxy;
}

- (IBAction)selectFolder:(id)sender;

@end
