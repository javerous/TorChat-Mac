/*
 *  TCFileSignature.h
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

#import <Foundation/Foundation.h>


/*
** Defines
*/
#pragma mark - Defines

#define SMPrivateKeyData	@"private_key"
#define SMPublicKeyData		@"public_key"



/*
** TCFileSignature
*/
#pragma mark - TCFileSignature

@interface TCFileSignature : NSObject

// -- Key Generation --
+ (NSDictionary *)generateKeyPairsOfSize:(NSUInteger)keySize;

// -- Signatures --
+ (NSData *)signContentsOfURL:(NSURL *)aURL withPrivateKey:(NSData *)privateKey;
+ (BOOL)validateSignature:(NSData *)signature forContentsOfURL:(NSURL *)aURL withPublicKey:(NSData *)publicKey;

@end
