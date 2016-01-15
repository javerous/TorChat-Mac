/*
 *  TCTorWindowController.m
 *
 *  Copyright 2016 Avérous Julien-Pierre
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

#import "TCTorWindowController.h"

#import "TCTorManager.h"
#import "TCInfo.h"
#import "TCInfo+Render.h"


/*
** TCTorWindowController
*/
#pragma mark - TCTorWindowController

@implementation TCTorWindowController
{
	IBOutlet NSButton				*cancelButton;
	IBOutlet NSTextField			*summaryField;
	IBOutlet NSProgressIndicator	*progressIndicator;
	
	TCTorManager *_torManager;
	
	void (^_handler)(TCInfo *info);
	
	BOOL	_isBootstrapping;
	BOOL	_isError;
}


/*
** TCTorWindowController - Instance
*/
#pragma mark - TCTorWindowController - Instance

+ (void)startWithTorManager:(TCTorManager *)torManager handler:(void (^)(TCInfo *info))handler
{
	dispatch_async(dispatch_get_main_queue(), ^{
		
		TCTorWindowController *ctrl = [[TCTorWindowController alloc] initWithTorManager:torManager handler:handler];
		
		[ctrl showWindow:nil];
	});
}

- (instancetype)initWithTorManager:(TCTorManager *)torManager handler:(void (^)(TCInfo *info))handler
{
	self = [super initWithWindowNibName:@"TorWindow"];
	
	if (self)
	{
		if (!torManager || !handler)
			return nil;
		
		_torManager = torManager;
		_handler = handler;
	}
	
	return self;
}



/*
** TCTorWindowController - NSWindowController
*/
#pragma mark - TCTorWindowController - NSWindowController

- (void)windowDidLoad
{
	[super windowDidLoad];
	
	[self.window center];
	[progressIndicator startAnimation:nil];
	
	[_torManager startWithHandler:^(TCInfo *info) {
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if ([info.domain isEqualToString:TCTorManagerInfoStartDomain] == NO)
				return;
			
			// Forward info.
			_handler(info);

			// Handle info.
			switch (info.kind)
			{
				case TCInfoInfo:
				{
					switch ((TCTorManagerEventStart)info.code)
					{
						case TCTorManagerEventStartBootstrapping:
						{
							NSDictionary	*context = info.context;
							NSString		*summary = context[@"summary"];
							NSNumber		*progress = context[@"progress"];

							if (!_isBootstrapping)
							{
								progressIndicator.indeterminate = NO;
								summaryField.hidden = NO;
								
								_isBootstrapping = YES;
							}
							
							progressIndicator.doubleValue = [progress doubleValue];
							summaryField.stringValue = summary;
							
							if (_isBootstrapping && [progress doubleValue] >= 100)
							{
								progressIndicator.indeterminate = YES;
								summaryField.hidden = YES;
								
								_isBootstrapping = NO;
							}
							
							break;
						}
							
						case TCTorManagerEventStartDone:
						{
							[self close];
							break;
						}
							
						default:
							break;
					}
					
					break;
				}
					
				case TCInfoWarning:
				{
					switch ((TCTorManagerWarningStart)info.code)
					{
						case TCTorManagerWarningStartCanceled:
						{
							[self close];
							break;
						}
					}
					
					break;
				}
					
				case TCInfoError:
				{
					summaryField.textColor = [NSColor redColor];
					summaryField.stringValue = [info renderMessage];
					summaryField.hidden = NO;
					
					cancelButton.stringValue = NSLocalizedString(@"tor_button_close", @"");
					
					_isError = YES;
					
					break;
				}
			}
		});
	}];
}



/*
** TCTorWindowController - IBAction
*/
#pragma mark - TCTorWindowController - IBAction

- (IBAction)doCancel:(id)sender
{
	if (_isError)
	{
		[self close];
	}
	else
	{
		cancelButton.enabled = NO;
		
		if (_isBootstrapping)
		{
			summaryField.hidden = YES;
			[progressIndicator setIndeterminate:YES];
		}
		
		[_torManager stopWithCompletionHandler:^{
			dispatch_async(dispatch_get_main_queue(), ^{
				[self close];
			});
		}];
	}
}

@end
