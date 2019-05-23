/*
 *  TCPrefView_Network.m
 *
 *  Copyright 2019 Avérous Julien-Pierre
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

#import "TCPrefView_Network.h"

#import "TCValidatedTextField.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Prototypes
*/
#pragma mark - Prototypes

static BOOL isNumber(NSString *str);



/*
** TCPrefView_Network - Private
*/
#pragma mark - TCPrefView_Network - Private

@interface TCPrefView_Network ()
{
	NSString *_customIMIdentifier;
	NSNumber *_customIMPort;
	NSString *_customTorAddress;
	NSNumber *_customTorPort;
}

@property (strong, nonatomic) IBOutlet NSImageView *warningView;

@property (strong, nonatomic) IBOutlet NSPopUpButton *modePopup;

@property (strong, nonatomic) IBOutlet TCValidatedTextField	*imIdentifierField;
@property (strong, nonatomic) IBOutlet TCValidatedTextField	*imPortField;
@property (strong, nonatomic) IBOutlet TCValidatedTextField	*torAddressField;
@property (strong, nonatomic) IBOutlet TCValidatedTextField	*torPortField;

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

- (instancetype)init
{
	self = [super initWithNibName:@"PrefView_Network" bundle:nil];
	
	if (self)
	{
	}
	
	return self;
}



/*
** TCPrefView_Network - NSViewController
*/
#pragma mark - TCPrefView_Network - NSViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	// Configure validation.
	TCPrefView_Network *weakSekf = self;
	
	// > Identifier.
	_imIdentifierField.validCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789"];
	_imIdentifierField.validateContent = ^ BOOL (NSString *newContent) {
		return (newContent.length <= 16);
	};
	_imIdentifierField.textDidChange = ^(NSString *content) {
		[weakSekf validateContent];
	};
	
	// > IM port.
	_imPortField.validCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
	_imPortField.validateContent = ^ BOOL (NSString *newContent) {
		return (newContent.length <= 5);
	};
	_imPortField.textDidChange = ^(NSString *content) {
		[weakSekf validateContent];
	};
	
	// > Tor address.
	_torAddressField.validCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789.-"];
	_torAddressField.textDidChange = ^(NSString *content) {
		[weakSekf validateContent];
	};
	
	// > Tor port.
	_torPortField.validCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
	_torPortField.validateContent = ^ BOOL (NSString *newContent) {
		return (newContent.length <= 5);
	};
	_torPortField.textDidChange = ^(NSString *content) {
		[weakSekf validateContent];
	};
	
	// Configure warning.
	[_warningView addToolTipRect:_warningView.bounds owner:NSLocalizedString(@"pref_network_warning_tooltip", @"") userData:NULL];
}



/*
** TCPrefView_Network - TCPrefView
*/
#pragma mark - TCPrefView_Network - TCPrefView

- (void)panelLoadConfiguration
{
	// Load configuration.
	TCConfigMode mode = self.config.mode;
	
	// Set mode.
	if (mode == TCConfigModeBundled)
	{
		[_modePopup selectItemAtIndex:0];
		
		_imIdentifierField.enabled = NO;
		_imPortField.enabled = NO;
		_torAddressField.enabled = NO;
		_torPortField.enabled = NO;
	}
	else if (mode == TCConfigModeCustom)
	{
		[_modePopup selectItemAtIndex:1];
		
		_imIdentifierField.enabled = YES;
		_imPortField.enabled = YES;
		_torAddressField.enabled = YES;
		_torPortField.enabled = YES;
	}
	
	// Set value field.
	_imIdentifierField.stringValue = self.config.selfIdentifier;
	_imPortField. stringValue = @(self.config.selfPort).description;
	_torAddressField.stringValue = self.config.torAddress;
	_torPortField.stringValue = @(self.config.torPort).description;
	
	// Init temporary changes.
	_customIMIdentifier = self.config.selfIdentifier;
	_customIMPort = @(self.config.selfPort);
	_customTorAddress = self.config.torAddress;
	_customTorPort = @(self.config.torPort);
}

- (void)panelSaveConfiguration
{
	if ([self contentChanged])
	{
		// Set config mode.
		if (_modePopup.indexOfSelectedItem == 0)
			self.config.mode = TCConfigModeBundled;
		else if (_modePopup.indexOfSelectedItem == 1)
			self.config.mode = TCConfigModeCustom;

		// Set config value.
		self.config.selfIdentifier = _imIdentifierField.stringValue;
		self.config.selfPort = (uint16_t)_imPortField.intValue;
		self.config.torAddress = _torAddressField.stringValue;
		self.config.torPort = (uint16_t)_torPortField.intValue;
		
		[self.config synchronize];
		
		// Relaunch TorChat.
		CFRunLoopRef runLoop = CFRunLoopGetMain();
		
		CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes, ^{
			
			// > Show alert.
			NSAlert *alert = [[NSAlert alloc] init];
			
			alert.messageText = NSLocalizedString(@"pref_network_relaunch_title", @"");
			alert.informativeText = [NSString stringWithFormat:NSLocalizedString(@"pref_network_relaunch_message", @"")];
			
			[alert addButtonWithTitle:NSLocalizedString(@"pref_network_relaunch_button", @"")];
			
			[alert runModal];
			
			// > Terminate + relaunch.
			NSString	*relauncher = [[NSBundle mainBundle] executablePath];
			NSTask		*task = [[NSTask alloc] init];
			
			task.launchPath = relauncher;
			task.arguments = @[ @"relaunch", [@(getpid()) stringValue] ];
			
			@try {
				[task launch];
			} @catch (NSException *exception) {
			}
			
			[[NSApplication sharedApplication] terminate:nil];
		});
		
		CFRunLoopWakeUp(runLoop);
	}
}



