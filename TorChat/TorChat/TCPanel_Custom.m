/*
 *  TCPanel_Custom.m
 *
 *  Copyright 2017 Avérous Julien-Pierre
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

#import "TCPanel_Custom.h"

#import "TCLogsManager.h"
#import "TCConfigApp.h"

#import "TCLocationViewController.h"

#import "TCValidatedTextField.h"


NS_ASSUME_NONNULL_BEGIN


/*
** Macro
*/
#pragma mark - Macro

#define TCLocalizedString(key, comment) [[NSBundle mainBundle] localizedStringForKey:[(key) copy] value:@"" table:nil]



/*
** Prototypes
*/
#pragma mark - Prototypes

static BOOL isNumber(NSString *str);



/*
** TCPanel_Custom - Private
*/
#pragma mark - TCPanel_Custom - Private

@interface TCPanel_Custom ()
{
	id <TCConfigApp> _currentConfig;

	TCLocationViewController *_torDownloadsLocation;
}

@property (strong, nonatomic)	IBOutlet TCValidatedTextField	*imIdentifierField;
@property (strong, nonatomic)	IBOutlet TCValidatedTextField	*imInPortField;
@property (strong, nonatomic)	IBOutlet NSView *downloadLocationView;

@property (strong, nonatomic)	IBOutlet TCValidatedTextField	*torAddressField;
@property (strong, nonatomic)	IBOutlet TCValidatedTextField	*torPortField;

@end



/*
** TCPanel_Custom
*/
#pragma mark - TCPanel_Custom

@implementation TCPanel_Custom

@synthesize panelProxy;
@synthesize panelPreviousContent;

- (void)dealloc
{
    TCDebugLog(@"TCPanel_Custom dealloc");
}


/*
** TCPanel_Custom - SMAssistantPanel
*/
#pragma mark - TCPanel_Custom - SMAssistantPanel

+ (id <SMAssistantPanel>)panelInstance
{
	return (id <SMAssistantPanel>)[[TCPanel_Custom alloc] initWithNibName:@"AssistantPanel_Custom" bundle:nil];
}

+ (NSString *)panelIdentifier
{
	return @"ac_custom";
}

+ (NSString *)panelTitle
{
	return NSLocalizedString(@"ac_title_custom", @"");
}

- (NSView *)panelView
{
	return self.view;
}

- (nullable id)panelContent
{
	// Set up the config with the fields.
	_currentConfig.torAddress = _torAddressField.stringValue;
	_currentConfig.selfIdentifier = _imIdentifierField.stringValue;
	
	_currentConfig.torPort = (uint16_t)_torPortField.intValue;
	_currentConfig.selfPort = (uint16_t)_imInPortField.intValue;
	
	// Return the config.
	return _currentConfig;
}

- (void)panelDidAppear
{
	// Handle config.
	_currentConfig = self.panelPreviousContent;

	if (!_currentConfig)
	{
		[self.panelProxy setDisableContinue:YES];
		return;
	}
	
	// Configure assistant.
	[self.panelProxy setDisableContinue:YES];
	
	_currentConfig.mode = TCConfigModeCustom;
	
	// Add view to configure download path.
	_torDownloadsLocation = [[TCLocationViewController alloc] initWithConfiguration:_currentConfig component:TCConfigPathComponentDownloads];
	
	[_torDownloadsLocation addToView:_downloadLocationView];
	
	// Select first field.
	[self.view.window makeFirstResponder:_imIdentifierField];

	// Configure validation.
	TCPanel_Custom *weakSekf = self;
	
	// > Identifier.
	_imIdentifierField.validCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@"abcdefghijklmnopqrstuvwxyz0123456789"];
	_imIdentifierField.validateContent = ^ BOOL (NSString *newContent) {
		return (newContent.length <= 16);
	};
	_imIdentifierField.textDidChange = ^(NSString *content) {
		[weakSekf validateContent];
	};
	
	// > IM port.
	_imInPortField.validCharacterSet = [NSCharacterSet decimalDigitCharacterSet];
	_imInPortField.validateContent = ^ BOOL (NSString *newContent) {
		return (newContent.length <= 5);
	};
	_imInPortField.textDidChange = ^(NSString *content) {
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
}

- (void)canceled
{
	NSString *referralPath = [_currentConfig pathForComponent:TCConfigPathComponentReferral fullPath:YES];
	
	[_currentConfig close];
	
	if (referralPath)
	{
		NSString *confPath = [referralPath stringByAppendingPathComponent:@"torchat.conf"];
		
		[[NSFileManager defaultManager] removeItemAtPath:confPath error:nil];
	}
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
	valid = valid && (_imInPortField.integerValue >= 1 && _imInPortField.integerValue <= 65535);
	
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

	[self.panelProxy setDisableContinue:!valid];
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
