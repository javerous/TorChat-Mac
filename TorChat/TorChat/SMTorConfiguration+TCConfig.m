/*
 *  SMTorConfiguration+TCConfig.m
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

#import "SMTorConfiguration+TCConfig.h"


NS_ASSUME_NONNULL_BEGIN


/*
** SMTorConfiguration + TCConfigCore
*/
#pragma mark - SMTorConfiguration + TCConfigCore

@implementation SMTorConfiguration (TCConfigCore)

- (nullable instancetype)initWithTorChatConfiguration:(id <TCConfigCore>)config
{
	self = [super init];
	
	if (self)
	{
		NSAssert(config, @"config is nil");
		
		// Socks.
		self.socksPort = config.torPort;
		self.socksHost = (config.torAddress ?: @"localhost");
		
		// Hidden Service.
		self.hiddenService = YES;
		
		self.hiddenServicePrivateKey = config.selfPrivateKey;
		
		self.hiddenServiceRemotePort = 11009;
		
		self.hiddenServiceLocalHost = @"127.0.0.1";
		self.hiddenServiceLocalPort = config.selfPort;
		
		// Paths.
		NSString *binPath = [config pathForComponent:TCConfigPathComponentTorBinary fullPath:YES];
		NSString *dataPath = [config pathForComponent:TCConfigPathComponentTorData fullPath:YES];
		
		if (!binPath || !dataPath)
			return nil;
		
		self.binaryPath = binPath;
		self.dataPath = dataPath;
	}
	
	return self;
}

@end


NS_ASSUME_NONNULL_END