/*
** TCPrefView_Network - IBAction
*/
#pragma mark - TCPrefView_Network - IBAction

- (IBAction)doChangeMode:(id)sender
{
	// Enabled / disable parts.
	NSInteger index = _modePopup.indexOfSelectedItem;
	
	if (index == 0)
	{
		_customIMIdentifier = _imIdentifierField.stringValue;
		_customIMPort = @(_imPortField.intValue);
		_customTorAddress = _torAddressField.stringValue;
		_customTorPort = @(_torPortField.intValue);
		
		_imIdentifierField.stringValue = self.config.selfIdentifier;
		_imPortField. stringValue = @"60601";
		_torAddressField.stringValue =  @"localhost";
		_torPortField.stringValue = @"60600";
		
		_imIdentifierField.enabled = NO;
		_imPortField.enabled = NO;
		_torAddressField.enabled = NO;
		_torPortField.enabled = NO;
	}
	else if (index == 1)
	{		
		_imIdentifierField.stringValue = _customIMIdentifier;
		_imPortField. stringValue = _customIMPort.description;
		_torAddressField.stringValue =  _customTorAddress;
		_torPortField.stringValue = _customTorPort.description;
		
		_imIdentifierField.enabled = YES;
		_imPortField.enabled = YES;
		_torAddressField.enabled = YES;
		_torPortField.enabled = YES;
	}
	
	// Validate content.
	[self validateContent];
}



/*
** TCPrefView_Network - Helper
*/
#pragma mark - TCPrefView_Network - Helper

- (BOOL)contentChanged
{
	if (_modePopup.indexOfSelectedItem == 0)
	{
		if (self.config.mode != TCConfigModeBundled)
			return YES;
	}
	else if (_modePopup.indexOfSelectedItem == 1)
	{
		if (self.config.mode != TCConfigModeCustom)
			return YES;
		
		BOOL changes = NO;
		
		changes = changes || ([self.config.selfIdentifier isEqualToString:_imIdentifierField.stringValue] == NO);
		changes = changes || (self.config.selfPort != (uint16_t)_imPortField.intValue);
		changes = changes || ([self.config.torAddress isEqualToString:_torAddressField.stringValue] == NO);
		changes = changes || (self.config.torPort != (uint16_t)_torPortField.intValue);
		
		return changes;
	}
	
	return NO;
}

- (void)validateContent
{
	// Init regexp.
	static dispatch_once_t		onceToken;
	static NSRegularExpression	*hostnameRegexp;
	
	dispatch_once(&onceToken, ^{
		hostnameRegexp = [NSRegularExpression regularExpressionWithPattern:@"^(([a-zA-Z0-9]|[a-zA-Z0-9][a-zA-Z0-9\\-]*[a-zA-Z0-9])\\.)*([A-Za-z0-9]|[A-Za-z0-9][A-Za-z0-9\\-]*[A-Za-z0-9])$" options:0 error:nil];
	});
	
	// Check.
	NSString	*torAddressString = _torAddressField.stringValue;
	BOOL		valid = YES;
	
	valid = valid && _imIdentifierField.stringValue.length == 16;
	valid = valid && (_imPortField.integerValue >= 1 && _imPortField.integerValue <= 65535);
	
	// Validate IPv4 or hostname.
	if (valid)
	{
		NSArray <NSString *> *components = [torAddressString componentsSeparatedByString:@"."];
		
		// > Check if it look like a valid IPv4.
		if (components.count == 4 && isNumber(components[0]) && isNumber(components[1]) && isNumber(components[2]) && isNumber(components[3]))
		{
			if (valid && (components[0].integerValue <= 0 || components[0].integerValue >= 255))
				valid = NO;
			if (valid && (components[1].integerValue <= 0 || components[1].integerValue >= 255))
				valid = NO;
			if (valid && (components[2].integerValue <= 0 || components[2].integerValue >= 255))
				valid = NO;
			if (valid && (components[3].integerValue <= 0 || components[3].integerValue >= 255))
				valid = NO;
		}
		// > Check if it look like a valid hostname.
		else
			valid = ([hostnameRegexp numberOfMatchesInString:torAddressString options:NSMatchingAnchored range:NSMakeRange(0, torAddressString.length)] > 0);
	}
	
	valid = valid && (_torPortField.integerValue >= 1 && _torPortField.integerValue <= 65535);
	
	_modePopup.enabled = valid;
	
	[self disablePanelSaving:!valid];
	
	// Show change warning.
	_warningView.hidden = ([self contentChanged] == NO);
}

@end



/*
** C Tools
*/
#pragma mark - C Tools

static BOOL isNumber(NSString *str)
{
	return (str.length > 0) && ([str rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet].invertedSet].location == NSNotFound);
}


NS_ASSUME_NONNULL_END
