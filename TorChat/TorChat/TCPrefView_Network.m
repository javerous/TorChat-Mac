//
//  TCPrefView_Network.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2015 SourceMac. All rights reserved.
//

#import "TCPrefView_Network.h"

#import "TCBuddiesWindowController.h"


/*
** TCPrefView_Network - Private
*/
#pragma mark - TCPrefView_Network - Private

@interface TCPrefView_Network ()
{
	BOOL changes;
}

@property (strong, nonatomic) IBOutlet NSTextField	*imAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*imPortField;
@property (strong, nonatomic) IBOutlet NSTextField	*torAddressField;
@property (strong, nonatomic) IBOutlet NSTextField	*torPortField;

@end



/*
** TCPrefView_Network
*/
#pragma mark - TCPrefView_Network

@implementation TCPrefView_Network


/*
** TCPrefView_Network - Instance
*/
#pragma mark - TCPrefView_Network - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_Network" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}



/*
** TCPrefView_Network - TextField Delegate
*/
#pragma mark - TCPrefView_Network - TextField Delegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	changes = YES;
}



/*
** TCPrefView_Network - TCPrefView
*/
#pragma mark - TCPrefView_Network - TCPrefView

- (void)loadConfig
{
	TCConfigMode mode;
	
	if (!self.config)
		return;
	
	// Load view.
	[self view];
	
	mode = [self.config mode];
	
	// Set mode
	if (mode == TCConfigModeBasic)
	{
		[_imAddressField setEnabled:NO];
		[_imPortField setEnabled:NO];
		[_torAddressField setEnabled:NO];
		[_torPortField setEnabled:NO];
	}
	else if (mode == TCConfigModeAdvanced)
	{
		[_imAddressField setEnabled:YES];
		[_imPortField setEnabled:YES];
		[_torAddressField setEnabled:YES];
		[_torPortField setEnabled:YES];
	}
	
	// Set value field
	[_imAddressField setStringValue:[self.config selfAddress]];
	[_imPortField setStringValue:[@([self.config clientPort]) description]];
	[_torAddressField setStringValue:[self.config torAddress]];
	[_torPortField setStringValue:[@([self.config torPort]) description]];
}

- (void)saveConfig
{
	if (!self.config)
		return;
	
	if ([self.config mode] == TCConfigModeAdvanced)
	{
		// Set config value
		[self.config setSelfAddress:[_imAddressField stringValue]];
		[self.config setClientPort:(uint16_t)[[_imPortField stringValue] intValue]];
		[self.config setTorAddress:[_torAddressField stringValue]];
		[self.config setTorPort:(uint16_t)[[_torPortField stringValue] intValue]];
		
		// Reload config
		if (changes)
		{
			[[TCBuddiesWindowController sharedController] stop];
			[[TCBuddiesWindowController sharedController] startWithConfiguration:self.config];
			
			changes = NO;
		}
	}
}

@end
