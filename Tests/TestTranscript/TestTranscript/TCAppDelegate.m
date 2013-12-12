//
//  TCAppDelegate.m
//  TranscriptPtest
//
//  Created by Julien-Pierre Avérous on 10/12/2013.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCAppDelegate.h"

#import "TCChatTranscriptViewController.h"

@interface TCAppDelegate ()
{
	TCChatTranscriptViewController *_viewCtrl;
}

@property (weak) IBOutlet NSView *transcriptView;

@property (weak) IBOutlet NSTextField *localField;
@property (weak) IBOutlet NSTextField *remoteField;
@property (weak) IBOutlet NSTextField *errorField;
@property (weak) IBOutlet NSTextField *statusField;

@end

@implementation TCAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification
{
	_viewCtrl = [[TCChatTranscriptViewController alloc] init];
	
	
	NSDictionary	*viewsDictionary;
	NSView			*view = _viewCtrl.view;
	
	[_transcriptView addSubview:view];
	
	viewsDictionary = NSDictionaryOfVariableBindings(view);
	
	[_transcriptView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:0 metrics:nil views:viewsDictionary]];
	[_transcriptView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[view]|" options:0 metrics:nil views:viewsDictionary]];
}

- (IBAction)localButton:(id)sender
{
	[_viewCtrl appendLocalMessage:_localField.stringValue];
}

- (IBAction)remoteButton:(id)sender
{
	[_viewCtrl appendRemoteMessage:_remoteField.stringValue];
	
}

- (IBAction)errorButton:(id)sender
{
	[_viewCtrl appendError:_errorField.stringValue];
}

- (IBAction)statusButton:(id)sender
{
	[_viewCtrl appendStatus:_statusField.stringValue];
}

- (IBAction)localAvatarButton:(id)sender
{
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:NO];
	[openDlg setAllowedFileTypes:[NSImage imageFileTypes]];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray	*urls = [openDlg URLs];
		NSImage *avatar = [[NSImage alloc] initWithContentsOfURL:[urls objectAtIndex:0]];
		
		[_viewCtrl setLocalAvatar:avatar];
	}
}

- (IBAction)remoteAvatarButton:(id)sender
{
	// Show dialog to select files to send
	NSOpenPanel	*openDlg = [NSOpenPanel openPanel];
	
	// Ask for a file
	[openDlg setCanChooseFiles:YES];
	[openDlg setCanChooseDirectories:NO];
	[openDlg setCanCreateDirectories:NO];
	[openDlg setAllowsMultipleSelection:NO];
	[openDlg setAllowedFileTypes:[NSImage imageFileTypes]];
	
	if ([openDlg runModal] == NSOKButton)
	{
		NSArray	*urls = [openDlg URLs];
		NSImage *avatar = [[NSImage alloc] initWithContentsOfURL:[urls objectAtIndex:0]];
		
		[_viewCtrl setRemoteAvatar:avatar];
	}
}

@end
