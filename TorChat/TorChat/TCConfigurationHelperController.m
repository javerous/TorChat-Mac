/*
 *  TCConfigurationHelperController.m
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

#import <Quartz/Quartz.h>

#import "TCConfigurationHelperController.h"

#import "TCLogsManager.h"

#import "TCConfigurationCopy.h"

#import "TCConfigPlist.h"
#import "TCConfigSQLite.h"

#import "SMCryptoFile.h"

#import "TCFileHelper.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCSQLiteConvertionWindowController - Interface
*/
#pragma mark - TCSQLiteConvertionWindowController - Interface

@interface TCSQLiteConvertionWindowController : NSWindowController

+ (void)convertPLISTConfigurationToSQLiteConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler;

@end


/*
** TCSQLiteOpenWindowController - Interface
*/
#pragma mark - TCSQLiteOpenWindowController - Interface

@interface TCSQLiteOpenWindowController : NSWindowController

+ (void)openSQLiteConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler;

@end



/*
** TCConfigurationHelperController
*/
#pragma mark - TCConfigurationHelperController

@implementation TCConfigurationHelperController

+ (void)openConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler
{
	// Check parameters.
	NSAssert(path, @"path is nil");
	NSAssert(handler, @"handler is nil");
	
	[self openOrConvertConfigurationAtPath:path completionHandler:^(TCConfigurationHelperCompletionType type, id  _Nullable result) {
		
		// Import private key file.
		NSError *error = nil;
		
		if (type == TCConfigurationHelperCompletionTypeDone && [self importPrivateKey:result error:&error] == NO)
		{
			handler(TCConfigurationHelperCompletionTypeError, error);
			return;
		}
		
		// Call original handler.
		handler(type, result);
	}];
}

+ (void)openOrConvertConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler
{
	// Check file existente.
	if ([[NSFileManager defaultManager] fileExistsAtPath:path] == NO)
	{
		handler(TCConfigurationHelperCompletionTypeError, [self errorWithCode:2 localizedMessage:@"conf_helper_error_file_dont_exist"]);
		return;
	}
	
	// Try to open as plist.
	TCConfigPlist *configPlist = [[TCConfigPlist alloc] initWithFile:path];
	
	if (configPlist)
	{
		// > Conversion needed.
		[TCSQLiteConvertionWindowController convertPLISTConfigurationToSQLiteConfigurationAtPath:path completionHandler:handler];
		return;
	}
	
	// Try to open as sqlite.
	[TCSQLiteOpenWindowController openSQLiteConfigurationAtPath:path completionHandler:handler];
}

