/*
 *  TCConfigurationCopy.m
 *
 *  Copyright 2018 Avérous Julien-Pierre
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

#import "TCConfigurationCopy.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCConfigurationCopy
*/
#pragma mark - TCConfigurationCopy

@implementation TCConfigurationCopy

+ (BOOL)copyConfiguration:(id <TCConfigApp>)source toConfiguration:(id <TCConfigApp>)target
{
	NSAssert(source, @"source is nil");
	NSAssert(target, @"target is nil");
	
	// Tor.
	target.torAddress = source.torAddress;
	target.torPort = source.torPort;
	
	// TorChat.
	target.selfIdentifier = source.selfIdentifier;
	target.selfPort = source.selfPort;

	// Mode.
	target.mode = source.mode;
	
	// Profile.
	target.profileName = source.profileName;
	target.profileText = source.profileText;
	target.profileAvatar = source.profileAvatar;
	
	// Buddies.
	NSArray *buddiesIdentifiers = [source buddiesIdentifiers];
	
	for (NSString *buddyIdentifier in buddiesIdentifiers)
	{
		NSString *alias = [source buddyAliasForBuddyIdentifier:buddyIdentifier];
		NSString *notes = [source buddyNotesForBuddyIdentifier:buddyIdentifier];
		NSString *lastName = [source buddyLastNameForBuddyIdentifier:buddyIdentifier];
		NSString *lastText = [source buddyLastTextForBuddyIdentifier:buddyIdentifier];
		TCImage *lastAvatar = [source buddyLastAvatarForBuddyIdentifier:buddyIdentifier];

		[target addBuddyWithIdentifier:buddyIdentifier alias:alias notes:notes];
		
		[target setBuddyLastName:lastName forBuddyIdentifier:buddyIdentifier];
		[target setBuddyLastText:lastText forBuddyIdentifier:buddyIdentifier];
		[target setBuddyLastAvatar:lastAvatar forBuddyIdentifier:buddyIdentifier];
	}
	
	// Blocked.
	NSArray *blocked = [source blockedBuddies];
	
	for (NSString *identifier in blocked)
		[target addBlockedBuddyWithIdentifier:identifier];
	
	// Client.
	NSString *version = [source clientVersion:TCConfigGetDefined];
	
	if (version.length > 0)
		[target setClientVersion:version];
	else
		[target setClientVersion:nil];


	NSString *name = [source clientName:TCConfigGetDefined];
	
	if (name.length > 0)
		[target setClientName:name];
	else
		[target setClientName:nil];

	
	// Paths.
	void (^handleComponent)(TCConfigPathComponent component) = ^(TCConfigPathComponent component) {
		
		TCConfigPathType type = [source pathTypeForComponent:component];
		
		switch (type)
		{
			case TCConfigPathTypeReferral:
				[target setPathForComponent:component pathType:TCConfigPathTypeReferral path:[source pathForComponent:component fullPath:NO]];
				break;
				
			case TCConfigPathTypeStandard:
				[target setPathForComponent:component pathType:TCConfigPathTypeStandard path:nil];
				break;
				
			case TCConfigPathTypeAbsolute:
				[target setPathForComponent:component pathType:TCConfigPathTypeAbsolute path:[source pathForComponent:component fullPath:NO]];
				break;
		}
	};
	
	handleComponent(TCConfigPathComponentTorBinary);
	handleComponent(TCConfigPathComponentTorData);
	handleComponent(TCConfigPathComponentTorIdentity);
	handleComponent(TCConfigPathComponentDownloads);

	
	// Synchronize.
	[target synchronize];

	return YES;
}

@end


NS_ASSUME_NONNULL_END
