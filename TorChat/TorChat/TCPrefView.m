/*
 *  TCPrefView.m
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

#import "TCPrefView.h"


/*
** TCPrefView - Private
*/
#pragma mark - TCPrefView - Private

@interface TCPrefView ()

@property (strong, nonatomic) void (^reloadConfig)(dispatch_block_t doneHandler);

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

- (void)panelDidAppear
{
	// Must be redefined
}

- (void)panelDidDisappear
{
	// Must be redefined
}

- (void)reloadConfigurationWithCompletionHandler:(dispatch_block_t)handler
{
	if (_reloadConfig)
		_reloadConfig(handler);
}

@end