+ (BOOL)importPrivateKey:(nullable id <TCConfigAppEncryptable>)configuration error:(NSError **)error
{
	if (!configuration || configuration.selfPrivateKey != nil || configuration.mode != TCConfigModeBundled)
		return YES;

	// Compose paths.
	NSString *privateKeyPath = [[configuration pathForComponent:TCConfigPathComponentTorIdentity fullPath:YES] stringByAppendingPathComponent:@"private_key"];
	NSString *hostnamePath = [[configuration pathForComponent:TCConfigPathComponentTorIdentity fullPath:YES] stringByAppendingPathComponent:@"hostname"];
	
	// Read private key.
	NSError	*ferror = nil;
	NSData	*privateKeyData = [NSData dataWithContentsOfFile:privateKeyPath options:NSDataReadingUncached error:&ferror];
	
	if (privateKeyData == nil)
	{
		if (error)
			*error = [self errorWithCode:10 localizedMessage:@"conf_helper_error_cant_read_private_key", privateKeyPath, ferror.localizedDescription];
		
		return NO;
	}
	
	// Convert private key to a string.
	NSString *privateKeyString = [[NSString alloc] initWithData:privateKeyData encoding:NSASCIIStringEncoding];
	
	if (privateKeyString == nil)
	{
		if (error)
			*error = [self errorWithCode:11 localizedMessage:@"conf_helper_error_cant_decode_private_key", privateKeyPath];

		return NO;
	}
	
	// Parse RSA content.
	NSRegularExpression					*regExp = [NSRegularExpression regularExpressionWithPattern:@"-----BEGIN RSA PRIVATE KEY-----(.*)-----END RSA PRIVATE KEY-----" options:(NSRegularExpressionCaseInsensitive | NSRegularExpressionDotMatchesLineSeparators) error:nil];
	NSArray <NSTextCheckingResult *>	*match = [regExp matchesInString:privateKeyString options:0 range:NSMakeRange(0, privateKeyString.length)];
	
	if (match.count == 0 || [match[0] numberOfRanges] < 2)
	{
		if (error)
			*error = [self errorWithCode:12 localizedMessage:@"conf_helper_error_cant_extract_private_key", privateKeyPath];
		
		return NO;
	}
	
	// Extract private key as a raw Base64 string.
	NSString *privateKey = [privateKeyString substringWithRange:[match[0] rangeAtIndex:1]];
	
	privateKey = [[privateKey componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@""];
	
	// Save this key as a setting.
	configuration.selfPrivateKey = [NSString stringWithFormat:@"RSA1024:%@", privateKey];
	
	// Be sure everything is written to disk before removing original file.
	if ([configuration synchronize] == NO)
	{
		if (error)
			*error = [self errorWithCode:13 localizedMessage:@"conf_helper_error_cant_synchronize", privateKeyPath];
		
		return NO;
	}
	
	// Remove previous file on disk.
	TCFileSecureRemove(privateKeyPath);
	TCFileSecureRemove(hostnamePath);
	
	[[TCLogsManager sharedManager] addGlobalLogWithKind:TCLogInfo message:@"conf_helper_info_import_sucess"];
	
	return YES;
}

+ (NSError *)errorWithCode:(int)code localizedMessage:(nullable NSString *)message, ...
{
	if (message)
	{
		// Build string.
		NSString	*localized = NSLocalizedString((NSString *)message, @"");
		NSString	*string;
		va_list		ap;
		
		va_start(ap, message);
		string = [[NSString alloc] initWithFormat:localized arguments:ap];
		va_end(ap);
		
		// Build error.
		return [NSError errorWithDomain:TCConfigurationHelperErrorDomain code:code userInfo:@{ NSLocalizedDescriptionKey : string }];
	}
	else
	{
		return [NSError errorWithDomain:TCConfigurationHelperErrorDomain code:code userInfo:nil];
	}
}

@end





/*
** TCSQLiteConvertionWindowController
*/
#pragma mark - TCSQLiteConvertionWindowController

@implementation TCSQLiteConvertionWindowController
{
	IBOutlet NSButton *encryptCheckBox;

	IBOutlet NSTextField *passwordTitle;
	IBOutlet NSTextField *verifyTitle;
	
	IBOutlet NSSecureTextField *passwordField;
	IBOutlet NSSecureTextField *verifyField;
	
	IBOutlet NSButton *convertButton;
	
	TCSQLiteConvertionWindowController		*_selfRetain;
	TCConfigurationHelperCompletionHandler	_completionHandler;
	NSString								*_path;
}


/*
** TCSQLiteConvertionWindowController - Instance
*/
#pragma mark - TCSQLiteConvertionWindowController - Instance

+ (void)convertPLISTConfigurationToSQLiteConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler
{
	// Create controller.
	TCSQLiteConvertionWindowController *ctrl = [[TCSQLiteConvertionWindowController alloc] init];
	
	if (!ctrl)
	{
		handler(TCConfigurationHelperCompletionTypeError, [TCConfigurationHelperController errorWithCode:20 localizedMessage:@"Internal error (nil ctrl)"]);
		return;
	}
	
	ctrl->_selfRetain = ctrl;
	ctrl->_completionHandler = handler;
	ctrl->_path = path;
	
	// Show as modal.
	CFRunLoopRef runLoop = CFRunLoopGetMain();
	
	CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes, ^{
		
		ctrl.window.preventsApplicationTerminationWhenModal = YES;
		ctrl.window.animationBehavior = NSWindowAnimationBehaviorDocumentWindow;
		
		[[NSApplication sharedApplication] runModalForWindow:(NSWindow *)ctrl.window];
	});
	
	CFRunLoopWakeUp(runLoop);
}

- (instancetype)init
{
	self = [super initWithWindowNibName:@"SQLiteConfigurationConvertWindow"];
	
	if (self)
	{
	}
	
	return self;
}



/*
** TCSQLiteConvertionWindowController - IBAction
*/
#pragma mark - TCSQLiteConvertionWindowController - IBAction

- (IBAction)doEncrypt:(id)sender
{
	passwordTitle.enabled = (encryptCheckBox.state == NSOnState);
	verifyTitle.enabled = (encryptCheckBox.state == NSOnState);
	passwordField.enabled = (encryptCheckBox.state == NSOnState);
	verifyField.enabled = (encryptCheckBox.state == NSOnState);

	[self checkValidity];
}

