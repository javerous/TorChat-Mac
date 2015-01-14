/*
 *  TCUpdateWindowController.m
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


#import "TCUpdateWindowController.h"

#import "TCTorManager.h"
#import "TCInfo.h"


/*
** TCUpdateWindowController - Private
*/
#pragma mark - TCUpdateWindowController - Private

@interface TCUpdateWindowController ()
{
	TCTorManager		*_torManager;
	
	dispatch_block_t	_currentCancelBlock;
	BOOL				_updateDone;
}

@property (strong, nonatomic)	IBOutlet NSView			*availableView;
@property (strong, nonatomic)	IBOutlet NSTextField	*subtitleField;

@property (strong, nonatomic)	IBOutlet NSView			*workingView;
@property (strong, nonatomic)	IBOutlet NSTextField	*workingStatusField;
@property (strong, nonatomic)	IBOutlet NSProgressIndicator *workingProgress;
@property (strong, nonatomic)	IBOutlet NSTextField	*workingDownloadInfo;
@property (strong, nonatomic)	IBOutlet NSButton		*workingButton;


- (IBAction)doRemindMeLater:(id)sender;
- (IBAction)doInstallUpdate:(id)sender;

- (IBAction)doWorkingButton:(id)sender;

@end



/*
** TCUpdateWindowController
*/
#pragma mark - TCUpdateWindowController

@implementation TCUpdateWindowController


/*
** TCUpdateWindowController - Instance
*/
#pragma mark - TCUpdateWindowController - Instance

+ (TCUpdateWindowController *)sharedController
{
	static dispatch_once_t			onceToken;
	static TCUpdateWindowController	*instance = nil;
	
	dispatch_once(&onceToken, ^{
		instance = [[TCUpdateWindowController alloc] init];
	});
	
	return instance;
}

- (id)init
{
	self = [super initWithWindowNibName:@"UpdateWindow"];
	
	if (self)
	{
	}
	
	return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	
	// Place Window
	[self.window center];
}



/*
** Tools
*/
#pragma mark - Tools

- (void)handleUpdateFromVersion:(NSString *)oldVersion toVersion:(NSString *)newVersion torManager:(TCTorManager *)torManager
{
	if (!oldVersion || !newVersion || !torManager)
		return;
	
	dispatch_async(dispatch_get_main_queue(), ^{
		
		// Handle tor manager.
		_torManager = torManager;
		
		// Place availableView.
		[_workingView removeFromSuperview];
		
		_availableView.alphaValue = 1.0;
		_workingView.alphaValue = 0.0;
		
		[self.window.contentView addSubview:_availableView];
		
		// Configure available view.
		NSString *subtitle = [NSString stringWithFormat:NSLocalizedString(@"update_available_subtitle", @""), newVersion, oldVersion];
		
		_subtitleField.stringValue = subtitle;
		
		// Show window.
		[self showWindow:nil];
	});
}

- (void)_doUpdate
{
	// > main queue <
	
	// Init view state.
	_workingStatusField.stringValue = @"Launching update…"; // FIXME: localize
	
	_workingDownloadInfo.stringValue = @"";
	_workingDownloadInfo.hidden = YES;
	
	_workingProgress.doubleValue = 0.0;
	_workingProgress.indeterminate = YES;
	[_workingProgress startAnimation:nil];
	
	_workingButton.title = @"Cancel"; // FIXME: localize
	_workingButton.keyEquivalent = @"\e";
	
	_updateDone = NO;
	
	// Launch update.
	__block NSUInteger archiveTotal = 0;
	
	_currentCancelBlock = [_torManager updateWithEventHandler:^(TCInfo *info){
		
		dispatch_async(dispatch_get_main_queue(), ^{
			
			if (info.kind == TCInfoInfo)
			{
				switch ((TCTorManagerEventUpdate)info.code)
				{
					case TCTorManagerEventUpdateArchiveInfoRetrieving:
					{
						_workingStatusField.stringValue = @"Retrieving archive info…"; // FIXME: localize
						break;
					}
						
					case TCTorManagerEventUpdateArchiveSize:
					{
						_workingStatusField.stringValue = @"Downloading…"; // FIXME: localize

						_workingProgress.indeterminate = NO;
						_workingDownloadInfo.hidden = NO;

						archiveTotal = [info.context unsignedIntegerValue];

						break;
					}
					
					case TCTorManagerEventUpdateArchiveDownloading:
					{
						NSUInteger archiveCurrent = [info.context unsignedIntegerValue];
						
						_workingProgress.doubleValue = (double)archiveCurrent / (double)archiveTotal;
						_workingDownloadInfo.stringValue = [NSString stringWithFormat:@"%lu of %lu", (unsigned long)archiveCurrent, (unsigned long)archiveTotal];
						
						if (archiveCurrent == archiveTotal)
						{
							_workingProgress.indeterminate = YES;
							_workingDownloadInfo.hidden = YES;
						}
						
						break;
					}
						
					case TCTorManagerEventUpdateArchiveStage:
					{
						_workingStatusField.stringValue = @"Archive staging…"; // FIXME: localize
						break;
					}
					
					case TCTorManagerEventUpdateSignatureCheck:
					{
						_workingStatusField.stringValue = @"Checking signature…"; // FIXME: localize
						break;
					}
						
					case TCTorManagerEventUpdateRelaunch:
					{
						_workingStatusField.stringValue = @"Relaunching tor…"; // FIXME: localize
						break;
					}
						
					case TCTorManagerEventUpdateDone:
					{
						_workingStatusField.stringValue = @"Update done."; // FIXME: localize
						
						_workingButton.title = @"Done"; // FIXME: localize
						_workingButton.keyEquivalent = @"\r";
						
						_updateDone = YES;
						
						break;
					}
				}
			}
			else if (info.kind == TCInfoError)
			{
#warning FIXME
			//	NSLog(@"Error: %@", [info render]);
			}
		});
	}];
}


/*
** TCUpdateWindowController - IBAction
*/
#pragma mark - TCUpdateWindowController - IBAction

- (IBAction)doRemindMeLater:(id)sender
{
	[self close];
}

- (IBAction)doInstallUpdate:(id)sender
{
	// Compute new rect.
	NSSize oldSize = [_availableView frame].size;
	NSSize newSize = [_workingView frame].size;
	
	NSRect frame = [self.window frame];
	NSRect rect;

	rect.size = NSMakeSize(frame.size.width + (newSize.width - oldSize.width), frame.size.height + (newSize.height - oldSize.height));
	rect.origin = NSMakePoint(frame.origin.x + (frame.size.width - rect.size.width) / 2.0, frame.origin.y + (frame.size.height - rect.size.height) / 2.0);

	_availableView.alphaValue = 1.0;
	_workingView.alphaValue = 0.0;
	
	[self.window.contentView addSubview:_workingView];

	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		context.duration = 0.1;
		_availableView.animator.alphaValue = 0.0;
		_workingView.animator.alphaValue = 1.0;
		[self.window.animator setFrame:rect display:YES];
	} completionHandler:^{
		[_availableView removeFromSuperview];
		[self _doUpdate];
	}];
}

- (IBAction)doWorkingButton:(id)sender
{
	if (!_updateDone && _currentCancelBlock)
		_currentCancelBlock();
	
	_currentCancelBlock = nil;
	
	[self close];
}

@end
