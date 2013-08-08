//
//  TCPanel_Mode.m
//  TorChat
//
//  Created by Julien-Pierre Avérous on 31/07/13.
//  Copyright (c) 2013 SourceMac. All rights reserved.
//

#import "TCPanel_Mode.h"



/*
** TCPanel_Mode - Private
*/
#pragma mark - TCPanel_Mode - Private

@interface TCPanel_Mode ()
{
    __weak id <TCAssistantProxy> _proxy;
}

@property (strong, nonatomic) IBOutlet NSMatrix *buttonMatrix;

- (IBAction)selectChange:(id)sender;

@end



/*
** TCPanel_Mode
*/
#pragma mark - TCPanel_Mode

@implementation TCPanel_Mode

- (void)awakeFromNib
{
	[_buttonMatrix setAutorecalculatesCellSize:YES];
}

- (void)dealloc
{
    TCDebugLog("TCPanel_Mode dealloc");
}



/*
** TCPanel_Mode - TCAssistantPanel
*/
#pragma mark - TCPanel_Mode - TCAssistantPanel

+ (id <TCAssistantPanel>)panelWithProxy:(id <TCAssistantProxy>)proxy
{
	TCPanel_Mode *panel = [[TCPanel_Mode alloc] initWithNibName:@"AssistantPanel_Mode" bundle:nil];
	
	panel->_proxy = proxy;
	
	return panel;
}

+ (NSString *)identifiant
{
	return @"ac_mode";
}

+ (NSString *)title
{
	return NSLocalizedString(@"ac_title_mode", @"");
}

- (id)content
{
	return nil;
}

- (void)showPanel;
{
	id <TCAssistantProxy> proxy = _proxy;

	[proxy setIsLastPanel:NO];
	[proxy setNextPanelID:@"ac_basic"];
}


/*
** TCPanel_Mode - IBAction
*/
#pragma mark - TCPanel_Mode - IBAction

- (IBAction)selectChange:(id)sender
{
	id <TCAssistantProxy> proxy = _proxy;

	NSMatrix	*mtr = sender;
	NSButton	*obj = [mtr selectedCell];
	NSInteger	tag = [obj tag];
	
	if (tag == 1)
		[proxy setNextPanelID:@"ac_basic"];
	else if (tag == 2)
		[proxy setNextPanelID:@"ac_advanced"];
	else
		[proxy setNextPanelID:nil];
}

@end