- (IBAction)doQuit:(id)sender
{
	[self close];
	[[NSApplication sharedApplication] stopModal];

	if (_completionHandler)
		_completionHandler(TCConfigurationHelperCompletionTypeCanceled, nil);
	
	_selfRetain = nil;
}

- (IBAction)doConvert:(id)sender
{
	NSFileManager	*mng = [NSFileManager defaultManager];
	NSError			*error;
	
	// Move plist.
	NSString *tpath = [_path stringByAppendingString:@"-tmp"];

	if ([mng moveItemAtPath:_path toPath:tpath error:&error] == NO)
	{
		NSLog(@"Can't move configuration file '%@' to '%@': %@", _path, tpath, error);
		NSBeep();
		return;
	}
	
	// Open plist.
	TCConfigPlist *configPlist = [[TCConfigPlist alloc] initWithFile:tpath];
	
	if (!configPlist)
	{
		NSLog(@"Can't open configuration file '%@'", tpath);
		[mng moveItemAtPath:tpath toPath:_path error:&error];
		NSBeep();
		return;
	}
	
	// Open sqlite.
	TCConfigSQLite	*configSqlite;
 
	if (encryptCheckBox.state == NSOnState)
	{
		configSqlite = [[TCConfigSQLite alloc] initWithFile:_path password:passwordField.stringValue error:&error];
		configSqlite.saveTranscript = YES;
	}
	else
		configSqlite = [[TCConfigSQLite alloc] initWithFile:_path password:nil error:&error];
	
	if (!configSqlite)
	{
		NSLog(@"Can't open configuration file '%@': %@", _path, error);
		[configPlist close];
		[mng moveItemAtPath:tpath toPath:_path error:nil];
		NSBeep();
		return;
	}

	// Copy plist content to sqlite.
	if ([TCConfigurationCopy copyConfiguration:configPlist toConfiguration:configSqlite] == NO)
	{
		NSLog(@"Can't copy configuration file '%@'", _path);
		[configSqlite close];
		[configPlist close];
		[mng moveItemAtPath:tpath toPath:_path error:&error];
		NSBeep();
	}
	
	// Remove original.
	[configPlist close];
	configPlist = nil;
	
	if ([mng trashItemAtURL:[NSURL fileURLWithPath:tpath] resultingItemURL:nil error:&error] == NO)
		TCFileSecureRemove(tpath);
	
	// Result.
	[self close];
	[[NSApplication sharedApplication] stopModal];

	if (_completionHandler)
		_completionHandler(TCConfigurationHelperCompletionTypeDone, configSqlite);
	
	_selfRetain = nil;
}



/*
** TCSQLiteConvertionWindowController - NSControlDelegate
*/
#pragma mark - TCSQLiteConvertionWindowController - NSControlDelegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	[self checkValidity];
}



/*
** TCSQLiteConvertionWindowController - Tools
*/
#pragma mark - TCSQLiteConvertionWindowController - Tools

- (void)checkValidity
{
	if (encryptCheckBox.state == NSOnState)
		convertButton.enabled = (passwordField.stringValue.length > 0 && [passwordField.stringValue isEqualToString:verifyField.stringValue]);
	else
		convertButton.enabled = YES;
}

@end






/*
** TCSQLiteOpenWindowController
*/
#pragma mark - TCSQLiteOpenWindowController

@implementation TCSQLiteOpenWindowController
{
	IBOutlet NSSecureTextField	*passwordField;
	IBOutlet NSButton			*openButton;
	
	
	TCSQLiteOpenWindowController			*_selfRetain;
	TCConfigurationHelperCompletionHandler	_completionHandler;
	NSString								*_path;
}


/*
** TCSQLiteOpenWindowController - Instance
*/
#pragma mark - TCSQLiteOpenWindowController - Instance

+ (void)openSQLiteConfigurationAtPath:(NSString *)path completionHandler:(TCConfigurationHelperCompletionHandler)handler
{
	if ([TCConfigSQLite isEncryptedFile:path] == NO)
	{
		TCConfigSQLite *config = [[TCConfigSQLite alloc] initWithFile:path password:nil error:nil];
		
		handler(TCConfigurationHelperCompletionTypeDone, config);
	}
	else
	{
		TCSQLiteOpenWindowController *ctrl = [[TCSQLiteOpenWindowController alloc] init];
		
		if (!ctrl)
		{
			handler(TCConfigurationHelperCompletionTypeError, [TCConfigurationHelperController errorWithCode:30 localizedMessage:@"Internal error (nil ctrl)"]);
			return;
		}
		
		ctrl->_selfRetain = ctrl;
		ctrl->_completionHandler = handler;
		ctrl->_path = path;
		
		// Show as modal.
		CFRunLoopRef runLoop = CFRunLoopGetMain();
		
		CFRunLoopPerformBlock(runLoop, kCFRunLoopCommonModes, ^{
			
			ctrl.window.preventsApplicationTerminationWhenModal = YES;
			ctrl.window.animationBehavior = NSWindowAnimationBehaviorDocumentWindow;
			
			[[NSApplication sharedApplication] runModalForWindow:(NSWindow *)ctrl.window];
		});
		
		CFRunLoopWakeUp(runLoop);
	}
}

