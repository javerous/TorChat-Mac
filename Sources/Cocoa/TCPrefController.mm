/*
 *  TCPrefController.mm
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



#import "TCPrefController.h"

#import "TCMainController.h"
#import "TCBuddiesController.h"

#include "TCConfig.h"



/*
** TCPrefController - Private
*/
#pragma mark -
#pragma mark TCPrefController - Private

@interface TCPrefController ()

- (NSString *)stringWithCPPString:(const std::string &)str;
- (std::string)cppStringWithString:(NSString *)str;
- (NSString *)stringWithInt:(int)value;

- (void)loadFields;

@end



/*
** TCPrefController
*/
#pragma mark -
#pragma mark TCPrefController

@implementation TCPrefController


/*
** TCPrefController - Constructor & Destructor
*/
#pragma mark -
#pragma mark TCPrefController - Constructor & Destructor

+ (TCPrefController *)sharedController
{
	static dispatch_once_t		pred;
	static TCPrefController	*instance = nil;
	
	dispatch_once(&pred, ^{
		instance = [[TCPrefController alloc] init];
	});
	
	return instance;
}

- (id)init
{
    if ((self = [super init]))
	{
        // Load the nib
		[NSBundle loadNibNamed:@"Preferences" owner:self];
    }
    
    return self;
}

- (void)dealloc
{
    // Clean-up code here.
    
    [super dealloc];
}

- (void)awakeFromNib
{	
	// Place Window
	[mainWindow center];
	[mainWindow setFrameAutosaveName:@"PreferencesWindow"];
}



/*
** TCPrefController - Tools
*/
#pragma mark -
#pragma mark TCPrefController - Tools

- (void)showWindow
{
	// Load fields
	[self loadFields];
	
	// Show window
	[mainWindow makeKeyAndOrderFront:self];
}

- (NSString *)stringWithCPPString:(const std::string &)str
{
	const char *cstr = str.c_str();
	
	if (!cstr)
		return nil;
	
	return [NSString stringWithUTF8String:cstr];
}

- (std::string)cppStringWithString:(NSString *)str
{
	const char *cstr = [str UTF8String];
	
	if (!str)
		return "";
	
	return cstr;
}


- (NSString *)stringWithInt:(int)value
{
	return [NSString stringWithFormat:@"%i", value];
}

- (void)loadFields
{
	TCConfig *config = [[TCMainController sharedController] config];
	
	if (!config)
	{
		NSBeep();
		return;
	}
	
	tc_config_mode mode = config->get_mode();
	
	// Set mode
	if (mode == tc_config_basic)
	{		
		[imAddressField setEnabled:NO];
		[imPortField setEnabled:NO];
		[torAddressField setEnabled:NO];
		[torPortField setEnabled:NO];
	}
	else if (mode == tc_config_advanced)
	{		
		[imAddressField setEnabled:YES];
		[imPortField setEnabled:YES];
		[torAddressField setEnabled:YES];
		[torPortField setEnabled:YES];
	}
	
	// Set value field
	[imAddressField setStringValue:[self stringWithCPPString:config->get_self_address()]];
	[imPortField setStringValue:[self stringWithInt:config->get_client_port()]];
	[torAddressField setStringValue:[self stringWithCPPString:config->get_tor_address()]];
	[torPortField setStringValue:[self stringWithInt:config->get_tor_port()]];
	
	[downloadField setStringValue:[[self stringWithCPPString:config->get_download_folder()] lastPathComponent]];
}



/*
** TCPrefController - IBAction
*/
#pragma mark -
#pragma mark TCPrefController - IBAction

- (IBAction)doDownload:(id)sender
{	
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:NO];
	[openDlg setCanChooseDirectories:YES];
	[openDlg setCanCreateDirectories:YES];
	[openDlg setAllowsMultipleSelection:NO];
	
	if ([openDlg runModalForDirectory:nil file:nil] == NSOKButton)
	{
		TCConfig	*config = [[TCMainController sharedController] config];
		NSArray		*files = [openDlg filenames];
		NSString	*path = [files objectAtIndex:0];
		
		if (config)
		{
			[downloadField setStringValue:[path lastPathComponent]];		
			config->set_download_folder([path UTF8String]);
		}
		else
			NSBeep();
	}
}



/*
** TCPrefController - NSWindow
*/
#pragma mark -
#pragma mark TCPrefController - NSWindow

- (void)windowWillClose:(NSNotification *)notification
{
	TCConfig *config = [[TCMainController sharedController] config];
	
	if (!config)
		return;
	
	if (config->get_mode() == tc_config_basic)
		return;
	
	// Set config value
	config->set_self_address([self cppStringWithString:[imAddressField stringValue]]);
	config->set_client_port([[imPortField stringValue] intValue]);
	config->set_tor_address([self cppStringWithString:[torAddressField stringValue]]);
	config->set_tor_port([[torPortField stringValue] intValue]);
	
	// Reload config
	[[TCBuddiesController sharedController] stop];
	[[TCBuddiesController sharedController] startWithConfig:config];
}

@end
