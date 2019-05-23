/*
 *  TCPrefView.m
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

#import "TCPrefView.h"


NS_ASSUME_NONNULL_BEGIN


/*
** TCPrefView - Private
*/
#pragma mark - TCPrefView - Private

@interface TCPrefView ()

@property (strong, nonatomic) void (^disablePanelSaving)(BOOL disable);

@property (strong, nonatomic) id <TCConfigAppEncryptable>	config;
@property (strong, nonatomic) TCCoreManager				*core;

@end



/*
** TCPrefView
*/
#pragma mark - TCPrefView

@implementation TCPrefView


/*
** TCPrefView - Config
*/
#pragma mark - TCPrefView - Config

- (void)panelLoadConfiguration
{
	// Must be redefined
}

- (void)panelSaveConfiguration
{
	// Must be redefined
}

- (void)switchingIn
{
	// Must be redefined
}

- (void)switchingOut
{
	// Must be redefined
}

- (void)disablePanelSaving:(BOOL)disable
{
	if (_disablePanelSaving)
		_disablePanelSaving(disable);
}

@end


NS_ASSUME_NONNULL_END