- (instancetype)init
{
	self = [super initWithWindowNibName:@"SQLiteConfigurationOpenWindow"];
	
	if (self)
	{
	}
	
	return self;
}



/*
** TCSQLiteOpenWindowController - IBAction
*/
#pragma mark - TCSQLiteOpenWindowController - IBAction

- (IBAction)doQuit:(id)sender
{
	[self close];
	[[NSApplication sharedApplication] stopModal];

	if (_completionHandler)
		_completionHandler(TCConfigurationHelperCompletionTypeCanceled, nil);
	
	_selfRetain = nil;
}

- (IBAction)doOpen:(id)sender
{
	NSError			*error = nil;
	TCConfigSQLite	*config = [[TCConfigSQLite alloc] initWithFile:_path password:passwordField.stringValue error:&error];
	
	if (config)
	{
		if (_completionHandler)
			_completionHandler(TCConfigurationHelperCompletionTypeDone, config);
		
		[self close];
		[[NSApplication sharedApplication] stopModal];

		_selfRetain = nil;
	}
	else
	{
		NSNumber *cryptoError = error.userInfo[TCConfigSMCryptoFileErrorKey];
		
		if (cryptoError && [cryptoError intValue] == SMCryptoFileErrorPassword)
		{
			passwordField.enabled = NO;
			openButton.enabled = NO;
			
			[self shakeWithCompletionHandler:^{

				passwordField.stringValue = @"";
				passwordField.enabled = YES;
				
				openButton.enabled = YES;

				[self.window makeFirstResponder:passwordField];
			}];
		}
		else
		{
			NSLog(@"Can't open configuration file '%@': %@", _path, error);
			NSBeep();
		}
	}
}



/*
** TCSQLiteConvertionWindowController - NSControlDelegate
*/
#pragma mark - TCSQLiteConvertionWindowController - NSControlDelegate

- (void)controlTextDidChange:(NSNotification *)aNotification
{
	openButton.enabled = (passwordField.stringValue.length > 0);
}



/*
** TCSQLiteConvertionWindowController - Tools
*/
#pragma mark - TCSQLiteConvertionWindowController - Tools

- (void)shakeWithCompletionHandler:(dispatch_block_t)handler
{
	// Inspired from :
	//  - http://stackoverflow.com/questions/10056528/shake-window-when-user-enter-wrong-password-from-code (SajjadZare)
	//  - http://stackoverflow.com/questions/10517386/how-to-give-nswindow-a-shake-effect-as-saying-no-as-in-login-failure-window (Anoop Vaidya)
	
	static int numberOfShakes = 2;
	static float durationOfShake = 0.25f;
	static float vigourOfShake = 0.05f;
	
	CGRect frame = [self.window frame];
	
	// Create shake path.
	CGMutablePathRef shakePath = CGPathCreateMutable();

	CGPathMoveToPoint(shakePath, NULL, NSMinX(frame), NSMinY(frame));
	
	for (int index = 0; index < numberOfShakes; ++index)
	{
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) - frame.size.width * vigourOfShake, NSMinY(frame));
		CGPathAddLineToPoint(shakePath, NULL, NSMinX(frame) + frame.size.width * vigourOfShake, NSMinY(frame));
	}
	
	CGPathCloseSubpath(shakePath);

	// Create shake animation.
	CAKeyframeAnimation *shakeAnimation = [CAKeyframeAnimation animation];
	
	shakeAnimation.path = shakePath;
	shakeAnimation.duration = durationOfShake;
	
	CGPathRelease(shakePath);

	// Animate.
	[NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
		self.window.animations = @{ @"frameOrigin" : shakeAnimation };
		self.window.animator.frameOrigin = self.window.frame.origin;
	} completionHandler:^{
		dispatch_async(dispatch_get_main_queue(), handler);
	}];
}

@end


NS_ASSUME_NONNULL_END
