//
//  TCPrefView_General.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 14/01/2015.
//  Copyright (c) 2016 SourceMac. All rights reserved.
//

#import "TCPrefView_General.h"


/*
** TCPrefView_General - Private
*/
#pragma mark - TCPrefView_General - Private

@interface TCPrefView_General ()

// -- Properties --
@property (strong, nonatomic) IBOutlet NSTextField		*clientNameField;
@property (strong, nonatomic) IBOutlet NSTextField		*clientVersionField;

@end



/*
** TCPrefView_General
*/
#pragma mark - TCPrefView_General

@implementation TCPrefView_General


/*
** TCPrefView_General - Instance
*/
#pragma mark - TCPrefView_General - Instance

- (id)init
{
	self = [super initWithNibName:@"PrefView_General" bundle:nil];
	
	if (self)
	{
		
	}
	
	return self;
}



/*
** TCPrefView_General - TCPrefView
*/
#pragma mark - TCPrefView_General - TCPrefView

- (void)loadConfig
{
	if (!self.config)
		return;
	
	// Load view.
	[self view];
		
	// Client info.
	[[_clientNameField cell] setPlaceholderString:[self.config clientName:TCConfigGetDefault]];
	[[_clientVersionField cell] setPlaceholderString:[self.config clientVersion:TCConfigGetDefault]];
	
	[_clientNameField setStringValue:[self.config clientName:TCConfigGetDefined]];
	[_clientVersionField setStringValue:[self.config clientVersion:TCConfigGetDefined]];
}

- (void)saveConfig
{
	[self.config setClientName:[_clientNameField stringValue]];
	[self.config setClientVersion:[_clientVersionField stringValue]];
}

@end
