/*
 *  TCPrefView_General.m
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

#import "TCPrefView_General.h"

#import "TCThemesManager.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPrefView_General - Private
*/
#pragma mark - TCPrefView_General - Private

@interface TCPrefView_General ()

// -- Properties --
@property (strong, nonatomic) IBOutlet NSTextField		*clientNameField;
@property (strong, nonatomic) IBOutlet NSTextField		*clientVersionField;

@property (strong, nonatomic) IBOutlet NSButton			*saveTranscriptCheckBox;

@property (strong, nonatomic) IBOutlet NSPopUpButton	*themesPopup;

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

- (instancetype)init
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

- (void)panelLoadConfiguration
{
	// Client info.
	_clientNameField.placeholderString = ([self.config clientName:TCConfigGetDefault] ?: @"");
	_clientVersionField.placeholderString = ([self.config clientVersion:TCConfigGetDefault] ?: @"");
	
	_clientNameField.stringValue = ([self.config clientName:TCConfigGetDefined] ?: @"");
	_clientVersionField.stringValue = ([self.config clientVersion:TCConfigGetDefined] ?: @"");
	
	// Transcripts.
	_saveTranscriptCheckBox.state = (self.config.saveTranscript ? NSOnState : NSOffState);
	
	// Themes.
	NSArray		*themes = [[TCThemesManager sharedManager] themes];
	NSString	*themeID = self.config.themeIdentifier;
	__block NSUInteger	themeIndex = NSNotFound;

	[_themesPopup removeAllItems];
	
	[themes enumerateObjectsUsingBlock:^(TCTheme * _Nonnull theme, NSUInteger idx, BOOL * _Nonnull stop) {
		
		NSString *localizedKey = [NSString stringWithFormat:@"pref_theme_%@", theme.identifier];
		
		[_themesPopup addItemWithTitle:NSLocalizedString(localizedKey, @"")];
		
		if (themeID && [theme.identifier isEqualToString:themeID])
			themeIndex = idx;
	}];

	[_themesPopup sizeToFit];

	if (themeIndex != NSNotFound)
		[_themesPopup selectItemAtIndex:(NSInteger)themeIndex];
	else
		[_themesPopup selectItemAtIndex:0];
}

- (void)panelSaveConfiguration
{
	// CLient info.
	// > name.
	NSString *clientName = _clientNameField.stringValue;
	
	if (clientName.length > 0)
		[self.config setClientName:clientName];
	else
		[self.config setClientName:nil];

	// > version.
	NSString *clientVersion = _clientVersionField.stringValue;
	
	if (clientVersion.length > 0)
		[self.config setClientVersion:clientVersion];
	else
		[self.config setClientVersion:nil];
	
	// Transcript.
	self.config.saveTranscript = (_saveTranscriptCheckBox.state == NSOnState);
	
	// Themes.
	NSInteger	themeIndex = _themesPopup.indexOfSelectedItem;
	NSArray		*themes = [[TCThemesManager sharedManager] themes];

	if (themeIndex >= 0 && themeIndex < themes.count)
	{
		TCTheme *theme = themes[(NSUInteger)themeIndex];
		
		self.config.themeIdentifier = theme.identifier;
	}
}

@end


NS_ASSUME_NONNULL_END
