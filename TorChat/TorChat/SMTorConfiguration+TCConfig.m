/*
 *  SMTorConfiguration+TCConfig.m
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

#import "SMTorConfiguration+TCConfig.h"


/*
** SMTorConfiguration + TCConfigCore
*/
#pragma mark - SMTorConfiguration + TCConfigCore

@implementation SMTorConfiguration (TCConfigCore)

- (instancetype)initWithTorChatConfiguration:(id <TCConfigCore>)config
{
	self = [super init];
	
	if (self)
	{
		// Socks.
		self.socksPort = config.torPort;
		self.socksHost = (config.torAddress ?: @"localhost");
		
		// Hidden Service.
		self.hiddenService = YES;
		
		self.hiddenServicePrivateKey = config.selfPrivateKey;
		
		self.hiddenServiceRemotePort = 11009;
		
		self.hiddenServiceLocalHost = @"127.0.0.1";
		self.hiddenServiceLocalPort = config.selfPort;
		
		// Path.
		self.binaryPath = [config pathForComponent:TCConfigPathComponentTorBinary fullPath:YES];
		self.dataPath = [config pathForComponent:TCConfigPathComponentTorData fullPath:YES];
	}
	
	return self;
}

@end
